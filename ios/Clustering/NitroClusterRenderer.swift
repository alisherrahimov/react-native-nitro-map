import Foundation
import GoogleMaps
import GoogleMapsUtils
import UIKit

class NitroClusterRenderer: GMUDefaultClusterRenderer {

  private weak var mapHandler: HybridNitroMap?
  private var clusterConfig: ClusterConfig?

  init(
    mapView: GMSMapView,
    clusterIconGenerator: GMUClusterIconGenerator,
    handler: HybridNitroMap
  ) {
    self.mapHandler = handler
    super.init(mapView: mapView, clusterIconGenerator: clusterIconGenerator)
    // Set self as delegate to customize markers
    self.delegate = self

    // Default animation settings (will be overridden by config)
    self.animatesClusters = true
    self.animationDuration = 0.3
  }

  func updateConfig(_ config: ClusterConfig?) {
    self.clusterConfig = config

    // Apply animation settings from config
    if let config = config {
      self.animatesClusters = config.animatesClusters
      self.animationDuration = config.animationDuration
    }
  }

  override func shouldRender(as cluster: GMUCluster, atZoom zoom: Float) -> Bool {
    let minSize = clusterConfig?.minimumClusterSize ?? 2
    let maxZoom = clusterConfig?.maxZoom ?? 20
    return cluster.count >= UInt(minSize) && zoom <= Float(maxZoom)
  }

  // MARK: - Custom Animation Helpers

  private func applyMarkerAnimation(_ marker: GMSMarker, animation: MarkerAnimation) {
    switch animation {
    case .pop:
      marker.appearAnimation = .pop
    case .fadein:
      marker.appearAnimation = .fadeIn
    case .none:
      marker.appearAnimation = .none
    }
  }

  private func applyCustomAnimation(_ marker: GMSMarker, style: ClusterAnimationStyle) {
    guard let iconView = createAnimatableIconView(for: marker) else { return }

    let duration = clusterConfig?.animationDuration ?? 0.3

    switch style {
    case .bounce:
      applyBounceAnimation(to: iconView, duration: duration)
    case .scale:
      applyScaleAnimation(to: iconView, duration: duration)
    case .fade:
      applyFadeAnimation(to: iconView, duration: duration)
    case .spring:
      applySpringAnimation(to: iconView, duration: duration)
    case .default:
      // Use default Google Maps animation
      break
    }
  }

  private func createAnimatableIconView(for marker: GMSMarker) -> UIView? {
    guard let icon = marker.icon else { return nil }

    let imageView = UIImageView(image: icon)
    imageView.contentMode = .center
    marker.iconView = imageView
    marker.icon = nil

    return imageView
  }

  // MARK: - Animation Implementations

  private func applyBounceAnimation(to view: UIView, duration: Double) {
    view.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)

    UIView.animate(
      withDuration: duration,
      delay: 0,
      usingSpringWithDamping: 0.4,
      initialSpringVelocity: 0.8,
      options: .curveEaseOut
    ) {
      view.transform = .identity
    }
  }

  private func applyScaleAnimation(to view: UIView, duration: Double) {
    view.transform = CGAffineTransform(scaleX: 0.0, y: 0.0)

    UIView.animate(
      withDuration: duration,
      delay: 0,
      options: .curveEaseOut
    ) {
      view.transform = .identity
    }
  }

  private func applyFadeAnimation(to view: UIView, duration: Double) {
    view.alpha = 0.0

    UIView.animate(withDuration: duration) {
      view.alpha = 1.0
    }
  }

  private func applySpringAnimation(to view: UIView, duration: Double) {
    view.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)

    UIView.animate(
      withDuration: duration,
      delay: 0,
      usingSpringWithDamping: 0.5,
      initialSpringVelocity: 1.0,
      options: .curveEaseInOut
    ) {
      view.transform = .identity
    }
  }
}

// MARK: - GMUClusterRendererDelegate
extension NitroClusterRenderer: GMUClusterRendererDelegate {

  func renderer(_ renderer: GMUClusterRenderer, willRenderMarker marker: GMSMarker) {
    // Check if this marker represents a single item (not a cluster)
    if let clusterItem = marker.userData as? NitroClusterItem {
      let markerData = clusterItem.markerData

      // Apply custom icon for individual markers
      if let icon = MarkerIconFactory.createIcon(for: markerData) {
        marker.icon = icon
      }

      marker.groundAnchor = CGPoint(x: markerData.anchor.x, y: markerData.anchor.y)
      marker.isDraggable = markerData.draggable
      marker.opacity = Float(markerData.opacity)
      marker.rotation = markerData.rotation
      marker.zIndex = Int32(markerData.zIndex)

      // Apply marker appearance animation
      applyMarkerAnimation(marker, animation: markerData.animation)

      // Apply custom cluster animation style if not default
      if let style = clusterConfig?.animationStyle, style != .default {
        applyCustomAnimation(marker, style: style)
      }
    }
  }
}
