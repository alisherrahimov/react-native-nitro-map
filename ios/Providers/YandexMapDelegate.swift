import Foundation
import YandexMapsMobile

/// YMKMapInputListener, YMKMapCameraListener implementation for YandexMapProvider
class YandexMapDelegate: NSObject {
  
  weak var provider: YandexMapProvider?
  
  // Track last camera position to avoid duplicate events
  private var lastCameraPosition: YMKCameraPosition?
  private var lastFinishedZoom: Float = 0
  
  init(provider: YandexMapProvider) {
    self.provider = provider
    super.init()
  }
  
  private func cameraPositionChanged(_ pos1: YMKCameraPosition?, _ pos2: YMKCameraPosition) -> Bool {
    guard let p1 = pos1 else { return true }
    
    // Check if position changed significantly
    let latDiff = Swift.abs(Double(p1.target.latitude) - Double(pos2.target.latitude))
    let lngDiff = Swift.abs(Double(p1.target.longitude) - Double(pos2.target.longitude))
    let zoomDiff = Swift.abs(Double(p1.zoom) - Double(pos2.zoom))
    
    // Threshold for significant change
    return latDiff > 0.00001 || lngDiff > 0.00001 || zoomDiff > 0.01
  }
}

// MARK: - Map Input Listener (Taps)

extension YandexMapDelegate: YMKMapInputListener {
  
  func onMapTap(with map: YMKMap, point: YMKPoint) {
    let event = MapPressEvent(
      coordinate: Coordinate(latitude: point.latitude, longitude: point.longitude),
      position: Point(x: 0, y: 0)  // Screen position not available directly
    )
    provider?.onPress?(event)
  }
  
  func onMapLongTap(with map: YMKMap, point: YMKPoint) {
    let event = MapPressEvent(
      coordinate: Coordinate(latitude: point.latitude, longitude: point.longitude),
      position: Point(x: 0, y: 0)
    )
    provider?.onLongPress?(event)
  }
}

// MARK: - Camera Listener (Region Changes)

extension YandexMapDelegate: YMKMapCameraListener {
  
  func onCameraPositionChanged(
    with map: YMKMap,
    cameraPosition: YMKCameraPosition,
    cameraUpdateReason: YMKCameraUpdateReason,
    finished: Bool
  ) {
    guard let provider = provider else { return }
    
    // Skip if position hasn't changed significantly
    guard cameraPositionChanged(lastCameraPosition, cameraPosition) else { return }
    
    lastCameraPosition = cameraPosition
    
    let region = provider.getCurrentRegion()
    
    let event = RegionChangeEvent(
      region: region,
      isGesture: cameraUpdateReason == .gestures
    )
    
    if finished {
      // Only fire complete if zoom changed from last finished event
      if abs(lastFinishedZoom - cameraPosition.zoom) > 0.01 || lastFinishedZoom == 0 {
        lastFinishedZoom = cameraPosition.zoom
        provider.onRegionChangeComplete?(event)
      }
    } else {
      provider.onRegionChange?(event)
    }
  }
}

// MARK: - Placemark Tap Listener

extension YandexMapDelegate: YMKMapObjectTapListener {
  
  func onMapObjectTap(with mapObject: YMKMapObject, point: YMKPoint) -> Bool {
    guard let placemark = mapObject as? YMKPlacemarkMapObject,
          let markerId = placemark.userData as? String else {
      return false
    }
    
    let event = MarkerPressEvent(
      id: markerId,
      coordinate: Coordinate(latitude: point.latitude, longitude: point.longitude)
    )
    provider?.onMarkerPress?(event)
    
    return true  // Consume the tap
  }
}

// MARK: - Placemark Drag Listener

extension YandexMapDelegate: YMKMapObjectDragListener {
  
  func onMapObjectDragStart(with mapObject: YMKMapObject) {
    guard let placemark = mapObject as? YMKPlacemarkMapObject,
          let markerId = placemark.userData as? String else {
      return
    }
    
    let position = placemark.geometry
    let event = MarkerDragEvent(
      id: markerId,
      coordinate: Coordinate(latitude: position.latitude, longitude: position.longitude)
    )
    provider?.onMarkerDragStart?(event)
  }
  
  func onMapObjectDrag(with mapObject: YMKMapObject, point: YMKPoint) {
    guard let placemark = mapObject as? YMKPlacemarkMapObject,
          let markerId = placemark.userData as? String else {
      return
    }
    
    let event = MarkerDragEvent(
      id: markerId,
      coordinate: Coordinate(latitude: point.latitude, longitude: point.longitude)
    )
    provider?.onMarkerDrag?(event)
  }
  
