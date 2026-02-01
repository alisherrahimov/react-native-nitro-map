package com.margelo.nitro.nitromap.providers

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import android.view.View
import android.view.ViewTreeObserver
import androidx.core.content.ContextCompat
import com.google.android.gms.maps.CameraUpdateFactory
import com.google.android.gms.maps.GoogleMap
import com.google.android.gms.maps.MapView
import com.google.android.gms.maps.OnMapReadyCallback
import com.google.android.gms.maps.model.*
import com.margelo.nitro.core.Promise
import com.margelo.nitro.nitromap.*
import com.margelo.nitro.nitromap.clustering.Cluster
import com.margelo.nitro.nitromap.clustering.NitroClusterEngine
import kotlin.math.max
import org.json.JSONArray
import org.json.JSONObject

/** User data attached to cluster markers for tap handling */
data class ClusterUserData(val markerIds: List<String>, val count: Int)

/** Google Maps implementation of MapProviderInterface */
class GoogleMapProvider(private val context: Context) : MapProviderInterface, OnMapReadyCallback {

    private val _mapView: MapView = MapView(context)
    override val mapView: View
        get() = _mapView

    private var googleMap: GoogleMap? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    // Clustering engine
    private val clusterEngine = NitroClusterEngine()
    private var clusterIconGenerator: ClusterIconGenerator? = null

    // Rendered markers on map
    private val renderedClusterMarkers = mutableListOf<Marker>()
    private val renderedSingleMarkers = mutableMapOf<String, Marker>()
    private val nonClusteredMarkers = mutableMapOf<String, Marker>()

    // Track clusterable marker data
    private val clusterableMarkerData = mutableMapOf<String, MarkerData>()

    // Track selected marker ID for visual state
    private var selectedMarkerId: String? = null

    // Track if we need to cluster after layout
    private var needsClusteringAfterLayout = false
    private var hasLayout = false
    private var initialRegionApplied = false

    // MARK: - Properties

    private var _initialRegion: Region? = null
    override var initialRegion: Region?
        get() = _initialRegion
        set(value) {
            _initialRegion = value
            value?.let { updateCameraToInitialRegion(it) }
        }

    private var _showsUserLocation: Boolean? = null
    override var showsUserLocation: Boolean?
        get() = _showsUserLocation
        @SuppressLint("MissingPermission")
        set(value) {
            _showsUserLocation = value
            googleMap?.let { map ->
                if (value == true && hasLocationPermission()) {
                    try {
                        map.isMyLocationEnabled = true
                    } catch (e: SecurityException) {
                        e.printStackTrace()
                    }
                } else {
                    try {
                        map.isMyLocationEnabled = false
                    } catch (e: SecurityException) {
                        e.printStackTrace()
                    }
                }
            }
        }

    private var _showsMyLocationButton: Boolean? = null
    override var showsMyLocationButton: Boolean?
        get() = _showsMyLocationButton
        set(value) {
            _showsMyLocationButton = value
            googleMap?.uiSettings?.isMyLocationButtonEnabled = value ?: false
        }

    private var _zoomEnabled: Boolean? = null
    override var zoomEnabled: Boolean?
        get() = _zoomEnabled
        set(value) {
            _zoomEnabled = value
            googleMap?.uiSettings?.isZoomGesturesEnabled = value ?: true
        }

    private var _scrollEnabled: Boolean? = null
    override var scrollEnabled: Boolean?
        get() = _scrollEnabled
        set(value) {
            _scrollEnabled = value
            googleMap?.uiSettings?.isScrollGesturesEnabled = value ?: true
        }

    private var _rotateEnabled: Boolean? = null
    override var rotateEnabled: Boolean?
        get() = _rotateEnabled
        set(value) {
            _rotateEnabled = value
            googleMap?.uiSettings?.isRotateGesturesEnabled = value ?: true
        }

    private var _pitchEnabled: Boolean? = null
    override var pitchEnabled: Boolean?
        get() = _pitchEnabled
        set(value) {
            _pitchEnabled = value
            googleMap?.uiSettings?.isTiltGesturesEnabled = value ?: true
        }

