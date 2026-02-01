import Foundation
import NitroModules
import UIKit

/// HybridNitroMap - Delegates to map provider based on configuration
/// Supports Google Maps, Apple Maps, and Yandex Maps via provider pattern
class HybridNitroMap: HybridNitroMapSpec {

  // MARK: - Provider
  
  // Container view that holds the actual map provider view
  private let containerView: UIView = {
    let view = UIView()
    view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    return view
  }()

  private var _mapProvider: MapProviderProtocol?
  private var currentProviderType: MapProviderType = .google
  private var providerInitialized: Bool = false

  private var mapProvider: MapProviderProtocol {
    if _mapProvider == nil {
      initializeProvider()
    }
    return _mapProvider!
  }
  
  private func initializeProvider() {
    // Remove old provider view if exists
    _mapProvider?.mapView.removeFromSuperview()
    
    // Create new provider
    _mapProvider = MapProviderFactory.createProvider(type: currentProviderType)
    _mapProvider?.setup()
    
    // Add provider view to container
    if let providerView = _mapProvider?.mapView {
      providerView.frame = containerView.bounds
      providerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      containerView.addSubview(providerView)
    }
    
    providerInitialized = true
    
    // Re-apply all current settings to new provider
    applyCurrentSettings()
  }
  
  private func applyCurrentSettings() {
    guard let provider = _mapProvider else { return }
    
    // Re-apply all props to new provider
    provider.initialRegion = initialRegion
    provider.showsUserLocation = showsUserLocation
    provider.zoomEnabled = zoomEnabled
    provider.scrollEnabled = scrollEnabled
    provider.rotateEnabled = rotateEnabled
    provider.pitchEnabled = pitchEnabled
    provider.mapType = mapType
    provider.showsMyLocationButton = showsMyLocationButton
    provider.clusterConfig = clusterConfig
    provider.customMapStyle = customMapStyle
    provider.darkMode = darkMode
    
    // Re-apply callbacks
    provider.onPress = onPress
    provider.onLongPress = onLongPress
    provider.onMapReady = onMapReady
    provider.onRegionChange = onRegionChange
    provider.onRegionChangeComplete = onRegionChangeComplete
    provider.onMarkerPress = onMarkerPress
    provider.onMarkerDragStart = onMarkerDragStart
    provider.onMarkerDrag = onMarkerDrag
    provider.onMarkerDragEnd = onMarkerDragEnd
    provider.onClusterPress = onClusterPress
  }

  var view: UIView { return containerView }

  // Provider prop from JS (MapProvider enum: google | apple | yandex)
  var provider: MapProvider? {
    didSet {
      guard let providerEnum = provider else { return }
      
      let newType: MapProviderType
      switch providerEnum {
      case .apple:
        newType = .apple
      case .yandex:
        newType = .yandex
      case .google:
        newType = .google
      }
      
      // Only reinitialize if provider type actually changed
      if newType != currentProviderType || !providerInitialized {
        currentProviderType = newType
        // Force reinitialization with new provider type
        initializeProvider()
      }
    }
  }

  // MARK: - Properties (forwarded to mapProvider)

  var initialRegion: Region? {
    didSet { mapProvider.initialRegion = initialRegion }
  }

  var showsUserLocation: Bool? {
    didSet { mapProvider.showsUserLocation = showsUserLocation }
  }

  var zoomEnabled: Bool? {
    didSet { mapProvider.zoomEnabled = zoomEnabled }
  }

  var scrollEnabled: Bool? {
    didSet { mapProvider.scrollEnabled = scrollEnabled }
  }

  var rotateEnabled: Bool? {
    didSet { mapProvider.rotateEnabled = rotateEnabled }
  }

  var pitchEnabled: Bool? {
    didSet { mapProvider.pitchEnabled = pitchEnabled }
  }

  var mapType: MapType? {
    didSet { mapProvider.mapType = mapType }
  }

  var showsMyLocationButton: Bool? {
    didSet { mapProvider.showsMyLocationButton = showsMyLocationButton }
  }

  var clusterConfig: ClusterConfig? {
    didSet { mapProvider.clusterConfig = clusterConfig }
  }

  var customMapStyle: [MapStyleElement]? {
    didSet { mapProvider.customMapStyle = customMapStyle }
  }

  var darkMode: Bool? {
    didSet { mapProvider.darkMode = darkMode }
  }

  // MARK: - Callbacks (forwarded to provider)

  var onPress: ((MapPressEvent) -> Void)? {
    didSet { mapProvider.onPress = onPress }
  }

