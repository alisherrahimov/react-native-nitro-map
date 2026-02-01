package com.margelo.nitro.nitromap

import android.view.View
import com.facebook.proguard.annotations.DoNotStrip
import com.facebook.react.uimanager.ThemedReactContext
import com.margelo.nitro.core.Promise
import com.margelo.nitro.nitromap.providers.GoogleMapProvider
import com.margelo.nitro.nitromap.providers.MapProviderInterface
import com.margelo.nitro.nitromap.providers.YandexMapProvider

/**
 * HybridNitroMap - Pure facade that delegates all operations to map providers.
 * 
 * This class serves as the bridge between React Native and native map implementations.
 * It does NOT contain any map logic itself - all functionality is delegated to the
 * currently active MapProviderInterface implementation.
 * 
 * Supported providers:
 * - Google Maps (default)
 * - Yandex Maps
 * - Apple Maps (falls back to Google on Android)
 */
@DoNotStrip
class HybridNitroMap(val context: ThemedReactContext) : HybridNitroMapSpec() {

    // ============================================================================
    // MARK: - Provider Management
    // ============================================================================

    private var currentProvider: MapProviderInterface
    private var _provider: MapProvider = MapProvider.GOOGLE

    // Container for provider views
    private val containerView: android.widget.FrameLayout = android.widget.FrameLayout(context)

    override val view: View
        get() = containerView

    @get:DoNotStrip
    @set:DoNotStrip
    override var provider: MapProvider?
        get() = _provider
        set(value) {
            if (value != null && value != _provider) {
                _provider = value
                switchProvider(value)
            }
        }

    init {
        // Initialize with default provider
        currentProvider = createProvider(_provider)
        setupProvider(currentProvider)
    }

    private fun createProvider(providerType: MapProvider): MapProviderInterface {
        return when (providerType) {
            MapProvider.YANDEX -> YandexMapProvider(context)
            MapProvider.GOOGLE -> GoogleMapProvider(context)
            MapProvider.APPLE -> GoogleMapProvider(context) // Fallback to Google on Android
        }
    }

    private fun setupProvider(provider: MapProviderInterface) {
        // Forward all callbacks
        provider.onMapReady = _onMapReady
        provider.onPress = _onPress
        provider.onLongPress = _onLongPress
        provider.onRegionChange = _onRegionChange
        provider.onRegionChangeComplete = _onRegionChangeComplete
        provider.onMarkerPress = _onMarkerPress
        provider.onMarkerDragStart = _onMarkerDragStart
        provider.onMarkerDrag = _onMarkerDrag
        provider.onMarkerDragEnd = _onMarkerDragEnd
        provider.onClusterPress = _onClusterPress

        // Forward all properties
        provider.initialRegion = _initialRegion
        provider.showsUserLocation = _showsUserLocation
        provider.showsMyLocationButton = _showsMyLocationButton
        provider.zoomEnabled = _zoomEnabled
        provider.scrollEnabled = _scrollEnabled
        provider.rotateEnabled = _rotateEnabled
        provider.pitchEnabled = _pitchEnabled
        provider.mapType = _mapType
        provider.clusterConfig = _clusterConfig
        provider.darkMode = _darkMode
        provider.customMapStyle = _customMapStyle

        // Setup the provider
        provider.setup()

        // Add provider view to container
        containerView.addView(
            provider.mapView,
            android.widget.FrameLayout.LayoutParams(
                android.widget.FrameLayout.LayoutParams.MATCH_PARENT,
                android.widget.FrameLayout.LayoutParams.MATCH_PARENT
            )
        )
    }

    private fun switchProvider(newProviderType: MapProvider) {
        // Store existing markers before switching
        val existingMarkers = mutableListOf<MarkerData>()
        // Note: Markers are stored in provider, we'll need to re-add them

        // Remove current provider view
        containerView.removeAllViews()

        // Cleanup old provider
        currentProvider.onDestroy()

        // Create and setup new provider
        currentProvider = createProvider(newProviderType)
        setupProvider(currentProvider)

        // Re-add existing markers
        if (existingMarkers.isNotEmpty()) {
            currentProvider.addMarkers(existingMarkers.toTypedArray())
        }
    }