    private var _mapType: MapType? = null
    override var mapType: MapType?
        get() = _mapType
        set(value) {
            _mapType = value
            googleMap?.mapType = convertMapType(value)
        }

    private var _clusterConfig: ClusterConfig? = null
    override var clusterConfig: ClusterConfig?
        get() = _clusterConfig
        set(value) {
            _clusterConfig = value
            updateClusterConfig()
        }

    private var _darkMode: Boolean? = null
    override var darkMode: Boolean?
        get() = _darkMode
        set(value) {
            _darkMode = value
            applyDarkModeStyle()
        }

    private var _customMapStyle: Array<MapStyleElement>? = null
    override var customMapStyle: Array<MapStyleElement>?
        get() = _customMapStyle
        set(value) {
            _customMapStyle = value
            applyMapStyle()
        }

    // MARK: - Callbacks

    override var onMapReady: (() -> Unit)? = null
    override var onPress: ((event: MapPressEvent) -> Unit)? = null
    override var onLongPress: ((event: MapPressEvent) -> Unit)? = null
    override var onRegionChange: ((event: RegionChangeEvent) -> Unit)? = null
    override var onRegionChangeComplete: ((event: RegionChangeEvent) -> Unit)? = null
    override var onMarkerPress: ((event: MarkerPressEvent) -> Unit)? = null
    override var onMarkerDragStart: ((event: MarkerDragEvent) -> Unit)? = null
    override var onMarkerDrag: ((event: MarkerDragEvent) -> Unit)? = null
    override var onMarkerDragEnd: ((event: MarkerDragEvent) -> Unit)? = null
    override var onClusterPress: ((event: ClusterPressEvent) -> Unit)? = null

    // MARK: - Setup

    override fun setup() {
        _mapView.onCreate(null)
        _mapView.getMapAsync(this)

        clusterIconGenerator = ClusterIconGenerator(context)
        clusterEngine.setClusterRadius(60.0)
        clusterEngine.setMinClusterSize(2)
        clusterEngine.setMaxZoom(20.0)

        _mapView.viewTreeObserver.addOnGlobalLayoutListener(
                object : ViewTreeObserver.OnGlobalLayoutListener {
                    override fun onGlobalLayout() {
                        if (_mapView.width > 0 && _mapView.height > 0) {
                            hasLayout = true
                            if (needsClusteringAfterLayout) {
                                needsClusteringAfterLayout = false
                                performClustering()
                            }
                        }
                    }
                }
        )
    }

    override fun onMapReady(map: GoogleMap) {
        googleMap = map
        applyAllProperties()
        setupMapListeners(map)
        onMapReady?.invoke()
    }

    @SuppressLint("MissingPermission")
    private fun applyAllProperties() {
        googleMap?.let { map ->
            map.uiSettings.isZoomGesturesEnabled = _zoomEnabled ?: true
            map.uiSettings.isScrollGesturesEnabled = _scrollEnabled ?: true
            map.uiSettings.isRotateGesturesEnabled = _rotateEnabled ?: true
            map.uiSettings.isTiltGesturesEnabled = _pitchEnabled ?: true
            map.uiSettings.isMyLocationButtonEnabled = _showsMyLocationButton ?: false
            map.mapType = convertMapType(_mapType)

            if (_showsUserLocation == true && hasLocationPermission()) {
                try {
                    map.isMyLocationEnabled = true
                } catch (e: SecurityException) {
                    e.printStackTrace()
                }
            }

            if (!initialRegionApplied) {
                _initialRegion?.let {
                    updateCameraToInitialRegion(it)
                    initialRegionApplied = true
                }
            }
            applyMapStyle()
            applyDarkModeStyle()
        }
    }

