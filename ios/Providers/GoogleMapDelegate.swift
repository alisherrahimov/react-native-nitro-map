import Foundation
import GoogleMaps
import GoogleMapsUtils

/// GMSMapViewDelegate implementation for GoogleMapProvider
class GoogleMapDelegate: NSObject, GMSMapViewDelegate {

  weak var provider: GoogleMapProvider?
  private var isGesture: Bool = false
  private var isMapReady: Bool = false
  private var hasPerformedInitialClustering: Bool = false
  private var fallbackClusteringTimer: Timer?

  init(provider: GoogleMapProvider) {
    self.provider = provider
    super.init()

    // Fallback timer for real devices where tile rendering callback may be delayed
    // This ensures clustering happens even if mapViewDidFinishTileRendering is slow
    fallbackClusteringTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
      self?.triggerInitialClusteringIfNeeded()
    }
  }

  deinit {
    fallbackClusteringTimer?.invalidate()
  }

  /// Triggers initial clustering if it hasn't happened yet and the view is ready
  private func triggerInitialClusteringIfNeeded() {
    guard !hasPerformedInitialClustering else { return }
    guard let provider = provider else { return }

    // Check if map view has valid dimensions
    let mapView = provider.mapView
    guard mapView.frame.size.width > 0 && mapView.frame.size.height > 0 else {
      // Retry after a short delay if view isn't laid out yet
      fallbackClusteringTimer?.invalidate()
      fallbackClusteringTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
        self?.triggerInitialClusteringIfNeeded()
      }
      return
    }

    hasPerformedInitialClustering = true
    if !isMapReady {
      isMapReady = true
      provider.onMapReady?()
    }
    provider.performClustering()
  }

  func mapViewDidFinishTileRendering(_ mapView: GMSMapView) {
    fallbackClusteringTimer?.invalidate()
    guard !isMapReady else { return }
    isMapReady = true
    hasPerformedInitialClustering = true
    provider?.onMapReady?()
    provider?.performClustering()
  }

  /// Called when map snapshot is ready - another reliable trigger point
  func mapViewSnapshotReady(_ mapView: GMSMapView) {
    triggerInitialClusteringIfNeeded()
  }
  
  func mapView(_ mapView: GMSMapView, didTapAt coordinate: CLLocationCoordinate2D) {
    let point = mapView.projection.point(for: coordinate)
    let event = MapPressEvent(
      coordinate: Coordinate(
        latitude: coordinate.latitude,
        longitude: coordinate.longitude
      ),
      position: Point(
        x: Double(point.x),
        y: Double(point.y)
      )
    )
    provider?.onPress?(event)
  }
  
  func mapView(_ mapView: GMSMapView, didLongPressAt coordinate: CLLocationCoordinate2D) {
    let point = mapView.projection.point(for: coordinate)
    let event = MapPressEvent(
      coordinate: Coordinate(
        latitude: coordinate.latitude,
        longitude: coordinate.longitude
      ),
      position: Point(
        x: Double(point.x),
        y: Double(point.y)
      )
    )
    provider?.onLongPress?(event)
  }
  
  func mapView(_ mapView: GMSMapView, willMove gesture: Bool) {
    isGesture = gesture
  }
  
  func mapView(_ mapView: GMSMapView, didChange position: GMSCameraPosition) {
    guard let provider = provider else { return }
    let event = RegionChangeEvent(
      region: provider.getCurrentRegion(),
      isGesture: isGesture
    )
    provider.onRegionChange?(event)
  }
  
  func mapView(_ mapView: GMSMapView, idleAt position: GMSCameraPosition) {
    guard let provider = provider else { return }
    let event = RegionChangeEvent(
      region: provider.getCurrentRegion(),
      isGesture: isGesture
    )
    provider.onRegionChangeComplete?(event)
    isGesture = false
    provider.performClustering()
  }
  
  // MARK: - Marker Methods
  
  func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker) -> Bool {
    guard let provider = provider else { return false }
    
    // Check if it's a C++ cluster
    if let clusterData = marker.userData as? ClusterUserData {
      provider.onClusterPress?(
        ClusterPressEvent(
          coordinate: Coordinate(
            latitude: marker.position.latitude,
            longitude: marker.position.longitude
          ),
          markerIds: clusterData.markerIds,
          count: Double(clusterData.count)
        )
      )
      return true
    }
    
    // Check if it's a legacy GMU cluster
    if let cluster = marker.userData as? GMUCluster {
      let markerIds = cluster.items.compactMap {
        ($0 as? NitroClusterItem)?.markerId
      }
      provider.onClusterPress?(
        ClusterPressEvent(
          coordinate: Coordinate(
            latitude: marker.position.latitude,
            longitude: marker.position.longitude
          ),
          markerIds: markerIds,
          count: Double(Int(cluster.count))
        )
      )
      return true
    }
    
    // Check if it's a cluster item
    if let clusterItem = marker.userData as? NitroClusterItem {
      provider.onMarkerPress?(
        MarkerPressEvent(
          id: clusterItem.markerId,
          coordinate: Coordinate(
            latitude: marker.position.latitude,
            longitude: marker.position.longitude
          )
        )
      )
      return true
    }
    
    // Regular marker
    if let markerId = marker.userData as? String {
      provider.onMarkerPress?(
        MarkerPressEvent(
          id: markerId,
          coordinate: Coordinate(
            latitude: marker.position.latitude,
            longitude: marker.position.longitude
          )
        )
      )
      return true
    }
    
    return false
  }
  
  func mapView(_ mapView: GMSMapView, didBeginDragging marker: GMSMarker) {
    guard let provider = provider, let markerId = getMarkerId(from: marker) else { return }
    provider.onMarkerDragStart?(
      MarkerDragEvent(
        id: markerId,
        coordinate: Coordinate(
          latitude: marker.position.latitude,
          longitude: marker.position.longitude
        )
      )
    )
  }
  
  func mapView(_ mapView: GMSMapView, didDrag marker: GMSMarker) {
    guard let provider = provider, let markerId = getMarkerId(from: marker) else { return }
    provider.onMarkerDrag?(
      MarkerDragEvent(
        id: markerId,
        coordinate: Coordinate(
          latitude: marker.position.latitude,
          longitude: marker.position.longitude
        )
      )
    )
  }
  
  func mapView(_ mapView: GMSMapView, didEndDragging marker: GMSMarker) {
    guard let provider = provider, let markerId = getMarkerId(from: marker) else { return }
    provider.onMarkerDragEnd?(
      MarkerDragEvent(
        id: markerId,
        coordinate: Coordinate(
          latitude: marker.position.latitude,
          longitude: marker.position.longitude
        )
      )
    )
  }
  
  private func getMarkerId(from marker: GMSMarker) -> String? {
    if let clusterItem = marker.userData as? NitroClusterItem {
      return clusterItem.markerId
    }
    return marker.userData as? String
  }
}
