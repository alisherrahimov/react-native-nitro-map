package com.margelo.nitro.nitromap.clustering

import com.google.android.gms.maps.model.LatLng
import com.google.android.gms.maps.model.LatLngBounds
import com.margelo.nitro.nitromap.ClusterConfig
import com.margelo.nitro.nitromap.MarkerData
import kotlin.math.*

/**
 * Marker point for clustering
 */
data class MarkerPoint(
    val id: String,
    val latitude: Double,
    val longitude: Double
)

/**
 * Cluster result containing multiple markers
 */
data class Cluster(
    val latitude: Double,
    val longitude: Double,
    val markerIds: List<String>,
    val count: Int
)

/**
 * Full clustering result
 */
data class ClusterResult(
    val clusters: List<Cluster>,
    val singleMarkers: List<MarkerPoint>
)

/**
 * High-performance clustering engine using QuadTree spatial indexing
 * Kotlin port of C++ ClusterEngine
 */
class NitroClusterEngine {

    // QuadTree for O(log n) spatial queries
    private var quadTree: QuadTree? = null

    // All markers stored by ID
    private val markers = mutableMapOf<String, MarkerPoint>()

    // Marker data cache for full marker info
    private val markerDataCache = mutableMapOf<String, MarkerData>()

    // Configuration
    private var clusterRadius = 60.0
    private var minClusterSize = 2
    private var maxZoom = 20.0

    // MARK: - Configuration

    fun setClusterRadius(radius: Double) {
        clusterRadius = radius
    }

    fun setMinClusterSize(size: Int) {
        minClusterSize = size
    }

    fun setMaxZoom(zoom: Double) {
        maxZoom = zoom
    }

    fun updateConfig(config: ClusterConfig?) {
        config?.let {
            minClusterSize = it.minimumClusterSize.toInt()
            maxZoom = it.maxZoom
        }
    }

    // MARK: - Marker Management

    fun addMarker(markerData: MarkerData) {
        val id = markerData.id
        val point = MarkerPoint(
            id = id,
            latitude = markerData.coordinate.latitude,
            longitude = markerData.coordinate.longitude
        )
        markers[id] = point
        markerDataCache[id] = markerData
        rebuildQuadTree()
    }

    fun addMarkers(markersList: List<MarkerData>) {
        for (marker in markersList) {
            val id = marker.id
            val point = MarkerPoint(
                id = id,
                latitude = marker.coordinate.latitude,
                longitude = marker.coordinate.longitude
            )
            markers[id] = point
            markerDataCache[id] = marker
        }
        rebuildQuadTree()
    }

    fun removeMarker(id: String) {
        markers.remove(id)
        markerDataCache.remove(id)
        rebuildQuadTree()
    }

    fun clearMarkers() {
        markers.clear()
        markerDataCache.clear()
        quadTree?.clear()
        quadTree = null
    }

    fun getMarkerCount(): Int = markers.size

    fun getMarkerData(id: String): MarkerData? = markerDataCache[id]

    // MARK: - Clustering

    fun cluster(
        bounds: LatLngBounds,
        zoom: Float,
        mapWidth: Int,
        mapHeight: Int
    ): ClusterResult {
        // At max zoom or beyond, don't cluster
        if (zoom >= maxZoom) {
            return ClusterResult(
                clusters = emptyList(),
                singleMarkers = markers.values.toList()
            )
        }

        val tree = quadTree ?: return ClusterResult(emptyList(), markers.values.toList())

        // Calculate cluster radius in coordinate space
        val latSpan = bounds.northeast.latitude - bounds.southwest.latitude
        val lngSpan = bounds.northeast.longitude - bounds.southwest.longitude

        // Pixels to degrees conversion
        val pixelsPerDegreeLat = if (latSpan > 0) mapHeight / latSpan else 1.0
        val pixelsPerDegreeLng = if (lngSpan > 0) mapWidth / lngSpan else 1.0

        // Cluster radius in degrees
        val radiusLat = clusterRadius / pixelsPerDegreeLat
        val radiusLng = clusterRadius / pixelsPerDegreeLng
        val avgRadius = (radiusLat + radiusLng) / 2.0

        // Grid-based clustering for O(n) performance
        val gridSizeLat = radiusLat * 2
        val gridSizeLng = radiusLng * 2

        // Get visible markers
        val visiblePoints = mutableListOf<QuadPoint>()
        val range = BoundingBox(
            bounds.southwest.longitude,
            bounds.southwest.latitude,
            bounds.northeast.longitude,
            bounds.northeast.latitude
        )
        tree.query(range, visiblePoints)

        // Track processed markers
        val processed = mutableSetOf<String>()
        val clusters = mutableListOf<Cluster>()
        val singleMarkers = mutableListOf<MarkerPoint>()

        for (point in visiblePoints) {
            if (processed.contains(point.id)) continue

            // Find nearby markers
            val nearbyPoints = mutableListOf<QuadPoint>()
            tree.queryRadius(point.x, point.y, avgRadius, nearbyPoints)

            // Filter to unprocessed points
            val unprocessedNearby = nearbyPoints.filter { !processed.contains(it.id) }

            if (unprocessedNearby.size >= minClusterSize) {
                // Create cluster
                var sumLat = 0.0
                var sumLng = 0.0
                val markerIds = mutableListOf<String>()

                for (nearby in unprocessedNearby) {
                    sumLng += nearby.x
                    sumLat += nearby.y
                    markerIds.add(nearby.id)
                    processed.add(nearby.id)
                }

                val count = unprocessedNearby.size
                clusters.add(
                    Cluster(
                        latitude = sumLat / count,
                        longitude = sumLng / count,
                        markerIds = markerIds,
                        count = count
                    )
                )
            } else {
                // Single marker
                processed.add(point.id)
                markers[point.id]?.let { singleMarkers.add(it) }
            }
        }

        return ClusterResult(clusters, singleMarkers)
    }

    private fun rebuildQuadTree() {
        if (markers.isEmpty()) {
            quadTree = null
            return
        }

        // Find bounds
        var minLat = Double.MAX_VALUE
        var maxLat = -Double.MAX_VALUE
        var minLng = Double.MAX_VALUE
        var maxLng = -Double.MAX_VALUE

        for (marker in markers.values) {
            minLat = min(minLat, marker.latitude)
            maxLat = max(maxLat, marker.latitude)
            minLng = min(minLng, marker.longitude)
            maxLng = max(maxLng, marker.longitude)
        }

        // Add padding
        val latPadding = (maxLat - minLat) * 0.1 + 0.001
        val lngPadding = (maxLng - minLng) * 0.1 + 0.001

        val bounds = BoundingBox(
            minLng - lngPadding,
            minLat - latPadding,
            maxLng + lngPadding,
            maxLat + latPadding
        )

        quadTree = QuadTree(bounds)

        for (marker in markers.values) {
            quadTree?.insert(
                QuadPoint(marker.longitude, marker.latitude, marker.id)
            )
        }
    }
}
