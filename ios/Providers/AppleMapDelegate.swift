import Foundation
import MapKit

/// MKMapViewDelegate implementation for AppleMapProvider
@available(iOS 17.0, *)
class AppleMapDelegate: NSObject, MKMapViewDelegate {
  
  weak var provider: AppleMapProvider?
  private var isGesture: Bool = false
  
  // Debouncing to prevent infinite loops
  private var lastRegion: MKCoordinateRegion?
  
  init(provider: AppleMapProvider) {
    self.provider = provider
    super.init()
  }
  
  private func regionChanged(_ region1: MKCoordinateRegion?, _ region2: MKCoordinateRegion) -> Bool {
    guard let r1 = region1 else { return true }
    
    let latDiff = Swift.abs(r1.center.latitude - region2.center.latitude)
    let lngDiff = Swift.abs(r1.center.longitude - region2.center.longitude)
    let latSpanDiff = Swift.abs(r1.span.latitudeDelta - region2.span.latitudeDelta)
    let lngSpanDiff = Swift.abs(r1.span.longitudeDelta - region2.span.longitudeDelta)
    
    // Only consider changed if differences are significant
    return latDiff > 0.00001 || lngDiff > 0.00001 || latSpanDiff > 0.0001 || lngSpanDiff > 0.0001
  }
  
  // MARK: - Region Changes
  
  func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
    // Detect if change is from user gesture
    if let gestureRecognizers = mapView.subviews.first?.gestureRecognizers {
      for recognizer in gestureRecognizers {
        if recognizer.state == .began || recognizer.state == .changed {
          isGesture = true
          break
        }
      }
    }
  }
  
  func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
    guard let provider = provider else { return }
    
    // Skip if region hasn't changed significantly (prevents loops)
    guard regionChanged(lastRegion, mapView.region) else { return }
    lastRegion = mapView.region
    
    let event = RegionChangeEvent(
      region: provider.getCurrentRegion(),
      isGesture: isGesture
    )
    provider.onRegionChangeComplete?(event)
    isGesture = false
    
    // Update clustering for new visible region
    provider.performClustering()
  }
  
  // MARK: - Annotation Views
  
  func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
    // Skip user location
    guard !(annotation is MKUserLocation) else { return nil }
    
    // Handle C++ cluster annotations
    if let cluster = annotation as? ClusterAnnotation {
      let view = mapView.dequeueReusableAnnotationView(
        withIdentifier: ClusterAnnotationView.reuseIdentifier,
        for: cluster
      ) as? ClusterAnnotationView
      
      view?.configure(provider: provider)
      return view
    }
    
    // Handle custom annotations
    if let nitroAnnotation = annotation as? NitroAnnotation {
      let view = mapView.dequeueReusableAnnotationView(
        withIdentifier: NitroAnnotationView.reuseIdentifier,
        for: nitroAnnotation
      ) as? NitroAnnotationView
      
      view?.configure(
        with: nitroAnnotation.markerData,
        clusteringEnabled: provider?.isClusteringEnabled() ?? true
      )
      
      return view
    }
    
    return nil
  }
  
  // MARK: - Annotation Selection
  
  func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
    guard let provider = provider else { return }
    
    // Handle C++ cluster selection
    if let cluster = view.annotation as? ClusterAnnotation {
      provider.onClusterPress?(
        ClusterPressEvent(
          coordinate: Coordinate(
            latitude: cluster.coordinate.latitude,
            longitude: cluster.coordinate.longitude
          ),
          markerIds: cluster.markerIds,
          count: Double(cluster.count)
        )
      )
      return
    }
    
    // Handle single marker selection
    if let nitroAnnotation = view.annotation as? NitroAnnotation {
      provider.onMarkerPress?(
        MarkerPressEvent(
          id: nitroAnnotation.markerData.id,
          coordinate: Coordinate(
            latitude: nitroAnnotation.coordinate.latitude,
            longitude: nitroAnnotation.coordinate.longitude
          )
        )
      )
    }
  }
  
  // MARK: - Dragging
  
  func mapView(
    _ mapView: MKMapView,
    annotationView view: MKAnnotationView,
    didChange newState: MKAnnotationView.DragState,
    fromOldState oldState: MKAnnotationView.DragState
  ) {
    guard let provider = provider,
          let nitroAnnotation = view.annotation as? NitroAnnotation else { return }
    
    let markerId = nitroAnnotation.markerData.id
    let coordinate = Coordinate(
      latitude: nitroAnnotation.coordinate.latitude,
      longitude: nitroAnnotation.coordinate.longitude
    )
    
    switch newState {
    case .starting:
      provider.onMarkerDragStart?(
        MarkerDragEvent(id: markerId, coordinate: coordinate)
      )
    case .dragging:
      provider.onMarkerDrag?(
        MarkerDragEvent(id: markerId, coordinate: coordinate)
      )
    case .ending, .canceling:
      provider.onMarkerDragEnd?(
        MarkerDragEvent(id: markerId, coordinate: coordinate)
      )
      view.setDragState(.none, animated: false)
    default:
      break
    }
  }
  
  // MARK: - Map Loading
  
  func mapViewDidFinishLoadingMap(_ mapView: MKMapView) {
    // Map is ready - already called in setup()
  }
}
