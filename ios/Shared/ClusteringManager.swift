import Foundation
import UIKit
import CoreLocation
import GoogleMaps

// MARK: - Clustering Manager Protocol

/// Protocol defining the clustering manager interface.
/// Enables dependency injection and mocking for unit tests.
///
/// Usage:
/// ```swift
/// class GoogleMapProvider: MapProviderProtocol {
///     private let clusteringManager: ClusteringManagerProtocol
///
///     init(clusteringManager: ClusteringManagerProtocol = ClusteringManager()) {
///         self.clusteringManager = clusteringManager
///     }
/// }
/// ```
protocol ClusteringManagerProtocol: AnyObject {
  
  /// Current cluster configuration
  var clusterConfig: ClusterConfig? { get set }
  
  /// Adds a marker to the clustering engine
  func addMarker(_ marker: MarkerData)
  
  /// Removes a marker by ID
  func removeMarker(_ id: String)
  
  /// Clears all markers from the engine
  func clearMarkers()
  
  /// Clusters markers using bounds-based region (MapKit/Yandex)
  func cluster(
    minLat: Double,
    maxLat: Double,
    minLon: Double,
    maxLon: Double,
    zoom: Double,
    mapSize: CGSize
  ) -> NitroClusterEngine.ClusteringResult
  
  /// Clusters markers using visible region (Google Maps)
  func clusterWithVisibleRegion(
    _ visibleRegion: Any,
    zoom: Float,
    mapSize: CGSize
  ) -> NitroClusterEngine.ClusteringResult
  
  /// Executes a clustering action with debouncing to prevent rapid re-clustering
  func debounce(_ action: @escaping () -> Void)
  
  /// Gets a cluster icon for the given count
  func clusterIcon(forCount count: Int) -> UIImage?
}

// MARK: - Clustering Manager Implementation

/// Production implementation of ClusteringManagerProtocol.
/// Wraps the C++ NitroClusterEngine and provides a clean Swift interface.
final class ClusteringManager: ClusteringManagerProtocol {
  
  // MARK: - Private Properties
  
  private let engine: NitroClusterEngine
  private let iconGenerator: NitroClusterIconGenerator
  private var debounceTimer: Timer?
  private let debounceInterval: TimeInterval
  
  // MARK: - Protocol Properties
  
  var clusterConfig: ClusterConfig? {
    didSet {
      iconGenerator.updateConfig(clusterConfig)
      if let config = clusterConfig {
        engine.setMinClusterSize(Int(config.minimumClusterSize))
        engine.setMaxZoom(config.maxZoom)
      }
    }
  }
  
  // MARK: - Initialization
  
  /// Creates a new clustering manager with default configuration
  /// - Parameters:
  ///   - clusterRadius: Radius for clustering in screen points (default: 60)
  ///   - minClusterSize: Minimum markers to form a cluster (default: 2)
  ///   - maxZoom: Maximum zoom level for clustering (default: 20)
  ///   - debounceInterval: Debounce interval in seconds (default: 0.1)
  init(
    clusterRadius: Double = 60.0,
    minClusterSize: Int = 2,
    maxZoom: Double = 20.0,
    debounceInterval: TimeInterval = 0.1
  ) {
    self.engine = NitroClusterEngine()
    self.iconGenerator = NitroClusterIconGenerator()
    self.debounceInterval = debounceInterval
    
    engine.setClusterRadius(clusterRadius)
    engine.setMinClusterSize(minClusterSize)
    engine.setMaxZoom(maxZoom)
  }
  
  deinit {
    debounceTimer?.invalidate()
  }
  
  // MARK: - Marker Management
  
  func addMarker(_ marker: MarkerData) {
    engine.addMarker(marker)
  }
  
  func removeMarker(_ id: String) {
    engine.removeMarker(id)
  }
  
  func clearMarkers() {
    engine.clearMarkers()
  }
  
  // MARK: - Clustering
  
  func cluster(
    minLat: Double,
    maxLat: Double,
    minLon: Double,
    maxLon: Double,
    zoom: Double,
    mapSize: CGSize
  ) -> NitroClusterEngine.ClusteringResult {
    return engine.clusterWithBounds(
      minLat: minLat,
      maxLat: maxLat,
      minLon: minLon,
      maxLon: maxLon,
      zoom: zoom,
      mapSize: mapSize
    )
  }
  
  func clusterWithVisibleRegion(
    _ visibleRegion: Any,
    zoom: Float,
    mapSize: CGSize
  ) -> NitroClusterEngine.ClusteringResult {
    guard let gmsRegion = visibleRegion as? GMSVisibleRegion else {
      // Return empty result if wrong type passed
      return NitroClusterEngine.ClusteringResult(clusters: [], singleMarkers: [])
    }
    return engine.cluster(
      visibleRegion: gmsRegion,
      zoom: zoom,
      mapSize: mapSize
    )
  }
  
  // MARK: - Debouncing
  
  func debounce(_ action: @escaping () -> Void) {
    debounceTimer?.invalidate()
    debounceTimer = Timer.scheduledTimer(
      withTimeInterval: debounceInterval,
      repeats: false
    ) { _ in
      action()
    }
  }
  
  // MARK: - Icon Generation
  
  func clusterIcon(forCount count: Int) -> UIImage? {
    return iconGenerator.icon(forSize: UInt(count))
  }
}

// MARK: - Mock for Unit Tests

#if DEBUG
/// Mock implementation for unit testing
final class MockClusteringManager: ClusteringManagerProtocol {
  
  var clusterConfig: ClusterConfig?
  
  // Tracking for assertions
  private(set) var addedMarkers: [MarkerData] = []
  private(set) var removedMarkerIds: [String] = []
  private(set) var clearMarkersCallCount = 0
  private(set) var clusterCallCount = 0
  
  // Configurable return value
  var mockClusterResult: NitroClusterEngine.ClusteringResult = NitroClusterEngine.ClusteringResult(
    clusters: [],
    singleMarkers: []
  )
  
  func addMarker(_ marker: MarkerData) {
    addedMarkers.append(marker)
  }
  
  func removeMarker(_ id: String) {
    removedMarkerIds.append(id)
  }
  
  func clearMarkers() {
    clearMarkersCallCount += 1
    addedMarkers.removeAll()
  }
  
  func cluster(
    minLat: Double,
    maxLat: Double,
    minLon: Double,
    maxLon: Double,
    zoom: Double,
    mapSize: CGSize
  ) -> NitroClusterEngine.ClusteringResult {
    clusterCallCount += 1
    return mockClusterResult
  }
  
  func clusterWithVisibleRegion(
    _ visibleRegion: Any,
    zoom: Float,
    mapSize: CGSize
  ) -> NitroClusterEngine.ClusteringResult {
    clusterCallCount += 1
    return mockClusterResult
  }
  
  func debounce(_ action: @escaping () -> Void) {
    action() // Execute immediately in tests
  }
  
  func clusterIcon(forCount count: Int) -> UIImage? {
    return nil
  }
}
#endif
