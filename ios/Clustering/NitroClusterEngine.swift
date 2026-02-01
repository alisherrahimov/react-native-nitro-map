import Foundation
import GoogleMaps

/// Swift wrapper for C++ ClusterEngine via Objective-C++ bridge
/// Provides high-performance clustering using QuadTree spatial indexing
class NitroClusterEngine {

    private let engine: ClusterEngineWrapper
    private var markerDataCache: [String: MarkerData] = [:]

    init() {
        engine = ClusterEngineWrapper()
    }

    // MARK: - Configuration

    func setClusterRadius(_ radius: Double) {
        engine.setClusterRadius(radius)
    }

    func setMinClusterSize(_ size: Int) {
        engine.setMinClusterSize(size)
    }

    func setMaxZoom(_ zoom: Double) {
        engine.setMaxZoom(zoom)
    }

    func updateConfig(_ config: ClusterConfig?) {
        guard let config = config else { return }
        setMinClusterSize(Int(config.minimumClusterSize))
        setMaxZoom(config.maxZoom)
    }

    // MARK: - Marker Management

    func addMarker(_ markerData: MarkerData) {
        let id = markerData.id
        markerDataCache[id] = markerData

        engine.addMarker(
            withId: id,
            latitude: markerData.coordinate.latitude,
            longitude: markerData.coordinate.longitude
        )
    }

    func addMarkers(_ markers: [MarkerData]) {
        for marker in markers {
            addMarker(marker)
        }
    }

    func removeMarker(_ id: String) {
        markerDataCache.removeValue(forKey: id)
        engine.removeMarker(withId: id)
    }

    func clearMarkers() {
        markerDataCache.removeAll()
        engine.clearMarkers()
    }

    func getMarkerCount() -> Int {
        return Int(engine.markerCount())
    }

    func getMarkerData(for id: String) -> MarkerData? {
        return markerDataCache[id]
    }

    // MARK: - Clustering

    struct ClusteringResult {
        var clusters: [ClusterDataResult]
        var singleMarkers: [MarkerData]
    }

    struct ClusterDataResult {
        var coordinate: CLLocationCoordinate2D
        var markerIds: [String]
        var count: Int
    }

    func cluster(
        visibleRegion: GMSVisibleRegion,
        zoom: Float,
        mapSize: CGSize
    ) -> ClusteringResult {
        // Get bounds from visible region
        let bounds = GMSCoordinateBounds(region: visibleRegion)
        
        return clusterWithBounds(
            minLat: bounds.southWest.latitude,
            maxLat: bounds.northEast.latitude,
            minLon: bounds.southWest.longitude,
            maxLon: bounds.northEast.longitude,
            zoom: Double(zoom),
            mapSize: mapSize
        )
    }
    
    /// Provider-agnostic clustering method - works with any map SDK
    func clusterWithBounds(
        minLat: Double,
        maxLat: Double,
        minLon: Double,
        maxLon: Double,
        zoom: Double,
        mapSize: CGSize
    ) -> ClusteringResult {
        let objcResult = engine.cluster(
            withMinLat: minLat,
            maxLat: maxLat,
            minLon: minLon,
            maxLon: maxLon,
            zoom: zoom,
            mapWidth: Double(mapSize.width),
            mapHeight: Double(mapSize.height)
        )

        var clusters: [ClusterDataResult] = []
        var singleMarkers: [MarkerData] = []

        // Process clusters
        for clusterData in objcResult.clusters {
            let cluster = ClusterDataResult(
                coordinate: CLLocationCoordinate2D(
                    latitude: clusterData.latitude,
                    longitude: clusterData.longitude
                ),
                markerIds: clusterData.markerIds as [String],
                count: clusterData.count
            )
            clusters.append(cluster)
        }

        // Process single markers
        for point in objcResult.singleMarkers {
            if let markerData = markerDataCache[point.markerId] {
                singleMarkers.append(markerData)
            }
        }

        return ClusteringResult(clusters: clusters, singleMarkers: singleMarkers)
    }
}
