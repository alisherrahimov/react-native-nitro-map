import Foundation
import UIKit

// MARK: - Map Style Protocol

/// Protocol for map styling utilities.
/// Provides zoom/altitude conversions and style constants.
protocol MapStyleProviding {
  
  /// Converts lat/lon deltas to approximate zoom level
  func zoomFromDeltas(latDelta: Double, lonDelta: Double) -> Double
  
  /// Converts zoom level to approximate altitude (meters)
  func altitudeFromZoom(_ zoom: Double) -> Double
  
  /// Converts altitude to approximate zoom level
  func zoomFromAltitude(_ altitude: Double) -> Double
  
  /// Gets the dark mode JSON style for Google Maps
  var googleDarkModeStyle: String { get }
}

// MARK: - Implementation

/// Production implementation of map styling utilities.
/// All methods are pure functions - thread-safe and stateless.
final class MapStyleProvider: MapStyleProviding {
  
  // MARK: - Singleton
  
  /// Shared instance for convenience (stateless, so safe to share)
  static let shared = MapStyleProvider()
  
  // MARK: - Constants
  
  /// Earth's approximate circumference at equator in degrees
  private let earthCircumferenceDegrees: Double = 360.0
  
  /// Approximate altitude at zoom level 0 (meters)
  private let baseAltitude: Double = 40_000_000
  
  /// Maximum supported zoom level
  private let maxZoom: Double = 21.0
  
  /// Minimum supported zoom level
  private let minZoom: Double = 0.0
  
  // MARK: - Initialization
  
  init() {}
  
  // MARK: - MapStyleProviding
  
  func zoomFromDeltas(latDelta: Double, lonDelta: Double) -> Double {
    let maxDelta = max(latDelta, lonDelta)
    guard maxDelta > 0 else { return maxZoom }
    
    let zoom = log2(earthCircumferenceDegrees / maxDelta)
    return clamp(zoom, min: minZoom, max: maxZoom)
  }
  
  func altitudeFromZoom(_ zoom: Double) -> Double {
    let clampedZoom = clamp(zoom, min: minZoom, max: maxZoom)
    return baseAltitude / pow(2, clampedZoom)
  }
  
  func zoomFromAltitude(_ altitude: Double) -> Double {
    guard altitude > 0 else { return maxZoom }
    
    let zoom = log2(baseAltitude / altitude)
    return clamp(zoom, min: minZoom, max: maxZoom)
  }
  
  var googleDarkModeStyle: String {
    return Self.darkModeJSON
  }
  
  // MARK: - Private Helpers
  
  private func clamp(_ value: Double, min: Double, max: Double) -> Double {
    return Swift.max(min, Swift.min(max, value))
  }
  
  // MARK: - Dark Mode Style JSON
  
  private static let darkModeJSON = """
  [
    {"elementType": "geometry", "stylers": [{"color": "#242f3e"}]},
    {"elementType": "labels.text.fill", "stylers": [{"color": "#746855"}]},
    {"elementType": "labels.text.stroke", "stylers": [{"color": "#242f3e"}]},
    {"featureType": "administrative.locality", "elementType": "labels.text.fill", "stylers": [{"color": "#d59563"}]},
    {"featureType": "poi", "elementType": "labels.text.fill", "stylers": [{"color": "#d59563"}]},
    {"featureType": "poi.park", "elementType": "geometry", "stylers": [{"color": "#263c3f"}]},
    {"featureType": "poi.park", "elementType": "labels.text.fill", "stylers": [{"color": "#6b9a76"}]},
    {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#38414e"}]},
    {"featureType": "road", "elementType": "geometry.stroke", "stylers": [{"color": "#212a37"}]},
    {"featureType": "road", "elementType": "labels.text.fill", "stylers": [{"color": "#9ca5b3"}]},
    {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#746855"}]},
    {"featureType": "road.highway", "elementType": "geometry.stroke", "stylers": [{"color": "#1f2835"}]},
    {"featureType": "road.highway", "elementType": "labels.text.fill", "stylers": [{"color": "#f3d19c"}]},
    {"featureType": "transit", "elementType": "geometry", "stylers": [{"color": "#2f3948"}]},
    {"featureType": "transit.station", "elementType": "labels.text.fill", "stylers": [{"color": "#d59563"}]},
    {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#17263c"}]},
    {"featureType": "water", "elementType": "labels.text.fill", "stylers": [{"color": "#515c6d"}]},
    {"featureType": "water", "elementType": "labels.text.stroke", "stylers": [{"color": "#17263c"}]}
  ]
  """
}

// MARK: - Mock for Unit Tests

#if DEBUG
/// Mock implementation for unit testing
final class MockMapStyleProvider: MapStyleProviding {
  
  var mockZoom: Double = 10.0
  var mockAltitude: Double = 40000.0
  
  var googleDarkModeStyle: String {
    return "[]" // Empty JSON for testing
  }
  
  func zoomFromDeltas(latDelta: Double, lonDelta: Double) -> Double {
    return mockZoom
  }
  
  func altitudeFromZoom(_ zoom: Double) -> Double {
    return mockAltitude
  }
  
  func zoomFromAltitude(_ altitude: Double) -> Double {
    return mockZoom
  }
}
#endif