    private fun setupMapListeners(map: GoogleMap) {
        map.setOnMapClickListener { latLng ->
            val projection = map.projection
            val screenPoint = projection.toScreenLocation(latLng)
            onPress?.invoke(
                    MapPressEvent(
                            coordinate = Coordinate(latLng.latitude, latLng.longitude),
                            position = Point(screenPoint.x.toDouble(), screenPoint.y.toDouble())
                    )
            )
        }

        map.setOnMapLongClickListener { latLng ->
            val projection = map.projection
            val screenPoint = projection.toScreenLocation(latLng)
            onLongPress?.invoke(
                    MapPressEvent(
                            coordinate = Coordinate(latLng.latitude, latLng.longitude),
                            position = Point(screenPoint.x.toDouble(), screenPoint.y.toDouble())
                    )
            )
        }

        map.setOnCameraMoveListener {
            val camera = map.cameraPosition
            val bounds = map.projection.visibleRegion.latLngBounds
            onRegionChange?.invoke(
                    RegionChangeEvent(
                            region =
                                    Region(
                                            latitude = camera.target.latitude,
                                            longitude = camera.target.longitude,
                                            latitudeDelta =
                                                    bounds.northeast.latitude -
                                                            bounds.southwest.latitude,
                                            longitudeDelta =
                                                    bounds.northeast.longitude -
                                                            bounds.southwest.longitude
                                    ),
                            isGesture = true
                    )
            )
        }

        map.setOnCameraIdleListener {
            val camera = map.cameraPosition
            val bounds = map.projection.visibleRegion.latLngBounds
            onRegionChangeComplete?.invoke(
                    RegionChangeEvent(
                            region =
                                    Region(
                                            latitude = camera.target.latitude,
                                            longitude = camera.target.longitude,
                                            latitudeDelta =
                                                    bounds.northeast.latitude -
                                                            bounds.southwest.latitude,
                                            longitudeDelta =
                                                    bounds.northeast.longitude -
                                                            bounds.southwest.longitude
                                    ),
                            isGesture = false
                    )
            )
            performClustering()
        }

        map.setOnMarkerClickListener { marker ->
            when (val userData = marker.tag) {
                is ClusterUserData -> {
                    onClusterPress?.invoke(
                            ClusterPressEvent(
                                    coordinate =
                                            Coordinate(
                                                    marker.position.latitude,
                                                    marker.position.longitude
                                            ),
                                    markerIds = userData.markerIds.toTypedArray(),
                                    count = userData.count.toDouble()
                            )
                    )
                    true
                }
                is String -> {
                    onMarkerPress?.invoke(
                            MarkerPressEvent(
                                    id = userData,
                                    coordinate =
                                            Coordinate(
                                                    marker.position.latitude,
                                                    marker.position.longitude
                                            )
                            )
                    )
                    false
                }
                else -> false
            }
        }

        map.setOnMarkerDragListener(
                object : GoogleMap.OnMarkerDragListener {
                    override fun onMarkerDragStart(marker: Marker) {
                        val id = marker.tag as? String ?: return
                        onMarkerDragStart?.invoke(
                                MarkerDragEvent(
                                        id = id,
                                        coordinate =
                                                Coordinate(
                                                        marker.position.latitude,
                                                        marker.position.longitude
                                                )
                                )
                        )
                    }

                    override fun onMarkerDrag(marker: Marker) {
                        val id = marker.tag as? String ?: return
                        onMarkerDrag?.invoke(
                                MarkerDragEvent(
                                        id = id,
                                        coordinate =
                                                Coordinate(
                                                        marker.position.latitude,
                                                        marker.position.longitude
                                                )
                                )
                        )
                    }

                    override fun onMarkerDragEnd(marker: Marker) {
                        val id = marker.tag as? String ?: return
                        onMarkerDragEnd?.invoke(
                                MarkerDragEvent(
                                        id = id,
                                        coordinate =
                                                Coordinate(
                                                        marker.position.latitude,
                                                        marker.position.longitude
                                                )
                                )
                        )
                    }
                }
        )
    }

    // MARK: - Clustering

    private fun updateClusterConfig() {
        clusterIconGenerator?.updateConfig(_clusterConfig)
        _clusterConfig?.let { config ->
            clusterEngine.setMinClusterSize(config.minimumClusterSize.toInt())
            clusterEngine.setMaxZoom(config.maxZoom)
        }
        performClustering()
    }

