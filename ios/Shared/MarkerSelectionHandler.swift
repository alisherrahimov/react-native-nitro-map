import Foundation
import UIKit

// MARK: - Marker Selection Protocol

/// Protocol for handling marker selection state changes.
/// Enables dependency injection and clean separation of concerns.
protocol MarkerSelectionHandling {
  
  /// Creates an updated MarkerData with the new selection state.
  /// Returns nil if the marker type doesn't support visual selection (only priceMarker does).
  ///
  /// - Parameters:
  ///   - markerData: The original marker data
  ///   - selected: Whether the marker should be selected
  /// - Returns: Updated marker data with new selection state, or nil if unsupported
  func updateSelectionState(for markerData: MarkerData, selected: Bool) -> MarkerData?
}

// MARK: - Implementation

/// Production implementation of marker selection handling.
/// Thread-safe, pure function - can be used from any thread.
final class MarkerSelectionHandler: MarkerSelectionHandling {
  
  // MARK: - Singleton
  
  /// Shared instance for convenience (stateless, so safe to share)
  static let shared = MarkerSelectionHandler()
  
  // MARK: - Initialization
  
  init() {}
  
  // MARK: - MarkerSelectionHandling
  
  func updateSelectionState(for markerData: MarkerData, selected: Bool) -> MarkerData? {
    // Only priceMarker style supports visual selection state
    guard markerData.config.style == .pricemarker,
          let priceConfig = markerData.config.priceMarker else {
      return nil
    }
    
    // Early exit if state hasn't changed
    if priceConfig.selected == selected {
      return nil
    }
    
    // Create updated price config with new selection state
    let updatedPriceConfig = PriceMarkerStyle(
      price: priceConfig.price,
      currency: priceConfig.currency,
      selected: selected,
      backgroundColor: priceConfig.backgroundColor,
      selectedBackgroundColor: priceConfig.selectedBackgroundColor,
      textColor: priceConfig.textColor,
      selectedTextColor: priceConfig.selectedTextColor,
      fontSize: priceConfig.fontSize,
      paddingHorizontal: priceConfig.paddingHorizontal,
      paddingVertical: priceConfig.paddingVertical,
      shadowOpacity: priceConfig.shadowOpacity
    )
    
    // Create updated config
    let updatedConfig = MarkerConfig(
      style: markerData.config.style,
      image: markerData.config.image,
      priceMarker: updatedPriceConfig
    )
    
    // Return new marker data (immutable pattern)
    return MarkerData(
      id: markerData.id,
      coordinate: markerData.coordinate,
      title: markerData.title,
      description: markerData.description,
      draggable: markerData.draggable,
      opacity: markerData.opacity,
      rotation: markerData.rotation,
      zIndex: markerData.zIndex,
      anchor: markerData.anchor,
      config: updatedConfig,
      clusteringEnabled: markerData.clusteringEnabled,
      animation: markerData.animation
    )
  }
}

// MARK: - Mock for Unit Tests

#if DEBUG
/// Mock implementation for unit testing
final class MockMarkerSelectionHandler: MarkerSelectionHandling {
  
  // Tracking for assertions
  private(set) var updateSelectionCallCount = 0
  private(set) var lastMarkerData: MarkerData?
  private(set) var lastSelectedValue: Bool?
  
  // Configurable behavior
  var shouldReturnNil = false
  
  func updateSelectionState(for markerData: MarkerData, selected: Bool) -> MarkerData? {
    updateSelectionCallCount += 1
    lastMarkerData = markerData
    lastSelectedValue = selected
    
    if shouldReturnNil {
      return nil
    }
    
    // Use real implementation for realistic behavior
    return MarkerSelectionHandler.shared.updateSelectionState(for: markerData, selected: selected)
  }
}
#endif
