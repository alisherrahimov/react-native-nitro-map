package com.margelo.nitro.nitromap.providers

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.PointF
import android.graphics.Rect
import android.graphics.Typeface
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
import androidx.core.content.ContextCompat
import com.margelo.nitro.core.Promise
import com.margelo.nitro.nitromap.*
import com.yandex.mapkit.Animation
import com.yandex.mapkit.geometry.BoundingBox
import com.yandex.mapkit.geometry.Point
import com.yandex.mapkit.map.*
import com.yandex.mapkit.map.Map
import com.yandex.mapkit.mapview.MapView
import com.yandex.runtime.image.ImageProvider
import kotlin.math.max
import kotlin.math.roundToInt

private const val TAG = "YandexMapProvider"

/** Yandex Maps implementation of MapProviderInterface using native clustering */
class YandexMapProvider(private val context: Context) :
        MapProviderInterface, ClusterListener, ClusterTapListener {

    init {
        // Initialize MapKit before creating any views
        com.yandex.mapkit.MapKitFactory.initialize(context)
    }

    private val _mapView: MapView = MapView(context)
    override val mapView: View
        get() = _mapView

    private val map: Map
        get() = _mapView.mapWindow.map
    private val mainHandler = Handler(Looper.getMainLooper())

    // Map object collections - like iOS
    private var mapObjectCollection: MapObjectCollection? = null
    private var clusterCollection: ClusterizedPlacemarkCollection? = null

    // Marker storage
    private val placemarks = mutableMapOf<String, PlacemarkMapObject>()
    private val markerData = mutableMapOf<String, MarkerData>()
    private val clusteredPlacemarkIds = mutableSetOf<String>()

    // Track selected marker ID for visual state
    private var selectedMarkerId: String? = null

    // Tap listener for individual markers
    private val markerTapListener = MapObjectTapListener { mapObject, point ->
        val placemark = mapObject as? PlacemarkMapObject ?: return@MapObjectTapListener false
        val markerId = placemark.userData as? String ?: return@MapObjectTapListener false

        onMarkerPress?.invoke(
                MarkerPressEvent(
                        id = markerId,
                        coordinate = Coordinate(point.latitude, point.longitude)
                )
        )
        true
    }

    // MARK: - Properties

    private var _initialRegion: Region? = null
    private var initialRegionApplied = false
    override var initialRegion: Region?
        get() = _initialRegion
        set(value) {
            _initialRegion = value
            // Only apply initialRegion once to prevent camera reset on re-renders
            if (initialRegionApplied) return
            value?.let {
                updateCameraToInitialRegion(it)
                initialRegionApplied = true
            }
        }

    private var _showsUserLocation: Boolean? = null
    override var showsUserLocation: Boolean?
        get() = _showsUserLocation
        @SuppressLint("MissingPermission")
        set(value) {
            _showsUserLocation = value
        }

    private var _showsMyLocationButton: Boolean? = null
    override var showsMyLocationButton: Boolean?
        get() = _showsMyLocationButton
        set(value) {
            _showsMyLocationButton = value
        }

    private var _zoomEnabled: Boolean? = null
    override var zoomEnabled: Boolean?
        get() = _zoomEnabled
        set(value) {
            _zoomEnabled = value
            map.isZoomGesturesEnabled = value ?: true
        }

    private var _scrollEnabled: Boolean? = null
    override var scrollEnabled: Boolean?
        get() = _scrollEnabled
        set(value) {
            _scrollEnabled = value
            map.isScrollGesturesEnabled = value ?: true
        }

    private var _rotateEnabled: Boolean? = null
    override var rotateEnabled: Boolean?
        get() = _rotateEnabled
        set(value) {
            _rotateEnabled = value
            map.isRotateGesturesEnabled = value ?: true
        }

    private var _pitchEnabled: Boolean? = null
    override var pitchEnabled: Boolean?
        get() = _pitchEnabled
        set(value) {
            _pitchEnabled = value
            map.isTiltGesturesEnabled = value ?: true
        }

    private var _mapType: com.margelo.nitro.nitromap.MapType? = null
    override var mapType: com.margelo.nitro.nitromap.MapType?
        get() = _mapType
        set(value) {
            _mapType = value
        }

    private var _clusterConfig: ClusterConfig? = null
    override var clusterConfig: ClusterConfig?
        get() = _clusterConfig
        set(value) {
            Log.d(
                    TAG,
                    "clusterConfig set: enabled=${value?.enabled}, minSize=${value?.minimumClusterSize}"
            )
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
        Log.d(TAG, "setup() called")
        // Start MapKit and the map view
        com.yandex.mapkit.MapKitFactory.getInstance().onStart()
        _mapView.onStart()

        setupMapListeners()

        // Create map object collection for non-clustered markers (like iOS)
        mapObjectCollection = map.mapObjects.addCollection()
        Log.d(TAG, "setup() - mapObjectCollection created")

        // Set initial camera position
        val defaultPosition =
                CameraPosition(
                        Point(41.311081, 69.240562), // Tashkent
                        10f,
                        0f,
                        0f
                )
        map.move(defaultPosition)

        Log.d(TAG, "setup() complete")
        // Defer onMapReady to allow React Native to finish setting all props
        // (provider prop is set before onMapReady callback prop in RN)
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            Log.d(
                    TAG,
                    "setup() - calling onMapReady (deferred), callback is ${if (onMapReady != null) "SET" else "NULL"}"
            )
            onMapReady?.invoke()
        }
    }

    private fun setupMapListeners() {
        // Tap listener
        map.addInputListener(
                object : InputListener {
                    override fun onMapTap(map: Map, point: Point) {
                        val screenPoint = _mapView.mapWindow.worldToScreen(point)
                        onPress?.invoke(
                                MapPressEvent(
                                        coordinate = Coordinate(point.latitude, point.longitude),
                                        position =
                                                com.margelo.nitro.nitromap.Point(
                                                        screenPoint?.x?.toDouble() ?: 0.0,
                                                        screenPoint?.y?.toDouble() ?: 0.0
                                                )
                                )
                        )
                    }

                    override fun onMapLongTap(map: Map, point: Point) {
                        val screenPoint = _mapView.mapWindow.worldToScreen(point)
                        onLongPress?.invoke(
                                MapPressEvent(
                                        coordinate = Coordinate(point.latitude, point.longitude),
                                        position =
                                                com.margelo.nitro.nitromap.Point(
                                                        screenPoint?.x?.toDouble() ?: 0.0,
                                                        screenPoint?.y?.toDouble() ?: 0.0
                                                )
                                )
                        )
                    }
                }
        )

        // Camera listener
        map.addCameraListener { _, _, reason, finished ->
            val region = getCurrentRegion()
            val isGesture = reason == CameraUpdateReason.GESTURES

            if (!finished) {
                onRegionChange?.invoke(RegionChangeEvent(region = region, isGesture = isGesture))
            } else {
                onRegionChangeComplete?.invoke(
                        RegionChangeEvent(region = region, isGesture = isGesture)
                )
            }
        }
    }

    // MARK: - ClusterListener (Native Yandex Clustering)

    override fun onClusterAdded(cluster: Cluster) {
        // This is called by Yandex SDK when clusters are formed
        val placemarksList = cluster.placemarks
        val count = placemarksList.size

        // Collect marker IDs from cluster
        val markerIds = mutableListOf<String>()
        for (placemark in placemarksList) {
            (placemark.userData as? String)?.let { markerIds.add(it) }
        }

        // Create cluster icon
        val clusterIcon = createClusterIcon(count)
        cluster.appearance.setIcon(ImageProvider.fromBitmap(clusterIcon))

        // Add tap listener to cluster
        cluster.addClusterTapListener(this)
    }

    // MARK: - ClusterTapListener

    override fun onClusterTap(cluster: Cluster): Boolean {
        val placemarksList = cluster.placemarks
        val markerIds = mutableListOf<String>()

        for (placemark in placemarksList) {
            (placemark.userData as? String)?.let { markerIds.add(it) }
        }

        val center = cluster.appearance.geometry

        onClusterPress?.invoke(
                ClusterPressEvent(
                        coordinate = Coordinate(center.latitude, center.longitude),
                        markerIds = markerIds.toTypedArray(),
                        count = placemarksList.size.toDouble()
                )
        )

        return true
    }

    // MARK: - Cluster Icon Generation

    private fun createClusterIcon(count: Int): Bitmap {
        val density = context.resources.displayMetrics.density

        val baseSize =
                when {
                    count > 99 -> 50
                    count > 9 -> 44
                    else -> 40
                }
        val size = (baseSize * density).roundToInt()

        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        // Background color from config or default
        val bgColor =
                _clusterConfig?.backgroundColor?.let { ColorUtils.fromColorValue(it) }
                        ?: Color.parseColor("#FF5722") // Orange-red like iOS screenshot

        val bgPaint =
                Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = bgColor
                    style = Paint.Style.FILL
                }
        canvas.drawCircle(size / 2f, size / 2f, size / 2f - 2 * density, bgPaint)

        // Border
        val borderWidth = _clusterConfig?.borderWidth?.toFloat() ?: 2f
        if (borderWidth > 0) {
            val borderColor =
                    _clusterConfig?.borderColor?.let { ColorUtils.fromColorValue(it) } ?: Color.WHITE
            val borderPaint =
                    Paint(Paint.ANTI_ALIAS_FLAG).apply {
                        color = borderColor
                        style = Paint.Style.STROKE
                        strokeWidth = borderWidth * density
                    }
            canvas.drawCircle(
                    size / 2f,
                    size / 2f,
                    size / 2f - borderWidth * density / 2,
                    borderPaint
            )
        }

        // Text
        val textColor = _clusterConfig?.textColor?.let { ColorUtils.fromColorValue(it) } ?: Color.WHITE
        val text = count.toString()
        val textPaint =
                Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = textColor
                    textSize = size * 0.4f
                    typeface = Typeface.DEFAULT_BOLD
                    textAlign = Paint.Align.CENTER
                }

        val textBounds = Rect()
        textPaint.getTextBounds(text, 0, text.length, textBounds)
        val textY = size / 2f + textBounds.height() / 2f
        canvas.drawText(text, size / 2f, textY, textPaint)

        return bitmap
    }

    // MARK: - Clustering Config

    private fun updateClusterConfig() {
        refreshClusters()
    }

    override fun performClustering() {
        // With native Yandex clustering, we just call clusterPlacemarks
        clusterCollection?.let { collection ->
            val clusterRadius = 60.0
            val minZoom = (_clusterConfig?.maxZoom ?: 20.0).toInt()
            collection.clusterPlacemarks(clusterRadius, minZoom)
        }
    }

    override fun refreshClusters() {
        runOnUiThread {
            // Clear existing cluster collection
            clusterCollection?.clear()
            clusterCollection = null
            clusteredPlacemarkIds.clear()

            // If clustering is disabled, use regular collection
            val clusteringEnabled = _clusterConfig?.enabled ?: true
            if (!clusteringEnabled) {
                recreateMarkersWithoutClustering()
                return@runOnUiThread
            }

            // Create new cluster collection with this as the listener (like iOS)
            clusterCollection = map.mapObjects.addClusterizedPlacemarkCollection(this)

            // Re-add all markers
            for ((id, data) in markerData) {
                if (data.clusteringEnabled) {
                    addPlacemarkToCluster(id, data)
                } else {
                    addPlacemarkToCollection(id, data)
                }
            }

            // Trigger clustering
            val clusterRadius = 60.0
            val minZoom = (_clusterConfig?.maxZoom ?: 20.0).toInt()
            clusterCollection?.clusterPlacemarks(clusterRadius, minZoom)
        }
    }

    private fun recreateMarkersWithoutClustering() {
        // Clear all markers from regular collection
        mapObjectCollection?.clear()
        placemarks.clear()

        // Re-add as regular placemarks
        for ((id, data) in markerData) {
            addPlacemarkToCollection(id, data)
        }
    }

    // MARK: - Marker Management

    override fun addMarker(marker: MarkerData) {
        runOnUiThread { addMarkerSync(marker) }
    }

    override fun addMarkers(markers: Array<MarkerData>) {
        runOnUiThread {
            for (marker in markers) {
                addMarkerSync(marker)
            }
            // Re-cluster after adding all markers
            performClustering()
        }
    }

    private fun addMarkerSync(data: MarkerData) {
        removeMarkerSync(data.id)

        markerData[data.id] = data

        val clusteringEnabled = _clusterConfig?.enabled ?: true

        if (data.clusteringEnabled && clusteringEnabled) {
            // Ensure cluster collection exists
            if (clusterCollection == null) {
                clusterCollection = map.mapObjects.addClusterizedPlacemarkCollection(this)
            }
            addPlacemarkToCluster(data.id, data)

            // Re-cluster after adding
            val clusterRadius = 60.0
            val minZoom = (_clusterConfig?.maxZoom ?: 20.0).toInt()
            clusterCollection?.clusterPlacemarks(clusterRadius, minZoom)
        } else {
            addPlacemarkToCollection(data.id, data)
        }
    }

    private fun addPlacemarkToCollection(id: String, data: MarkerData) {
        // Ensure mapObjectCollection exists
        if (mapObjectCollection == null) {
            mapObjectCollection = map.mapObjects.addCollection()
        }

        val collection = mapObjectCollection ?: return
        val point = Point(data.coordinate.latitude, data.coordinate.longitude)
        val placemark = collection.addPlacemark(point)

        configurePlacemark(placemark, data)
        placemarks[id] = placemark
    }

    private fun addPlacemarkToCluster(id: String, data: MarkerData) {
        val cluster =
                clusterCollection
                        ?: run {
                            return
                        }
        val point = Point(data.coordinate.latitude, data.coordinate.longitude)
        val placemark = cluster.addPlacemark(point)

        configurePlacemark(placemark, data)
        placemarks[id] = placemark
        clusteredPlacemarkIds.add(id)

    }

    private fun configurePlacemark(placemark: PlacemarkMapObject, data: MarkerData) {
        // Set icon - CRITICAL for visibility
        val iconBitmap =
                YandexMarkerIconFactory.createIcon(context, data)
                        ?: YandexMarkerIconFactory.createDefaultMarkerIcon(context)

        // Calculate anchor based on marker style
        val anchor =
                when (data.config.style) {
                    MarkerStyle.IMAGE -> PointF(0.5f, 1.0f) // Bottom center for pins
                    MarkerStyle.PRICEMARKER ->
                            PointF(0.5f, 1.0f) // Bottom center for price bubbles
                    else ->
                            PointF(
                                    data.anchor?.x?.toFloat() ?: 0.5f,
                                    data.anchor?.y?.toFloat() ?: 0.5f
                            )
                }

        val iconStyle =
                IconStyle().apply {
                    setAnchor(anchor)
                    setScale(1.0f)
                }
        placemark.setIcon(ImageProvider.fromBitmap(iconBitmap), iconStyle)

        // Set other properties
        placemark.opacity = data.opacity.toFloat()
        placemark.direction = data.rotation.toFloat()
        placemark.zIndex = data.zIndex.toFloat()
        placemark.isDraggable = data.draggable

        // Store marker ID in userData for tap handling
        placemark.userData = data.id

        // Add tap listener
        placemark.addTapListener(markerTapListener)
    }

    override fun updateMarker(marker: MarkerData) {
        runOnUiThread {
            // Update marker data
            markerData[marker.id] = marker

            // If placemark exists, update it in-place (no flicker!)
            placemarks[marker.id]?.let { placemark ->
                // Update position
                placemark.geometry = Point(marker.coordinate.latitude, marker.coordinate.longitude)

                // Update icon
                val iconBitmap =
                        YandexMarkerIconFactory.createIcon(context, marker)
                                ?: YandexMarkerIconFactory.createDefaultMarkerIcon(context)
                val anchor =
                        PointF(
                                marker.anchor?.x?.toFloat() ?: 0.5f,
                                marker.anchor?.y?.toFloat() ?: 0.5f
                        )
                val iconStyle =
                        IconStyle().apply {
                            setAnchor(anchor)
                            setScale(1.0f)
                        }
                placemark.setIcon(ImageProvider.fromBitmap(iconBitmap), iconStyle)

                // Update other properties
                placemark.opacity = marker.opacity.toFloat()
                placemark.direction = marker.rotation.toFloat()
                placemark.zIndex = marker.zIndex.toFloat()
                placemark.isDraggable = marker.draggable
            }
                    ?: run {
                        // Placemark doesn't exist, add it
                        addMarkerSync(marker)
                    }
        }
    }

    override fun removeMarker(id: String) {
        runOnUiThread {
            removeMarkerSync(id)
            performClustering()
        }
    }

    private fun removeMarkerSync(id: String) {
        markerData.remove(id)

        placemarks[id]?.let { placemark ->
            if (clusteredPlacemarkIds.contains(id)) {
                clusterCollection?.remove(placemark)
                clusteredPlacemarkIds.remove(id)
            } else {
                mapObjectCollection?.remove(placemark)
            }
            placemarks.remove(id)
        }
    }

    override fun selectMarker(id: String) {
        runOnUiThread {
            // Deselect previous marker if exists
            selectedMarkerId?.let { previousId ->
                if (previousId != id) updateMarkerSelectionState(previousId, false)
            }

            // Select new marker
            selectedMarkerId = id
            updateMarkerSelectionState(id, true)

            // Animate to marker position
            placemarks[id]?.let { placemark ->
                val position = placemark.geometry
                val currentCamera = map.cameraPosition

                val newCamera =
                        CameraPosition(
                                position,
                                currentCamera.zoom,
                                currentCamera.azimuth,
                                currentCamera.tilt
                        )

                map.move(newCamera, Animation(Animation.Type.SMOOTH, 0.3f), null)
            }
        }
    }

    private fun updateMarkerSelectionState(id: String, selected: Boolean) {
        val data = markerData[id] ?: return

        // Only priceMarker style supports selected state visually
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

        // Update stored data
        markerData[id] = updatedData

        // Update the placemark's icon
        placemarks[id]?.let { placemark ->
            val iconBitmap =
                    YandexMarkerIconFactory.createIcon(context, updatedData)
                            ?: YandexMarkerIconFactory.createDefaultMarkerIcon(context)
            val iconStyle =
                    IconStyle().apply {
                        setAnchor(
                                PointF(
                                        updatedData.anchor?.x?.toFloat() ?: 0.5f,
                                        updatedData.anchor?.y?.toFloat() ?: 0.5f
                                )
                        )
                        setScale(1.0f)
                    }
            placemark.setIcon(ImageProvider.fromBitmap(iconBitmap), iconStyle)
        }
    }

    override fun clearMarkers() {
        runOnUiThread {
            mapObjectCollection?.clear()
            clusterCollection?.clear()
            placemarks.clear()
            markerData.clear()
            clusteredPlacemarkIds.clear()
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
                                            ?: ColorUtils.defaultColorValue(255.0, 87.0, 34.0, 255.0), // Orange-red
                            textColor = existing?.textColor
                                            ?: ColorUtils.defaultColorValue(255.0, 255.0, 255.0, 255.0),
                            borderWidth = existing?.borderWidth ?: 2.0,
                            borderColor = existing?.borderColor
                                            ?: ColorUtils.defaultColorValue(255.0, 255.0, 255.0, 255.0),
                            animatesClusters = existing?.animatesClusters ?: true,
                            animationDuration = existing?.animationDuration ?: 0.3,
                            animationStyle = existing?.animationStyle
                                            ?: ClusterAnimationStyle.DEFAULT
                    )
            refreshClusters()
        }
    }

    // MARK: - Camera Methods

    override fun animateToRegion(region: Region, duration: Double) {
        runOnUiThread {
            val cameraPosition =
                    CameraPosition(
                            Point(region.latitude, region.longitude),
                            calculateZoom(region),
                            0f,
                            0f
                    )
            map.move(
                    cameraPosition,
                    Animation(Animation.Type.SMOOTH, (duration / 1000).toFloat()),
                    null
            )
        }
    }

    override fun animateCamera(camera: Camera, duration: Double) {
        runOnUiThread {
            val cameraPosition =
                    CameraPosition(
                            Point(camera.center.latitude, camera.center.longitude),
                            camera.zoom.toFloat(),
                            camera.heading.toFloat(),
                            camera.pitch.toFloat()
                    )
            map.move(
                    cameraPosition,
                    Animation(Animation.Type.SMOOTH, (duration / 1000).toFloat()),
                    null
            )
        }
    }

    override fun setCamera(camera: Camera) {
        runOnUiThread {
            val cameraPosition =
                    CameraPosition(
                            Point(camera.center.latitude, camera.center.longitude),
                            camera.zoom.toFloat(),
                            camera.heading.toFloat(),
                            camera.pitch.toFloat()
                    )
            map.move(cameraPosition)
        }
    }

    override fun getCamera(): Promise<Camera> = Promise.resolved(getCurrentCamera())

    override fun fitToCoordinates(
            coordinates: Array<Coordinate>,
            padding: EdgePadding,
            animated: Boolean
    ) {
        runOnUiThread {
            if (coordinates.isEmpty()) return@runOnUiThread

            if (coordinates.size == 1) {
                animateToRegion(
                        Region(coordinates[0].latitude, coordinates[0].longitude, 0.05, 0.05),
                        300.0
                )
                return@runOnUiThread
            }

            var minLat = Double.MAX_VALUE
            var maxLat = -Double.MAX_VALUE
            var minLon = Double.MAX_VALUE
            var maxLon = -Double.MAX_VALUE

            for (coord in coordinates) {
                minLat = minOf(minLat, coord.latitude)
                maxLat = maxOf(maxLat, coord.latitude)
                minLon = minOf(minLon, coord.longitude)
                maxLon = maxOf(maxLon, coord.longitude)
            }

            val geometry =
                    com.yandex.mapkit.geometry.Geometry.fromBoundingBox(
                            BoundingBox(Point(minLat, minLon), Point(maxLat, maxLon))
                    )
            val cameraPosition = map.cameraPosition(geometry)

            if (animated) {
                map.move(cameraPosition, Animation(Animation.Type.SMOOTH, 0.3f), null)
            } else {
                map.move(cameraPosition)
            }
        }
    }

    override fun getMapBoundaries(): Promise<MapBoundaries> {
        val visibleRegion = map.visibleRegion
        return Promise.resolved(
                MapBoundaries(
                        northEast =
                                Coordinate(
                                        visibleRegion.topRight.latitude,
                                        visibleRegion.topRight.longitude
                                ),
                        southWest =
                                Coordinate(
                                        visibleRegion.bottomLeft.latitude,
                                        visibleRegion.bottomLeft.longitude
                                )
                )
        )
    }

    override fun getCurrentRegion(): Region {
        val cam = map.cameraPosition
        val visibleRegion = map.visibleRegion
        return Region(
                latitude = cam.target.latitude,
                longitude = cam.target.longitude,
                latitudeDelta =
                        kotlin.math.abs(
                                visibleRegion.topRight.latitude - visibleRegion.bottomLeft.latitude
                        ),
                longitudeDelta =
                        kotlin.math.abs(
                                visibleRegion.topRight.longitude -
                                        visibleRegion.bottomLeft.longitude
                        )
        )
    }

    // MARK: - Styling

    override fun setMapStyle(style: Array<MapStyleElement>?) {
        runOnUiThread { _customMapStyle = style }
    }

    override fun setIsDarkMode(enabled: Boolean) {
        runOnUiThread {
            _darkMode = enabled
            applyDarkModeStyle()
        }
    }

    private fun applyDarkModeStyle() {
        map.isNightModeEnabled = _darkMode == true
    }

    // MARK: - Lifecycle

    override fun onResume() {
        _mapView.onStart()
    }

    override fun onPause() {
        _mapView.onStop()
    }

    override fun onDestroy() {}

    // MARK: - Helpers

    private fun runOnUiThread(action: () -> Unit) {
        if (Looper.myLooper() == Looper.getMainLooper()) action() else mainHandler.post(action)
    }

    private fun updateCameraToInitialRegion(region: Region) {
        val cameraPosition =
                CameraPosition(
                        Point(region.latitude, region.longitude),
                        calculateZoom(region),
                        0f,
                        0f
                )
        map.move(cameraPosition)
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

    private fun getCurrentCamera(): Camera {
        val cam = map.cameraPosition
        return Camera(
                center = Coordinate(cam.target.latitude, cam.target.longitude),
                pitch = cam.tilt.toDouble(),
                heading = cam.azimuth.toDouble(),
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