    override fun performClustering() {
        val map = googleMap ?: return
        if (_mapView.width <= 0 || _mapView.height <= 0) return

        val enabled = _clusterConfig?.enabled ?: true
        if (!enabled) {
            clearRenderedMarkers()
            renderAllMarkersIndividually()
            return
        }

        val bounds = map.projection.visibleRegion.latLngBounds
        val zoom = map.cameraPosition.zoom

        val result =
                clusterEngine.cluster(
                        bounds = bounds,
                        zoom = zoom,
                        mapWidth = _mapView.width,
                        mapHeight = _mapView.height
                )

        clearRenderedMarkers()

        for (clusterData in result.clusters) {
            renderCluster(clusterData)
        }

        for (markerPoint in result.singleMarkers) {
            clusterEngine.getMarkerData(markerPoint.id)?.let { renderSingleMarker(it) }
        }
    }

    private fun clearRenderedMarkers() {
        renderedClusterMarkers.forEach { it.remove() }
        renderedClusterMarkers.clear()
        renderedSingleMarkers.values.forEach { it.remove() }
        renderedSingleMarkers.clear()
    }

    private fun renderAllMarkersIndividually() {
        clusterableMarkerData.values.forEach { markerData ->
            createGoogleMarker(markerData)?.let { renderedSingleMarkers[markerData.id] = it }
        }
    }

    private fun renderCluster(clusterData: Cluster) {
        val map = googleMap ?: return
        val markerOptions =
                MarkerOptions()
                        .position(LatLng(clusterData.latitude, clusterData.longitude))
                        .anchor(0.5f, 0.5f)

        clusterIconGenerator?.getClusterIcon(clusterData.count)?.let { markerOptions.icon(it) }

        val marker = map.addMarker(markerOptions)
        marker?.tag = ClusterUserData(markerIds = clusterData.markerIds, count = clusterData.count)
        marker?.let { renderedClusterMarkers.add(it) }
    }

    private fun renderSingleMarker(markerData: MarkerData) {
        createGoogleMarker(markerData)?.let { renderedSingleMarkers[markerData.id] = it }
    }

    private fun createGoogleMarker(markerData: MarkerData): Marker? {
        val map = googleMap ?: return null

        val markerOptions =
                MarkerOptions()
                        .position(
                                LatLng(
                                        markerData.coordinate.latitude,
                                        markerData.coordinate.longitude
                                )
                        )
                        .title(markerData.title)
                        .snippet(markerData.description)
                        .draggable(markerData.draggable)
                        .alpha(markerData.opacity.toFloat())
                        .rotation(markerData.rotation.toFloat())
                        .zIndex(markerData.zIndex.toFloat())
                        .anchor(markerData.anchor.x.toFloat(), markerData.anchor.y.toFloat())

        MarkerIconFactory.createIcon(context, markerData)?.let { markerOptions.icon(it) }

        val marker = map.addMarker(markerOptions)
        marker?.tag = markerData.id
        return marker
    }

    // MARK: - Marker Management

    override fun addMarker(marker: MarkerData) {
        runOnUiThread {
            addMarkerSync(marker)
            scheduleClusteringAfterLayout()
        }
    }

    override fun addMarkers(markers: Array<MarkerData>) {
        runOnUiThread {
            markers.forEach { addMarkerSync(it) }
            scheduleClusteringAfterLayout()
        }
    }

    private fun addMarkerSync(markerData: MarkerData) {
        removeMarkerSync(markerData.id)

        val clusterConfigEnabled = _clusterConfig?.enabled ?: true
        if (markerData.clusteringEnabled && clusterConfigEnabled) {
            clusterableMarkerData[markerData.id] = markerData
            clusterEngine.addMarker(markerData)
        } else {
            createGoogleMarker(markerData)?.let { nonClusteredMarkers[markerData.id] = it }
        }
    }

    override fun updateMarker(marker: MarkerData) {
        runOnUiThread {
            removeMarkerSync(marker.id)
            addMarkerSync(marker)
            scheduleClusteringAfterLayout()
        }
    }

    override fun removeMarker(id: String) {
        runOnUiThread {
            removeMarkerSync(id)
            scheduleClusteringAfterLayout()
        }
    }

    private fun removeMarkerSync(id: String) {
        clusterEngine.removeMarker(id)
        clusterableMarkerData.remove(id)
        renderedSingleMarkers[id]?.remove()
        renderedSingleMarkers.remove(id)
        nonClusteredMarkers[id]?.remove()
        nonClusteredMarkers.remove(id)
    }

