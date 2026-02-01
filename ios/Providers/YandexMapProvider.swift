import Foundation
import UIKit
import YandexMapsMobile

/// Yandex Maps implementation of MapProviderProtocol using YandexMapsMobile SDK
class YandexMapProvider: NSObject, MapProviderProtocol {
  
  // MARK: - Properties
  
  private let ymkMapView: YMKMapView
  var mapView: UIView { return ymkMapView }
  
  private var map: YMKMap { return ymkMapView.mapWindow.map }
  private var mapDelegate: YandexMapDelegate?
  
  // Marker storage
  private var placemarks: [String: YMKPlacemarkMapObject] = [:]
  private var markerData: [String: MarkerData] = [:]
  private var clusteredPlacemarkIds: Set<String> = []  // Track which markers are in cluster collection
  private var mapObjectCollection: YMKMapObjectCollection?
  private var clusterCollection: YMKClusterizedPlacemarkCollection?
  
  // MARK: - Protocol Properties
  
  var initialRegion: Region? {
    didSet { updateCameraToInitialRegion() }
  }
  
  var showsUserLocation: Bool? {
    didSet { configureUserLocation() }
  }
  
  var zoomEnabled: Bool? {
    didSet { map.isZoomGesturesEnabled = zoomEnabled ?? true }
  }
  
  var scrollEnabled: Bool? {
    didSet { map.isScrollGesturesEnabled = scrollEnabled ?? true }
  }
  
  var rotateEnabled: Bool? {
    didSet { map.isRotateGesturesEnabled = rotateEnabled ?? true }
  }
  
  var pitchEnabled: Bool? {
    didSet { map.isTiltGesturesEnabled = pitchEnabled ?? true }
  }
  
  var mapType: MapType? {
    didSet { configureMapType() }
  }
  
  var showsMyLocationButton: Bool? {
    didSet {
      // Yandex doesn't have a built-in location button
      // Would need custom implementation
    }
  }
  
  var clusterConfig: ClusterConfig? {
    didSet { updateClusterConfig() }
  }
  
  var customMapStyle: [MapStyleElement]? {
    didSet {
      // Yandex uses a different style format
      // Would need conversion from Google-style JSON
    }
  }
  
  var darkMode: Bool? {
    didSet { applyDarkMode() }
  }
  
  // MARK: - Callbacks
  
  var onPress: ((MapPressEvent) -> Void)?
  var onLongPress: ((MapPressEvent) -> Void)?
  var onMapReady: (() -> Void)?
  var onRegionChange: ((RegionChangeEvent) -> Void)?
  var onRegionChangeComplete: ((RegionChangeEvent) -> Void)?
  var onMarkerPress: ((MarkerPressEvent) -> Void)?
  var onMarkerDragStart: ((MarkerDragEvent) -> Void)?
  var onMarkerDrag: ((MarkerDragEvent) -> Void)?
  var onMarkerDragEnd: ((MarkerDragEvent) -> Void)?
  var onClusterPress: ((ClusterPressEvent) -> Void)?
  
  // User location layer
  private var userLocationLayer: YMKUserLocationLayer?
  
  // MARK: - Initialization
  
  override init() {
    // Create map view
    ymkMapView = YMKMapView(frame: .zero)
    ymkMapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    
    super.init()
  }
  
  // MARK: - Static API Key Setup
  
  /// Call this from AppDelegate before using Yandex Maps
  static func setApiKey(_ apiKey: String) {
    YMKMapKit.setApiKey(apiKey)
  }
  
  // MARK: - Lifecycle
  
  func setup() {
    print("🗺️ YandexMapProvider: setup() called")
    print("🗺️ YandexMapProvider: mapView frame = \(ymkMapView.frame)")
    print("🗺️ YandexMapProvider: mapWindow = \(ymkMapView.mapWindow)")
    
    mapDelegate = YandexMapDelegate(provider: self)
    
    // Set up input listener for taps
    map.addInputListener(with: mapDelegate!)
    
    // Set up camera listener for region changes
    map.addCameraListener(with: mapDelegate!)
    
    // Create map object collection for markers
    mapObjectCollection = map.mapObjects.add()
    
    // Set initial camera position to make sure map is visible
    let defaultPosition = YMKCameraPosition(
      target: YMKPoint(latitude: 41.311081, longitude: 69.240562),  // Tashkent
      zoom: 10.0,
      azimuth: 0,
      tilt: 0
    )
    map.move(with: defaultPosition)
    
    print("🗺️ YandexMapProvider: setup() complete, camera position set")
    
    // Notify map ready
    DispatchQueue.main.async { [weak self] in
      self?.onMapReady?()
      print("🗺️ YandexMapProvider: onMapReady called")
    }
  }
  