  var onLongPress: ((MapPressEvent) -> Void)? {
    didSet { mapProvider.onLongPress = onLongPress }
  }

  var onMapReady: (() -> Void)? {
    didSet { mapProvider.onMapReady = onMapReady }
  }

  var onRegionChange: ((RegionChangeEvent) -> Void)? {
    didSet { mapProvider.onRegionChange = onRegionChange }
  }

  var onRegionChangeComplete: ((RegionChangeEvent) -> Void)? {
    didSet { mapProvider.onRegionChangeComplete = onRegionChangeComplete }
  }

  var onMarkerPress: ((_ event: MarkerPressEvent) -> Void)? {
    didSet { mapProvider.onMarkerPress = onMarkerPress }
  }

  var onMarkerDragStart: ((_ event: MarkerDragEvent) -> Void)? {
    didSet { mapProvider.onMarkerDragStart = onMarkerDragStart }
  }

  var onMarkerDrag: ((_ event: MarkerDragEvent) -> Void)? {
    didSet { mapProvider.onMarkerDrag = onMarkerDrag }
  }

  var onMarkerDragEnd: ((_ event: MarkerDragEvent) -> Void)? {
    didSet { mapProvider.onMarkerDragEnd = onMarkerDragEnd }
  }

  var onClusterPress: ((_ event: ClusterPressEvent) -> Void)? {
    didSet { mapProvider.onClusterPress = onClusterPress }
  }

  // MARK: - Initialization

  override init() {
    super.init()
  }

  // MARK: - Lifecycle

  func beforeUpdate() {}

  func afterUpdate() {
    mapProvider.updateSettings()
  }

  // MARK: - Camera Methods

  func animateToRegion(region: Region, duration: Double?) throws {
    mapProvider.animateToRegion(region, duration: duration)
  }

  func fitToCoordinates(
    coordinates: [Coordinate],
    edgePadding: EdgePadding?,
    animated: Bool?
  ) throws {
    mapProvider.fitToCoordinates(
      coordinates,
      edgePadding: edgePadding,
      animated: animated
    )
  }

  func animateCamera(camera: Camera, duration: Double?) throws {
    mapProvider.animateCamera(camera, duration: duration)
  }

  func setCamera(camera: Camera) throws {
    DispatchQueue.main.async { [weak self] in
      self?.mapProvider.setCamera(camera)
    }
  }

  func getCamera() throws -> NitroModules.Promise<Camera> {
    return .resolved(withResult: mapProvider.getCamera())
  }

  func getMapBoundaries() throws -> NitroModules.Promise<MapBoundaries> {
    var boundaries: MapBoundaries?

    if Thread.isMainThread {
      boundaries = mapProvider.getMapBoundaries()
    } else {
      DispatchQueue.main.sync { [weak self] in
        boundaries = self?.mapProvider.getMapBoundaries()
      }
    }

    guard let result = boundaries else {
      let empty = MapBoundaries(
        northEast: Coordinate(latitude: 0, longitude: 0),
        southWest: Coordinate(latitude: 0, longitude: 0)
      )
      return .resolved(withResult: empty)
    }

    return .resolved(withResult: result)
  }

  // MARK: - Marker Methods

  func addMarker(marker: MarkerData) throws {
    mapProvider.addMarker(marker)
  }

  func addMarkers(markers: [MarkerData]) throws {
    mapProvider.addMarkers(markers)
  }

  func updateMarker(marker: MarkerData) throws {
    mapProvider.updateMarker(marker)
  }

  func removeMarker(id: String) throws {
    mapProvider.removeMarker(id)
  }

  func clearMarkers() throws {
    mapProvider.clearMarkers()
  }

  func selectMarker(id: String) {
    mapProvider.selectMarker(id)
  }

  // MARK: - Clustering

  func setClusteringEnabled(enabled: Bool) throws {
    DispatchQueue.main.async { [weak self] in
      self?.mapProvider.setClusteringEnabled(enabled)
    }
  }

  func refreshClusters() throws {
    mapProvider.refreshClusters()
  }

  // MARK: - Map Style

  func setMapStyle(style: [MapStyleElement]?) throws {
    mapProvider.setMapStyle(style)
  }

  func setIsDarkMode(enabled isDark: Bool) {
    mapProvider.setDarkMode(isDark)
  }

  // MARK: - Clustering & Region

  func performClustering() {
    mapProvider.performClustering()
  }

  func getCurrentRegion() -> Region {
    return mapProvider.getCurrentRegion()
  }
}

// MARK: - Cluster User Data

/// User data attached to cluster markers for tap handling
struct ClusterUserData {
  let markerIds: [String]
  let count: Int
}