    override fun selectMarker(id: String) {
        runOnUiThread {
            selectedMarkerId?.let { previousId ->
                if (previousId != id) updateMarkerSelectionState(previousId, false)
            }
            selectedMarkerId = id
            updateMarkerSelectionState(id, true)
            renderedSingleMarkers[id]?.showInfoWindow() ?: nonClusteredMarkers[id]?.showInfoWindow()
        }
    }

    private fun updateMarkerSelectionState(id: String, selected: Boolean) {
        val data = clusterableMarkerData[id] ?: return
        if (data.config.style != MarkerStyle.PRICEMARKER) return
        val priceConfig = data.config.priceMarker ?: return

        val updatedPriceConfig =
                PriceMarkerStyle(
                        price = priceConfig.price,
                        currency = priceConfig.currency,
                        selected = selected,
                        backgroundColor = priceConfig.backgroundColor,
                        selectedBackgroundColor = priceConfig.selectedBackgroundColor,
                        textColor = priceConfig.textColor,
                        selectedTextColor = priceConfig.selectedTextColor,
                        fontSize = priceConfig.fontSize,
                        paddingHorizontal = priceConfig.paddingHorizontal,
                        paddingVertical = priceConfig.paddingVertical,
                        shadowOpacity = priceConfig.shadowOpacity
                )

        val updatedConfig =
                MarkerConfig(
                        style = data.config.style,
                        image = data.config.image,
                        priceMarker = updatedPriceConfig,

                )

        val updatedData =
                MarkerData(
                        id = data.id,
                        coordinate = data.coordinate,
                        title = data.title,
                        description = data.description,
                        draggable = data.draggable,
                        opacity = data.opacity,
                        rotation = data.rotation,
                        zIndex = data.zIndex,
                        anchor = data.anchor,
                        clusteringEnabled = data.clusteringEnabled,
                        config = updatedConfig,
                        animation = data.animation
                )

        clusterableMarkerData[id] = updatedData
        clusterEngine.removeMarker(id)
        clusterEngine.addMarker(updatedData)

        (renderedSingleMarkers[id] ?: nonClusteredMarkers[id])?.let { marker ->
            MarkerIconFactory.createIcon(context, updatedData)?.let { marker.setIcon(it) }
        }
    }

    override fun clearMarkers() {
        runOnUiThread {
            clusterEngine.clearMarkers()
            clusterableMarkerData.clear()
            clearRenderedMarkers()
            nonClusteredMarkers.values.forEach { it.remove() }
            nonClusteredMarkers.clear()
        }
    }

    override fun setClusteringEnabled(enabled: Boolean) {
        runOnUiThread {
            val existing = _clusterConfig
            _clusterConfig =
                    ClusterConfig(
                            enabled = enabled,
                            minimumClusterSize = existing?.minimumClusterSize ?: 2.0,
                            maxZoom = existing?.maxZoom ?: 20.0,
                            backgroundColor = existing?.backgroundColor
                                            ?: MarkerColor(0.0, 122.0, 255.0, 255.0),
                            textColor = existing?.textColor
                                            ?: MarkerColor(255.0, 255.0, 255.0, 255.0),
                            borderWidth = existing?.borderWidth ?: 2.0,
                            borderColor = existing?.borderColor
                                            ?: MarkerColor(255.0, 255.0, 255.0, 255.0),
                            animatesClusters = existing?.animatesClusters ?: true,
                            animationDuration = existing?.animationDuration ?: 0.3,
                            animationStyle = existing?.animationStyle
                                            ?: ClusterAnimationStyle.DEFAULT
                    )
            performClustering()
        }
    }

    override fun refreshClusters() {
        runOnUiThread { performClustering() }
    }

    // MARK: - Camera Methods

    override fun animateToRegion(region: Region, duration: Double) {
        runOnUiThread {
            val map = googleMap ?: return@runOnUiThread
            val camera =
                    CameraPosition.builder()
                            .target(LatLng(region.latitude, region.longitude))
                            .zoom(calculateZoom(region))
                            .build()
            map.animateCamera(CameraUpdateFactory.newCameraPosition(camera), duration.toInt(), null)
        }
    }