  func onMapObjectDragEnd(with mapObject: YMKMapObject) {
    guard let placemark = mapObject as? YMKPlacemarkMapObject,
          let markerId = placemark.userData as? String else {
      return
    }
    
    let position = placemark.geometry
    let event = MarkerDragEvent(
      id: markerId,
      coordinate: Coordinate(latitude: position.latitude, longitude: position.longitude)
    )
    provider?.onMarkerDragEnd?(event)
  }
}

// MARK: - Cluster Listener

extension YandexMapDelegate: YMKClusterListener {
  
  func onClusterAdded(with cluster: YMKCluster) {
    // Configure cluster appearance
    let placemarks = cluster.placemarks
    let count = placemarks.count
    
    // Get cluster config from provider
    let config = provider?.clusterConfig
    
    // Create cluster icon
    let icon = createClusterIcon(count: count, config: config)
    cluster.appearance.setIconWith(icon)
    
    // Add tap listener to cluster
    cluster.addClusterTapListener(with: self)
  }
  
  private func createClusterIcon(count: Int, config: ClusterConfig?) -> UIImage {
    let size: CGFloat = count > 99 ? 50 : (count > 9 ? 44 : 40)
    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    
    UIGraphicsBeginImageContextWithOptions(rect.size, false, 0)
    guard let context = UIGraphicsGetCurrentContext() else {
      return UIImage()
    }
    
    // Background color (Yandex yellow by default)
    let bgColor = config?.backgroundColor.toMarkerColor() ?? MarkerColor(r: 255, g: 204, b: 0, a: 255)
    context.setFillColor(UIColor(
      red: CGFloat(bgColor.r) / 255,
      green: CGFloat(bgColor.g) / 255,
      blue: CGFloat(bgColor.b) / 255,
      alpha: CGFloat(bgColor.a) / 255
    ).cgColor)
    context.fillEllipse(in: rect)

    // Border
    if let borderWidth = config?.borderWidth, borderWidth > 0 {
      let borderColor = config?.borderColor.toMarkerColor() ?? MarkerColor(r: 255, g: 255, b: 255, a: 255)
      context.setStrokeColor(UIColor(
        red: CGFloat(borderColor.r) / 255,
        green: CGFloat(borderColor.g) / 255,
        blue: CGFloat(borderColor.b) / 255,
        alpha: CGFloat(borderColor.a) / 255
      ).cgColor)
      context.setLineWidth(CGFloat(borderWidth))
      let inset = CGFloat(borderWidth) / 2
      context.strokeEllipse(in: rect.insetBy(dx: inset, dy: inset))
    }

    // Text
    let textColor = config?.textColor.toMarkerColor() ?? MarkerColor(r: 0, g: 0, b: 0, a: 255)
    let text = "\(count)"
    let attributes: [NSAttributedString.Key: Any] = [
      .font: UIFont.boldSystemFont(ofSize: size * 0.4),
      .foregroundColor: UIColor(
        red: CGFloat(textColor.r) / 255,
        green: CGFloat(textColor.g) / 255,
        blue: CGFloat(textColor.b) / 255,
        alpha: CGFloat(textColor.a) / 255
      )
    ]
    let textSize = text.size(withAttributes: attributes)
    let textRect = CGRect(
      x: (size - textSize.width) / 2,
      y: (size - textSize.height) / 2,
      width: textSize.width,
      height: textSize.height
    )
    text.draw(in: textRect, withAttributes: attributes)
    
    let image = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
    UIGraphicsEndImageContext()
    
    return image
  }
}

// MARK: - Cluster Tap Listener

extension YandexMapDelegate: YMKClusterTapListener {
  
  func onClusterTap(with cluster: YMKCluster) -> Bool {
    let placemarks = cluster.placemarks
    var markerIds: [String] = []
    
    for placemark in placemarks {
      if let markerId = placemark.userData as? String {
        markerIds.append(markerId)
      }
    }
    
    let center = cluster.appearance.geometry
    
    let event = ClusterPressEvent(
      coordinate: Coordinate(latitude: center.latitude, longitude: center.longitude),
      markerIds: markerIds,
      count: Double(placemarks.count)
    )
    
    provider?.onClusterPress?(event)
    
    return true  // Consume the tap
  }
}
