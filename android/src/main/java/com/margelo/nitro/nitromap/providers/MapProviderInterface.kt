package com.margelo.nitro.nitromap.providers

import android.view.View
import com.margelo.nitro.core.Promise
import com.margelo.nitro.nitromap.*

/** Interface for map providers (Google, Yandex) Mirrors iOS MapProviderProtocol */
interface MapProviderInterface {

    // MARK: - View
    val mapView: View

    // MARK: - Setup
    fun setup()
    fun onResume()
    fun onPause()
    fun onDestroy()

    // MARK: - Properties
    var initialRegion: Region?
    var showsUserLocation: Boolean?
    var showsMyLocationButton: Boolean?
    var zoomEnabled: Boolean?
    var scrollEnabled: Boolean?
    var rotateEnabled: Boolean?
    var pitchEnabled: Boolean?
    var mapType: MapType?
    var clusterConfig: ClusterConfig?
    var darkMode: Boolean?
    var customMapStyle: Array<MapStyleElement>?

    // MARK: - Callbacks
    var onMapReady: (() -> Unit)?
    var onPress: ((event: MapPressEvent) -> Unit)?
    var onLongPress: ((event: MapPressEvent) -> Unit)?
    var onRegionChange: ((event: RegionChangeEvent) -> Unit)?
    var onRegionChangeComplete: ((event: RegionChangeEvent) -> Unit)?
    var onMarkerPress: ((event: MarkerPressEvent) -> Unit)?
    var onMarkerDragStart: ((event: MarkerDragEvent) -> Unit)?
    var onMarkerDrag: ((event: MarkerDragEvent) -> Unit)?
    var onMarkerDragEnd: ((event: MarkerDragEvent) -> Unit)?
    var onClusterPress: ((event: ClusterPressEvent) -> Unit)?

    // MARK: - Camera Methods
    fun animateToRegion(region: Region, duration: Double)
    fun animateCamera(camera: Camera, duration: Double)
    fun setCamera(camera: Camera)
    fun getCamera(): Promise<Camera>
    fun fitToCoordinates(coordinates: Array<Coordinate>, padding: EdgePadding, animated: Boolean)
    fun getMapBoundaries(): Promise<MapBoundaries>
    fun getCurrentRegion(): Region

    // MARK: - Marker Methods
    fun addMarker(marker: MarkerData)
    fun addMarkers(markers: Array<MarkerData>)
    fun updateMarker(marker: MarkerData)
    fun removeMarker(id: String)
    fun clearMarkers()
    fun selectMarker(id: String)

    // MARK: - Clustering
    fun setClusteringEnabled(enabled: Boolean)
    fun refreshClusters()
    fun performClustering()

    // MARK: - Styling
    fun setMapStyle(style: Array<MapStyleElement>?)
    fun setIsDarkMode(enabled: Boolean)
}