  func updateSettings() {
    map.isZoomGesturesEnabled = zoomEnabled ?? true
    map.isScrollGesturesEnabled = scrollEnabled ?? true
    map.isRotateGesturesEnabled = rotateEnabled ?? true
    map.isTiltGesturesEnabled = pitchEnabled ?? true
  }
  
  // MARK: - User Location
  
  private func configureUserLocation() {
    guard let showLocation = showsUserLocation else { return }
    
    if showLocation {
      let mapKit = YMKMapKit.sharedInstance()
      userLocationLayer = mapKit.createUserLocationLayer(with: ymkMapView.mapWindow)
      userLocationLayer?.setVisibleWithOn(true)
      userLocationLayer?.isHeadingModeActive = true
    } else {
      userLocationLayer?.setVisibleWithOn(false)
    }
  }
  
  // MARK: - Map Type
  
  private func configureMapType() {
    guard let type = mapType else {
      return
    }
  
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      
      switch type {
      case .satellite:
        
        self.map.mapType = .satellite
      case .hybrid:
        
        self.map.mapType = .hybrid
      case .standard:
        
        self.map.mapType = .map
      }
      
      
    }
  }
  
  // MARK: - Clustering
  
  private func updateClusterConfig() {
    refreshClusters()
  }
  
  func refreshClusters() {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      
      // Clear existing cluster collection (don't remove, just clear and set to nil)
      self.clusterCollection?.clear()
      self.clusterCollection = nil
      self.clusteredPlacemarkIds.removeAll()
      
      // If clustering is disabled, use regular collection
      guard self.clusterConfig?.enabled ?? true else {
        self.recreateMarkersWithoutClustering()
        return
      }
      
      // Create cluster collection only if we have a delegate
      guard let delegate = self.mapDelegate else { return }
      self.clusterCollection = self.map.mapObjects.addClusterizedPlacemarkCollection(with: delegate)
      
      // Re-add all markers to cluster collection
      for (id, data) in self.markerData {
        if data.clusteringEnabled {
          self.addPlacemarkToCluster(id: id, data: data)
        } else {
          self.addPlacemarkToCollection(id: id, data: data)
        }
      }
      
      // Cluster placemarks
      let clusterRadius = 60.0
      let minZoom = UInt(self.clusterConfig?.maxZoom ?? 20)
      self.clusterCollection?.clusterPlacemarks(withClusterRadius: clusterRadius, minZoom: minZoom)
    }
  }
  
  private func recreateMarkersWithoutClustering() {
    // Clear all markers
    mapObjectCollection?.clear()
    placemarks.removeAll()
    
    // Re-add as regular placemarks
    for (id, data) in markerData {
      addPlacemarkToCollection(id: id, data: data)
    }
  }
  
  // MARK: - Camera Methods
  
  func animateToRegion(_ region: Region, duration: Double?) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      
      let target = YMKPoint(latitude: region.latitude, longitude: region.longitude)
      let zoom = self.zoomFromDeltas(latDelta: region.latitudeDelta, lonDelta: region.longitudeDelta)
      
      let cameraPosition = YMKCameraPosition(
        target: target,
        zoom: Float(zoom),
        azimuth: 0,
        tilt: 0
      )
      
      let durationSeconds = Float((duration ?? 300) / 1000.0)
      
      self.map.move(
        with: cameraPosition,
        animation: YMKAnimation(type: .smooth, duration: durationSeconds),
        cameraCallback: nil
      )
    }
  }
  
  func fitToCoordinates(_ coordinates: [Coordinate], edgePadding: EdgePadding?, animated: Bool?) {
    guard !coordinates.isEmpty else { return }
    
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      
      var points: [YMKPoint] = []
      for coord in coordinates {
        points.append(YMKPoint(latitude: coord.latitude, longitude: coord.longitude))
      }
      
      // Calculate bounding box
      var minLat = points[0].latitude
      var maxLat = points[0].latitude
      var minLon = points[0].longitude
      var maxLon = points[0].longitude
      
      for point in points {
        minLat = min(minLat, point.latitude)
        maxLat = max(maxLat, point.latitude)
        minLon = min(minLon, point.longitude)
        maxLon = max(maxLon, point.longitude)
      }
      
      let boundingBox = YMKBoundingBox(
        southWest: YMKPoint(latitude: minLat, longitude: minLon),
        northEast: YMKPoint(latitude: maxLat, longitude: maxLon)
      )
      
      // Convert bounding box to geometry
      let geometry = YMKGeometry(boundingBox: boundingBox)
      let cameraPosition = self.map.cameraPosition(with: geometry)
      
      if animated ?? true {
        self.map.move(
          with: cameraPosition,
          animation: YMKAnimation(type: .smooth, duration: 0.5),
          cameraCallback: nil
        )
      } else {
        self.map.move(with: cameraPosition)
      }
    }
  }
  
  func animateCamera(_ camera: Camera, duration: Double?) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      
      let cameraPosition = YMKCameraPosition(
        target: YMKPoint(latitude: camera.center.latitude, longitude: camera.center.longitude),
        zoom: Float(camera.zoom),
        azimuth: Float(camera.heading),
        tilt: Float(camera.pitch)
      )
      
      let durationSeconds = Float((duration ?? 300) / 1000.0)
      
      self.map.move(
        with: cameraPosition,
        animation: YMKAnimation(type: .smooth, duration: durationSeconds),
        cameraCallback: nil
      )
    }
  }
  
  func setCamera(_ camera: Camera) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      
      let cameraPosition = YMKCameraPosition(
        target: YMKPoint(latitude: camera.center.latitude, longitude: camera.center.longitude),
        zoom: Float(camera.zoom),
        azimuth: Float(camera.heading),
        tilt: Float(camera.pitch)
      )
      
      self.map.move(with: cameraPosition)
    }
  }
  
  func getCamera() -> Camera {
    // Default camera if map not ready
    var result = Camera(
      center: Coordinate(latitude: 0, longitude: 0),
      pitch: 0,
      heading: 0,
      altitude: 40000000,
      zoom: 0
    )
    
    // Safely access map camera on main thread
    if Thread.isMainThread {
      let cameraPosition = map.cameraPosition
      let zoom = Double(cameraPosition.zoom)
      result = Camera(
        center: Coordinate(
          latitude: cameraPosition.target.latitude,
          longitude: cameraPosition.target.longitude
        ),
        pitch: Double(cameraPosition.tilt),
        heading: Double(cameraPosition.azimuth),
        altitude: altitudeFromZoom(zoom),
        zoom: zoom
      )
    } else {
      DispatchQueue.main.sync { [self] in
        let cameraPosition = map.cameraPosition
        let zoom = Double(cameraPosition.zoom)
        result = Camera(
          center: Coordinate(
            latitude: cameraPosition.target.latitude,
            longitude: cameraPosition.target.longitude
          ),
          pitch: Double(cameraPosition.tilt),
          heading: Double(cameraPosition.azimuth),
          altitude: altitudeFromZoom(zoom),
          zoom: zoom
        )
      }
    }
    
    return result
  }
  
  func getMapBoundaries() -> MapBoundaries? {
    var result: MapBoundaries? = nil
    
    if Thread.isMainThread {
      let visibleRegion = map.visibleRegion
      result = MapBoundaries(
        northEast: Coordinate(
          latitude: visibleRegion.topRight.latitude,
          longitude: visibleRegion.topRight.longitude
        ),
        southWest: Coordinate(
          latitude: visibleRegion.bottomLeft.latitude,
          longitude: visibleRegion.bottomLeft.longitude
        )
      )
    } else {
      DispatchQueue.main.sync { [self] in
        let visibleRegion = map.visibleRegion
        result = MapBoundaries(
          northEast: Coordinate(
            latitude: visibleRegion.topRight.latitude,
            longitude: visibleRegion.topRight.longitude
          ),
          southWest: Coordinate(
            latitude: visibleRegion.bottomLeft.latitude,
            longitude: visibleRegion.bottomLeft.longitude
          )
        )
      }
    }
    
    return result
  }
  
  // MARK: - Marker Management
  
  func addMarker(_ marker: MarkerData) {
    DispatchQueue.main.async { [weak self] in
      self?.addMarkerSync(marker)
    }
  }
  
  func addMarkers(_ markers: [MarkerData]) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      for marker in markers {
        self.addMarkerSync(marker)
      }
    }
  }
  
  private func addMarkerSync(_ data: MarkerData) {
    print("🗺️ YandexMapProvider: addMarkerSync for: \(data.id), clusteringEnabled: \(data.clusteringEnabled)")
    
    removeMarkerSync(data.id)
    
    markerData[data.id] = data
    
    // For now, always add to regular collection to ensure visibility
    // Clustering in Yandex requires special handling
    if data.clusteringEnabled && (clusterConfig?.enabled ?? true) {
      // Ensure cluster collection exists
      if clusterCollection == nil, let delegate = mapDelegate {
        print("🗺️ YandexMapProvider: Creating clusterCollection on demand")
        clusterCollection = map.mapObjects.addClusterizedPlacemarkCollection(with: delegate)
      }
      
      if clusterCollection != nil {
        addPlacemarkToCluster(id: data.id, data: data)
      } else {
        print("🗺️ YandexMapProvider: clusterCollection is nil, falling back to regular collection")
        addPlacemarkToCollection(id: data.id, data: data)
      }
    } else {
      addPlacemarkToCollection(id: data.id, data: data)
    }
  }
  
  private func addPlacemarkToCollection(id: String, data: MarkerData) {
    print("🗺️ YandexMapProvider: addPlacemarkToCollection for: \(id)")
    
    // Ensure mapObjectCollection exists
    if mapObjectCollection == nil {
      print("🗺️ YandexMapProvider: Creating mapObjectCollection on demand")
      mapObjectCollection = map.mapObjects.add()
    }
    
    guard let collection = mapObjectCollection else {
      print("🗺️ YandexMapProvider: ERROR - mapObjectCollection still nil!")
      return
    }
    
    let point = YMKPoint(latitude: data.coordinate.latitude, longitude: data.coordinate.longitude)
    let placemark = collection.addPlacemark(with: point)
    
    configurePlacemark(placemark, with: data)
    placemarks[id] = placemark
    print("🗺️ YandexMapProvider: Marker added to regular collection")
  }
  
  private func addPlacemarkToCluster(id: String, data: MarkerData) {
    print("🗺️ YandexMapProvider: addPlacemarkToCluster for: \(id)")
    
    guard let cluster = clusterCollection else {
      print("🗺️ YandexMapProvider: clusterCollection is nil, cannot add to cluster")
      return
    }
    
    let point = YMKPoint(latitude: data.coordinate.latitude, longitude: data.coordinate.longitude)
    let placemark = cluster.addPlacemark(with: point)
    
    configurePlacemark(placemark, with: data)
    placemarks[id] = placemark
    clusteredPlacemarkIds.insert(id)  // Track that this marker is in cluster collection
    
    // Re-cluster after adding
    let clusterRadius = 60.0
    let minZoom = UInt(clusterConfig?.maxZoom ?? 20)
    cluster.clusterPlacemarks(withClusterRadius: clusterRadius, minZoom: minZoom)
    
    print("🗺️ YandexMapProvider: Marker added to cluster collection")
  }
  
  private func configurePlacemark(_ placemark: YMKPlacemarkMapObject, with data: MarkerData) {
    print("🗺️ YandexMapProvider: configurePlacemark for marker: \(data.id)")
    
    // Set icon with fallback
    if let icon = MarkerIconFactory.createIcon(for: data) {
      print("🗺️ YandexMapProvider: Using custom icon for marker")
      let iconStyle = YMKIconStyle()
      iconStyle.anchor = NSValue(cgPoint: CGPoint(x: 0.5, y: 1.0))  // Bottom center
      iconStyle.scale = NSNumber(value: 1.0)
      placemark.setIconWith(icon, style: iconStyle)
    } else {
      print("🗺️ YandexMapProvider: Creating default icon for marker")
      // Create a simple default marker icon
      let defaultIcon = createDefaultMarkerIcon()
      let iconStyle = YMKIconStyle()
      iconStyle.anchor = NSValue(cgPoint: CGPoint(x: 0.5, y: 1.0))
      iconStyle.scale = NSNumber(value: 1.0)
      placemark.setIconWith(defaultIcon, style: iconStyle)
    }
    
    // Set opacity
    placemark.opacity = Float(data.opacity)
    
    // Set rotation
    placemark.direction = Float(data.rotation)
    
    // Set z-index
    placemark.zIndex = Float(data.zIndex)
    
    // Enable dragging if needed
    placemark.isDraggable = data.draggable
    
    // Store marker ID in userData for tap handling
    placemark.userData = data.id
    
    // Add tap listener
    if let delegate = mapDelegate {
      placemark.addTapListener(with: delegate)
      
      // Add drag listener if draggable
      if data.draggable {
        placemark.setDragListenerWith(delegate)
      }
    }
    
    print("🗺️ YandexMapProvider: Marker configured, placemark visible: \(placemark.isVisible)")
  }
  
  private func createDefaultMarkerIcon() -> UIImage {
    let size: CGFloat = 32
    let rect = CGRect(x: 0, y: 0, width: size, height: size * 1.3)
    
    UIGraphicsBeginImageContextWithOptions(rect.size, false, UIScreen.main.scale)
    guard UIGraphicsGetCurrentContext() != nil else {
      return UIImage()
    }
    
    // Draw pin shape
    let pinPath = UIBezierPath()
    let centerX = size / 2
    let circleRadius = size / 2 - 2
    
    // Circle at top
    pinPath.addArc(
      withCenter: CGPoint(x: centerX, y: circleRadius + 2),
      radius: circleRadius,
      startAngle: CGFloat.pi,
      endAngle: 0,
      clockwise: true
    )
    
    // Point at bottom
    pinPath.addLine(to: CGPoint(x: centerX, y: rect.height))
    pinPath.addLine(to: CGPoint(x: 2, y: circleRadius + 2))
    pinPath.close()
    
    // Fill with red
    UIColor.red.setFill()
    pinPath.fill()
    
    // White border
    UIColor.white.setStroke()
    pinPath.lineWidth = 2
    pinPath.stroke()
    
    // White dot in center
    UIColor.white.setFill()
    let dotPath = UIBezierPath(
      arcCenter: CGPoint(x: centerX, y: circleRadius + 2),
      radius: circleRadius / 3,
      startAngle: 0,
      endAngle: CGFloat.pi * 2,
      clockwise: true
    )
    dotPath.fill()
    
    let image = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
    UIGraphicsEndImageContext()
    
    return image
  }
  
  func updateMarker(_ marker: MarkerData) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      
      // Update marker data
      self.markerData[marker.id] = marker
      
      // If placemark exists, update it in-place (no flicker!)
      if let placemark = self.placemarks[marker.id] {
        // Update position
        placemark.geometry = YMKPoint(
          latitude: marker.coordinate.latitude,
          longitude: marker.coordinate.longitude
        )
        
        // Update icon
        if let icon = MarkerIconFactory.createIcon(for: marker) {
          let iconStyle = YMKIconStyle()
          iconStyle.anchor = NSValue(cgPoint: CGPoint(x: marker.anchor.x, y: marker.anchor.y))
          iconStyle.scale = NSNumber(value: 1.0)
          placemark.setIconWith(icon, style: iconStyle)
        }
        
        // Update other properties
        placemark.opacity = Float(marker.opacity)
        placemark.direction = Float(marker.rotation)
        placemark.zIndex = Float(marker.zIndex)
        placemark.isDraggable = marker.draggable
      } else {
        // Placemark doesn't exist, add it
        self.addMarkerSync(marker)
      }
    }
  }
  
  func removeMarker(_ id: String) {
    DispatchQueue.main.async { [weak self] in
      self?.removeMarkerSync(id)
    }
  }
  
  private func removeMarkerSync(_ id: String) {
    markerData.removeValue(forKey: id)
    
    if let placemark = placemarks[id] {
      // Remove from the correct collection based on tracking
      if clusteredPlacemarkIds.contains(id) {
        clusterCollection?.remove(with: placemark)
        clusteredPlacemarkIds.remove(id)
      } else {
        mapObjectCollection?.remove(with: placemark)
      }
      placemarks.removeValue(forKey: id)
    }
  }
  
  func clearMarkers() {
    DispatchQueue.main.async { [weak self] in
      self?.clearMarkersSync()
    }
  }
  
  private func clearMarkersSync() {
    mapObjectCollection?.clear()
    clusterCollection?.clear()
    placemarks.removeAll()
    markerData.removeAll()
    clusteredPlacemarkIds.removeAll()
  }
  
  private var selectedMarkerId: String?
  
  func selectMarker(_ id: String) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      
      // Deselect previous marker if exists
      if let previousId = self.selectedMarkerId, previousId != id {
        self.updateMarkerSelectionState(previousId, selected: false)
      }
      
      // Select new marker
      self.selectedMarkerId = id
      self.updateMarkerSelectionState(id, selected: true)
      
      // Animate to marker position
      if let placemark = self.placemarks[id] {
        let position = placemark.geometry
        let currentCamera = self.map.cameraPosition
        
        let newCamera = YMKCameraPosition(
          target: position,
          zoom: currentCamera.zoom,
          azimuth: currentCamera.azimuth,
          tilt: currentCamera.tilt
        )
        
        self.map.move(
          with: newCamera,
          animation: YMKAnimation(type: .smooth, duration: 0.3),
          cameraCallback: nil
        )
      }
    }
  }
  
  /// Update a marker's visual selection state by regenerating its icon
  private func updateMarkerSelectionState(_ id: String, selected: Bool) {
    guard let data = markerData[id] else { return }
    
    // Use shared helper to create updated marker data with selection state
    guard let updatedData = MarkerSelectionHandler.shared.updateSelectionState(for: data, selected: selected) else {
      return
    }
    
    // Update stored data
    markerData[id] = updatedData
    
    // Update the placemark's icon
    if let placemark = placemarks[id] {
      if let icon = MarkerIconFactory.createIcon(for: updatedData) {
        let iconStyle = YMKIconStyle()
        iconStyle.anchor = NSValue(cgPoint: CGPoint(x: updatedData.anchor.x, y: updatedData.anchor.y))
        iconStyle.scale = NSNumber(value: 1.0)
        placemark.setIconWith(icon, style: iconStyle)
      }
    }
  }
  
  // MARK: - Clustering Control
  
  func setClusteringEnabled(_ enabled: Bool) {
    var config = clusterConfig ?? ClusterConfig(
      enabled: enabled,
      minimumClusterSize: 2,
      maxZoom: 20,
      backgroundColor: .second(MarkerColor(r: 255, g: 204, b: 0, a: 255)),  // Yandex yellow
      textColor: .second(MarkerColor(r: 0, g: 0, b: 0, a: 255)),
      borderWidth: 2,
      borderColor: .second(MarkerColor(r: 255, g: 255, b: 255, a: 255)),
      animatesClusters: true,
      animationDuration: 0.3,
      animationStyle: .default
    )
    config = ClusterConfig(
      enabled: enabled,
      minimumClusterSize: config.minimumClusterSize,
      maxZoom: config.maxZoom,
      backgroundColor: config.backgroundColor,
      textColor: config.textColor,
      borderWidth: config.borderWidth,
      borderColor: config.borderColor,
      animatesClusters: config.animatesClusters,
      animationDuration: config.animationDuration,
      animationStyle: config.animationStyle
    )
    clusterConfig = config
    refreshClusters()
  }
  
  func performClustering() {
    // Yandex uses built-in clustering via clusterCollection
    // This just triggers a refresh of the cluster state
    refreshClusters()
  }
  
  // MARK: - Map Style
  
  func setMapStyle(_ style: [MapStyleElement]?) {
    // Yandex uses a different style format (JSON/URI based)
    // Would need to convert from Google-style to Yandex style
    print("YandexMapProvider: Custom map styles require Yandex-specific format")
  }
  
  func setDarkMode(_ enabled: Bool) {
    DispatchQueue.main.async { [weak self] in
      self?.darkMode = enabled
    }
  }
  
  private func applyDarkMode() {
    guard let isDark = darkMode else { return }
    
    // Yandex Maps supports night mode
    if isDark {
      map.isNightModeEnabled = true
    } else {
      map.isNightModeEnabled = false
    }
  }
  
  // MARK: - Helper Methods
  
  private func updateCameraToInitialRegion() {
    guard let region = initialRegion else { return }
    
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      
      let target = YMKPoint(latitude: region.latitude, longitude: region.longitude)
      let zoom = self.zoomFromDeltas(latDelta: region.latitudeDelta, lonDelta: region.longitudeDelta)
      
      let cameraPosition = YMKCameraPosition(
        target: target,
        zoom: Float(zoom),
        azimuth: 0,
        tilt: 0
      )
      
      self.map.move(with: cameraPosition)
    }
  }
  
  private func zoomFromDeltas(latDelta: Double, lonDelta: Double) -> Double {
    // Approximate conversion from lat/lon deltas to zoom level
    let maxDelta = max(latDelta, lonDelta)
    return max(0, min(21, log2(360.0 / maxDelta)))
  }
  
  private func altitudeFromZoom(_ zoom: Double) -> Double {
    return 40000000 / pow(2, zoom)
  }
  
  func getCurrentRegion() -> Region {
    let center = map.cameraPosition.target
    let zoom = Double(map.cameraPosition.zoom)
    
    // Approximate deltas from zoom
    let delta = 360.0 / pow(2, zoom)
    
    return Region(
      latitude: center.latitude,
      longitude: center.longitude,
      latitudeDelta: delta,
      longitudeDelta: delta
    )
  }
}