    override fun animateCamera(camera: Camera, duration: Double) {
        runOnUiThread {
            val map = googleMap ?: return@runOnUiThread
            val cameraPosition =
                    CameraPosition.builder()
                            .target(LatLng(camera.center.latitude, camera.center.longitude))
                            .zoom(camera.zoom.toFloat())
                            .bearing(camera.heading.toFloat())
                            .tilt(camera.pitch.toFloat())
                            .build()
            map.animateCamera(
                    CameraUpdateFactory.newCameraPosition(cameraPosition),
                    duration.toInt(),
                    null
            )
        }
    }

    override fun setCamera(camera: Camera) {
        runOnUiThread {
            val map = googleMap ?: return@runOnUiThread
            val cameraPosition =
                    CameraPosition.builder()
                            .target(LatLng(camera.center.latitude, camera.center.longitude))
                            .zoom(camera.zoom.toFloat())
                            .bearing(camera.heading.toFloat())
                            .tilt(camera.pitch.toFloat())
                            .build()
            map.moveCamera(CameraUpdateFactory.newCameraPosition(cameraPosition))
        }
    }

    override fun getCamera(): Promise<Camera> = Promise.resolved(getCurrentCamera())

    override fun fitToCoordinates(
            coordinates: Array<Coordinate>,
            padding: EdgePadding,
            animated: Boolean
    ) {
        runOnUiThread {
            val map = googleMap ?: return@runOnUiThread

            if (coordinates.size < 2) {
                coordinates.firstOrNull()?.let {
                    animateToRegion(
                            Region(it.latitude, it.longitude, 0.05, 0.05),
                            if (animated) 300.0 else 0.0
                    )
                }
                return@runOnUiThread
            }

            val boundsBuilder = LatLngBounds.Builder()
            coordinates.forEach { boundsBuilder.include(LatLng(it.latitude, it.longitude)) }
            val bounds = boundsBuilder.build()

            val density = context.resources.displayMetrics.density
            val paddingPx = (padding.top * density).toInt()
            val cameraUpdate = CameraUpdateFactory.newLatLngBounds(bounds, paddingPx)

            if (animated) map.animateCamera(cameraUpdate) else map.moveCamera(cameraUpdate)
        }
    }

    override fun getMapBoundaries(): Promise<MapBoundaries> {
        val map =
                googleMap
                        ?: return Promise.resolved(
                                MapBoundaries(
                                        northEast = Coordinate(0.0, 0.0),
                                        southWest = Coordinate(0.0, 0.0)
                                )
                        )

        val bounds = map.projection.visibleRegion.latLngBounds
        return Promise.resolved(
                MapBoundaries(
                        northEast =
                                Coordinate(bounds.northeast.latitude, bounds.northeast.longitude),
                        southWest =
                                Coordinate(bounds.southwest.latitude, bounds.southwest.longitude)
                )
        )
    }

    override fun getCurrentRegion(): Region {
        val map = googleMap ?: return Region(0.0, 0.0, 0.0, 0.0)
        val cam = map.cameraPosition
        val bounds = map.projection.visibleRegion.latLngBounds
        return Region(
                latitude = cam.target.latitude,
                longitude = cam.target.longitude,
                latitudeDelta = bounds.northeast.latitude - bounds.southwest.latitude,
                longitudeDelta = bounds.northeast.longitude - bounds.southwest.longitude
        )
    }

    // MARK: - Styling

    override fun setMapStyle(style: Array<MapStyleElement>?) {
        runOnUiThread {
            _customMapStyle = style
            applyMapStyle()
        }
    }

    override fun setIsDarkMode(enabled: Boolean) {
        runOnUiThread {
            _darkMode = enabled
            applyDarkModeStyle()
        }
    }

