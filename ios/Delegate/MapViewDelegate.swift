import Foundation
import GoogleMaps
import GoogleMapsUtils

class MapViewDelegate: NSObject, GMSMapViewDelegate {

  weak var handler: HybridNitroMap?
  private var isGesture: Bool = false
  private var isMapReady: Bool = false

  init(handler: HybridNitroMap) {
    self.handler = handler
    super.init()
  }

  func mapViewDidFinishTileRendering(_ mapView: GMSMapView) {
    guard !isMapReady else { return }
    isMapReady = true
    handler?.onMapReady?()

    // Perform initial clustering after map is ready
    handler?.performClustering()
  }

  func mapView(
    _ mapView: GMSMapView,
    didTapAt coordinate: CLLocationCoordinate2D
  ) {
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
    handler?.onPress?(event)
  }

  func mapView(
    _ mapView: GMSMapView,
    didLongPressAt coordinate: CLLocationCoordinate2D
  ) {
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
    handler?.onLongPress?(event)
  }

  func mapView(_ mapView: GMSMapView, willMove gesture: Bool) {
    isGesture = gesture
  }

  func mapView(_ mapView: GMSMapView, didChange position: GMSCameraPosition) {
    guard let handler = handler else { return }
    let event = RegionChangeEvent(
      region: handler.getCurrentRegion(),
      isGesture: isGesture
    )
    handler.onRegionChange?(event)
  }

  func mapView(_ mapView: GMSMapView, idleAt position: GMSCameraPosition) {
    guard let handler = handler else { return }
    let event = RegionChangeEvent(
      region: handler.getCurrentRegion(),
      isGesture: isGesture
    )
    handler.onRegionChangeComplete?(event)
    isGesture = false

    // Re-cluster when camera stops moving (C++ engine)
    handler.performClustering()
  }

  // MARK: - Marker Methods

  func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker) -> Bool {
    guard let handler = handler else { return false }

    // Check if it's a C++ cluster (ClusterUserData)
    if let clusterData = marker.userData as? ClusterUserData {
      handler.onClusterPress?(
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

    // Check if it's a legacy GMU cluster (for backwards compatibility)
    if let cluster = marker.userData as? GMUCluster {
      let markerIds = cluster.items.compactMap {
        ($0 as? NitroClusterItem)?.markerId
      }
      handler.onClusterPress?(
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

    // Check if it's a legacy cluster item (for backwards compatibility)
    if let clusterItem = marker.userData as? NitroClusterItem {
      handler.onMarkerPress?(
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

    // Regular marker (marker ID as string)
    if let markerId = marker.userData as? String {
      handler.onMarkerPress?(
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
    guard let handler = handler, let markerId = getMarkerId(from: marker) else {
      return
    }
    handler.onMarkerDragStart?(
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
    guard let handler = handler, let markerId = getMarkerId(from: marker) else {
      return
    }
    handler.onMarkerDrag?(
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
    guard let handler = handler, let markerId = getMarkerId(from: marker) else {
      return
    }
    handler.onMarkerDragEnd?(
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