    // ============================================================================
    // MARK: - Properties (stored locally, forwarded to provider)
    // ============================================================================

    private var _initialRegion: Region? = null
    override var initialRegion: Region?
        get() = _initialRegion
        set(value) {
            _initialRegion = value
            currentProvider.initialRegion = value
        }

    private var _showsUserLocation: Boolean? = null
    override var showsUserLocation: Boolean?
        get() = _showsUserLocation
        set(value) {
            _showsUserLocation = value
            currentProvider.showsUserLocation = value
        }

    private var _showsMyLocationButton: Boolean? = null
    override var showsMyLocationButton: Boolean?
        get() = _showsMyLocationButton
        set(value) {
            _showsMyLocationButton = value
            currentProvider.showsMyLocationButton = value
        }

    private var _zoomEnabled: Boolean? = null
    override var zoomEnabled: Boolean?
        get() = _zoomEnabled
        set(value) {
            _zoomEnabled = value
            currentProvider.zoomEnabled = value
        }

    private var _scrollEnabled: Boolean? = null
    override var scrollEnabled: Boolean?
        get() = _scrollEnabled
        set(value) {
            _scrollEnabled = value
            currentProvider.scrollEnabled = value
        }

    private var _rotateEnabled: Boolean? = null
    override var rotateEnabled: Boolean?
        get() = _rotateEnabled
        set(value) {
            _rotateEnabled = value
            currentProvider.rotateEnabled = value
        }

    private var _pitchEnabled: Boolean? = null
    override var pitchEnabled: Boolean?
        get() = _pitchEnabled
        set(value) {
            _pitchEnabled = value
            currentProvider.pitchEnabled = value
        }

    private var _mapType: MapType? = null
    override var mapType: MapType?
        get() = _mapType
        set(value) {
            _mapType = value
            currentProvider.mapType = value
        }

    private var _clusterConfig: ClusterConfig? = null
    override var clusterConfig: ClusterConfig?
        get() = _clusterConfig
        set(value) {
            _clusterConfig = value
            currentProvider.clusterConfig = value
        }

    private var _customMapStyle: Array<MapStyleElement>? = null
    override var customMapStyle: Array<MapStyleElement>?
        get() = _customMapStyle
        set(value) {
            _customMapStyle = value
            currentProvider.customMapStyle = value
        }

    private var _darkMode: Boolean? = false
    @get:DoNotStrip
    @set:DoNotStrip
    override var darkMode: Boolean?
        get() = _darkMode
        set(value) {
            _darkMode = value
            currentProvider.darkMode = value
        }

    // ============================================================================
    // MARK: - Callbacks (stored locally, forwarded to provider)
    // ============================================================================

    private var _onPress: ((event: MapPressEvent) -> Unit)? = null
    override var onPress: ((event: MapPressEvent) -> Unit)?
        get() = _onPress
        set(value) {
            _onPress = value
            currentProvider.onPress = value
        }

    private var _onLongPress: ((event: MapPressEvent) -> Unit)? = null
    override var onLongPress: ((event: MapPressEvent) -> Unit)?
        get() = _onLongPress
        set(value) {
            _onLongPress = value
            currentProvider.onLongPress = value
        }

    private var _onMapReady: (() -> Unit)? = null
    override var onMapReady: (() -> Unit)?
        get() = _onMapReady
        set(value) {
            _onMapReady = value
            currentProvider.onMapReady = value
        }

    private var _onRegionChange: ((region: RegionChangeEvent) -> Unit)? = null
    override var onRegionChange: ((region: RegionChangeEvent) -> Unit)?
        get() = _onRegionChange
        set(value) {
            _onRegionChange = value
            currentProvider.onRegionChange = value
        }

    private var _onRegionChangeComplete: ((region: RegionChangeEvent) -> Unit)? = null
    override var onRegionChangeComplete: ((region: RegionChangeEvent) -> Unit)?
        get() = _onRegionChangeComplete
        set(value) {
            _onRegionChangeComplete = value
            currentProvider.onRegionChangeComplete = value
        }

    private var _onMarkerPress: ((event: MarkerPressEvent) -> Unit)? = null
    override var onMarkerPress: ((event: MarkerPressEvent) -> Unit)?
        get() = _onMarkerPress
        set(value) {
            _onMarkerPress = value
            currentProvider.onMarkerPress = value
        }