    private fun applyMapStyle() {
        val map = googleMap ?: return
        val styleElements = _customMapStyle

        if (styleElements == null || styleElements.isEmpty()) {
            map.setMapStyle(null)
            return
        }

        try {
            val jsonArray = JSONArray()
            for (element in styleElements) {
                val jsonObject = JSONObject()
                element.featureType?.let { jsonObject.put("featureType", it) }
                element.elementType?.let { jsonObject.put("elementType", it) }

                val stylersArray = JSONArray()
                for (styler in element.stylers) {
                    val stylerObject = JSONObject()
                    styler.color?.let { stylerObject.put("color", it) }
                    styler.visibility?.let { stylerObject.put("visibility", it) }
                    styler.weight?.let { stylerObject.put("weight", it) }
                    styler.saturation?.let { stylerObject.put("saturation", it) }
                    styler.lightness?.let { stylerObject.put("lightness", it) }
                    styler.gamma?.let { stylerObject.put("gamma", it) }
                    stylersArray.put(stylerObject)
                }
                jsonObject.put("stylers", stylersArray)
                jsonArray.put(jsonObject)
            }

            map.setMapStyle(MapStyleOptions(jsonArray.toString()))
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun applyDarkModeStyle() {
        val map = googleMap ?: return
        if (_customMapStyle != null && _customMapStyle!!.isNotEmpty()) return

        if (_darkMode == true) {
            try {
                val darkStyleJson =
                        """[{"elementType":"geometry","stylers":[{"color":"#242f3e"}]},{"elementType":"labels.text.fill","stylers":[{"color":"#746855"}]},{"elementType":"labels.text.stroke","stylers":[{"color":"#242f3e"}]},{"featureType":"water","elementType":"geometry","stylers":[{"color":"#17263c"}]}]"""
                runOnUiThread { map.setMapStyle(MapStyleOptions(darkStyleJson)) }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        } else {
            map.setMapStyle(null)
        }
    }

    // MARK: - Lifecycle

    override fun onResume() {
        _mapView.onResume()
    }
    override fun onPause() {
        _mapView.onPause()
    }
    override fun onDestroy() {
        _mapView.onDestroy()
    }

    // MARK: - Helpers

    private fun runOnUiThread(action: () -> Unit) {
        if (Looper.myLooper() == Looper.getMainLooper()) action() else mainHandler.post(action)
    }

    private fun scheduleClusteringAfterLayout() {
        if (hasLayout && _mapView.width > 0 && _mapView.height > 0) performClustering()
        else needsClusteringAfterLayout = true
    }

    private fun updateCameraToInitialRegion(region: Region) {
        val map = googleMap ?: return
        val camera =
                CameraPosition.builder()
                        .target(LatLng(region.latitude, region.longitude))
                        .zoom(calculateZoom(region))
                        .build()
        map.moveCamera(CameraUpdateFactory.newCameraPosition(camera))
    }

    private fun calculateZoom(region: Region): Float {
        val delta = max(region.latitudeDelta, region.longitudeDelta)
        return when {
            delta < 0.01 -> 16f
            delta < 0.05 -> 14f
            delta < 0.1 -> 12f
            delta < 0.5 -> 10f
            delta < 1.0 -> 8f
            delta < 5.0 -> 6f
            else -> 4f
        }
    }

    private fun convertMapType(type: MapType?): Int =
            when (type) {
                MapType.SATELLITE -> GoogleMap.MAP_TYPE_SATELLITE
                MapType.HYBRID -> GoogleMap.MAP_TYPE_HYBRID
                MapType.STANDARD, null -> GoogleMap.MAP_TYPE_NORMAL
            }

    private fun getCurrentCamera(): Camera {
        val map =
                googleMap
                        ?: return Camera(
                                center = Coordinate(0.0, 0.0),
                                pitch = 0.0,
                                heading = 0.0,
                                altitude = 0.0,
                                zoom = 0.0
                        )
        val cam = map.cameraPosition
        return Camera(
                center = Coordinate(cam.target.latitude, cam.target.longitude),
                pitch = cam.tilt.toDouble(),
                heading = cam.bearing.toDouble(),
                altitude = cam.zoom.toDouble() * 1000,
                zoom = cam.zoom.toDouble()
        )
    }

    private fun hasLocationPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED ||
                ContextCompat.checkSelfPermission(
                        context,
                        Manifest.permission.ACCESS_COARSE_LOCATION
                ) == PackageManager.PERMISSION_GRANTED
    }
}
