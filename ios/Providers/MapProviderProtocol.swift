import Foundation
import UIKit

/// Protocol that all map providers must implement
/// This allows the library to support multiple map backends (Google, Apple, Yandex)
protocol MapProviderProtocol: AnyObject {
  
  // MARK: - View
  
  /// The underlying map view to be displayed
  var mapView: UIView { get }
  
  // MARK: - Properties
  
  var initialRegion: Region? { get set }
  var showsUserLocation: Bool? { get set }
  var zoomEnabled: Bool? { get set }
  var scrollEnabled: Bool? { get set }
  var rotateEnabled: Bool? { get set }
  var pitchEnabled: Bool? { get set }
  var mapType: MapType? { get set }
  var showsMyLocationButton: Bool? { get set }
  var clusterConfig: ClusterConfig? { get set }
  var customMapStyle: [MapStyleElement]? { get set }
  var darkMode: Bool? { get set }
  
  // MARK: - Callbacks
  
  var onPress: ((MapPressEvent) -> Void)? { get set }
  var onLongPress: ((MapPressEvent) -> Void)? { get set }
  var onMapReady: (() -> Void)? { get set }
  var onRegionChange: ((RegionChangeEvent) -> Void)? { get set }
  var onRegionChangeComplete: ((RegionChangeEvent) -> Void)? { get set }
  var onMarkerPress: ((MarkerPressEvent) -> Void)? { get set }
  var onMarkerDragStart: ((MarkerDragEvent) -> Void)? { get set }
  var onMarkerDrag: ((MarkerDragEvent) -> Void)? { get set }
  var onMarkerDragEnd: ((MarkerDragEvent) -> Void)? { get set }
  var onClusterPress: ((ClusterPressEvent) -> Void)? { get set }
  
  // MARK: - Lifecycle
  
  func setup()
  func updateSettings()
  
  // MARK: - Camera Methods
  
  func animateToRegion(_ region: Region, duration: Double?)
  func fitToCoordinates(_ coordinates: [Coordinate], edgePadding: EdgePadding?, animated: Bool?)
  func animateCamera(_ camera: Camera, duration: Double?)
  func setCamera(_ camera: Camera)
  func getCamera() -> Camera
  func getMapBoundaries() -> MapBoundaries?
  
  // MARK: - Marker Management
  
  func addMarker(_ marker: MarkerData)
  func addMarkers(_ markers: [MarkerData])
  func updateMarker(_ marker: MarkerData)
  func removeMarker(_ id: String)
  func clearMarkers()
  func selectMarker(_ id: String)
  
  // MARK: - Clustering
  
  func setClusteringEnabled(_ enabled: Bool)
  func refreshClusters()
  func performClustering()
  
  // MARK: - Map Style
  
  func setMapStyle(_ style: [MapStyleElement]?)
  func setDarkMode(_ enabled: Bool)
  
  // MARK: - Region
  
  func getCurrentRegion() -> Region
}

// MARK: - Provider Type

enum MapProviderType: String {
  case google = "google"
  case apple = "apple"
  case yandex = "yandex"
}

// MARK: - Provider Factory

class MapProviderFactory {
  
  static func createProvider(type: MapProviderType) -> MapProviderProtocol {
    switch type {
    case .google:
      return GoogleMapProvider()
    case .apple:
      if #available(iOS 17.0, *) {
        print("rendering apple maps")
        return AppleMapProvider()
      } else {
        print("apple checking ios version and i put 17")
        return GoogleMapProvider()
      }
    case .yandex:
      return YandexMapProvider()
    }
  }
}