    private var _onMarkerDragStart: ((event: MarkerDragEvent) -> Unit)? = null
    override var onMarkerDragStart: ((event: MarkerDragEvent) -> Unit)?
        get() = _onMarkerDragStart
        set(value) {
            _onMarkerDragStart = value
            currentProvider.onMarkerDragStart = value
        }

    private var _onMarkerDrag: ((event: MarkerDragEvent) -> Unit)? = null
    override var onMarkerDrag: ((event: MarkerDragEvent) -> Unit)?
        get() = _onMarkerDrag
        set(value) {
            _onMarkerDrag = value
            currentProvider.onMarkerDrag = value
        }

    private var _onMarkerDragEnd: ((event: MarkerDragEvent) -> Unit)? = null
    override var onMarkerDragEnd: ((event: MarkerDragEvent) -> Unit)?
        get() = _onMarkerDragEnd
        set(value) {
            _onMarkerDragEnd = value
            currentProvider.onMarkerDragEnd = value
        }

    private var _onClusterPress: ((event: ClusterPressEvent) -> Unit)? = null
    override var onClusterPress: ((event: ClusterPressEvent) -> Unit)?
        get() = _onClusterPress
        set(value) {
            _onClusterPress = value
            currentProvider.onClusterPress = value
        }

    // ============================================================================
    // MARK: - Marker Methods (delegated to provider)
    // ============================================================================

    override fun addMarker(marker: MarkerData) {
        currentProvider.addMarker(marker)
    }

    override fun addMarkers(markers: Array<MarkerData>) {
        currentProvider.addMarkers(markers)
    }

    override fun updateMarker(marker: MarkerData) {
        currentProvider.updateMarker(marker)
    }

    override fun removeMarker(id: String) {
        currentProvider.removeMarker(id)
    }

    override fun clearMarkers() {
        currentProvider.clearMarkers()
    }

    override fun selectMarker(id: String) {
        currentProvider.selectMarker(id)
    }

    // ============================================================================
    // MARK: - Clustering Methods (delegated to provider)
    // ============================================================================

    override fun setClusteringEnabled(enabled: Boolean) {
        currentProvider.setClusteringEnabled(enabled)
    }

    override fun refreshClusters() {
        currentProvider.refreshClusters()
    }

    // ============================================================================
    // MARK: - Camera Methods (delegated to provider)
    // ============================================================================

    override fun animateToRegion(region: Region, duration: Double?) {
        currentProvider.animateToRegion(region, duration ?: 300.0)
    }

    override fun fitToCoordinates(
        coordinates: Array<Coordinate>,
        edgePadding: EdgePadding?,
        animated: Boolean?
    ) {
        currentProvider.fitToCoordinates(
            coordinates,
            edgePadding ?: EdgePadding(50.0, 50.0, 50.0, 50.0),
            animated ?: true
        )
    }

    override fun animateCamera(camera: Camera, duration: Double?) {
        currentProvider.animateCamera(camera, duration ?: 300.0)
    }

    override fun setCamera(camera: Camera) {
        currentProvider.setCamera(camera)
    }

    override fun getCamera(): Promise<Camera> {
        return currentProvider.getCamera()
    }

    override fun getMapBoundaries(): Promise<MapBoundaries> {
        return currentProvider.getMapBoundaries()
    }

    // ============================================================================
    // MARK: - Styling Methods (delegated to provider)
    // ============================================================================

    override fun setMapStyle(style: Array<MapStyleElement>?) {
        currentProvider.setMapStyle(style)
    }

    override fun setIsDarkMode(enabled: Boolean) {
        currentProvider.setIsDarkMode(enabled)
    }

    // ============================================================================
    // MARK: - Lifecycle Methods (delegated to provider)
    // ============================================================================

    override fun beforeUpdate() {
        // No-op: Properties are applied via setters
    }

    override fun afterUpdate() {
        // No-op: Properties are applied via setters
    }

    fun onResume() {
        currentProvider.onResume()
    }

    fun onPause() {
        currentProvider.onPause()
    }

    fun onDestroy() {
        currentProvider.onDestroy()
    }

    fun onLowMemory() {
        // Providers can implement if needed
    }
}
