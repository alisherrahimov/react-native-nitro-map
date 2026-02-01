import Foundation
import GoogleMaps
import GoogleMapsUtils
import UIKit

/// Google Maps implementation of MapProviderProtocol
class GoogleMapProvider: MapProviderProtocol {

  // MARK: - Properties

  let gmsMapView: GMSMapView
  var mapView: UIView { return gmsMapView }

  private var mapDelegate: GoogleMapDelegate?

  // MARK: - Injected Dependencies (Production-Ready DI Pattern)
  
  private let clusteringManager: ClusteringManagerProtocol
  private let selectionHandler: MarkerSelectionHandling
  private let styleProvider: MapStyleProviding

  // Rendered markers
  private var renderedClusterMarkers: [GMSMarker] = []
  private var renderedSingleMarkers: [String: GMSMarker] = [:]
  private var nonClusteredMarkers: [String: GMSMarker] = [:]
  private var clusterableMarkerData: [String: MarkerData] = [:]

  private var selectedMarkerId: String?

  // Marker reuse pool to prevent texture allocation exhaustion
  private var markerReusePool: [GMSMarker] = []
  private let maxPoolSize = 100

  // MARK: - Protocol Properties
  

  var initialRegion: Region? = Region(latitude: 41.2995, longitude: 69.2401, latitudeDelta: 0.15, longitudeDelta: 0.15) {
    didSet {
      // Only move to initial region on first set, not on every re-render
      guard oldValue == nil else { return }
      updateCameraToInitialRegion()
    }
  }

  var showsUserLocation: Bool? {
    didSet { gmsMapView.isMyLocationEnabled = showsUserLocation ?? false }
  }

  var zoomEnabled: Bool? {
    didSet { gmsMapView.settings.zoomGestures = zoomEnabled ?? true }
  }

  var scrollEnabled: Bool? {
    didSet { gmsMapView.settings.scrollGestures = scrollEnabled ?? true }
  }

  var rotateEnabled: Bool? {
    didSet { gmsMapView.settings.rotateGestures = rotateEnabled ?? true }
  }

  var pitchEnabled: Bool? {
    didSet { gmsMapView.settings.tiltGestures = pitchEnabled ?? true }
  }

  var mapType: MapType? {
    didSet { gmsMapView.mapType = convertMapType(mapType) }
  }

  var showsMyLocationButton: Bool? {
    didSet {
      gmsMapView.settings.myLocationButton = showsMyLocationButton ?? false
    }
  }

  var clusterConfig: ClusterConfig? {
    didSet { updateClusterConfig() }
  }

  var customMapStyle: [MapStyleElement]? {
    didSet { applyMapStyle() }
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

  // MARK: - Initialization
  
  /// Creates a GoogleMapProvider with injected dependencies.
  /// Uses default production implementations if none provided.
  ///
  /// - Parameters:
  ///   - clusteringManager: Clustering logic handler (default: ClusteringManager)
  ///   - selectionHandler: Marker selection handler (default: MarkerSelectionHandler.shared)
  ///   - styleProvider: Style utilities (default: MapStyleProvider.shared)
  init(
    clusteringManager: ClusteringManagerProtocol = ClusteringManager(),
    selectionHandler: MarkerSelectionHandling = MarkerSelectionHandler.shared,
    styleProvider: MapStyleProviding = MapStyleProvider.shared
  ) {
    self.clusteringManager = clusteringManager
    self.selectionHandler = selectionHandler
    self.styleProvider = styleProvider
    
    let camera = GMSCameraPosition.camera(
      withLatitude: 41.2995,
      longitude: 69.2401,
      zoom: 10
    )

    // Use GMSMapViewOptions (required for Google Maps SDK v10.0+)
    let options = GMSMapViewOptions()
    options.camera = camera
    options.frame = .zero
    
    let mapView = GMSMapView(options: options)
    mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    self.gmsMapView = mapView

    setupIconLoadNotification()
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  // MARK: - Lifecycle

  func setup() {
    mapDelegate = GoogleMapDelegate(provider: self)
    gmsMapView.delegate = mapDelegate
  }

  /// Listen for async icon load completion to update markers
  private func setupIconLoadNotification() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleIconLoaded(_:)),
      name: Notification.Name("MarkerIconLoaded"),
      object: nil
    )
  }

  @objc private func handleIconLoaded(_ notification: Notification) {
    guard let userInfo = notification.userInfo,
          let icon = userInfo["icon"] as? UIImage else {
      return
    }

    // Update any markers that were waiting for this icon
    // The cache has already been updated, so just refresh visible markers
    DispatchQueue.main.async { [weak self] in
      self?.refreshVisibleMarkerIcons()
    }
  }

  /// Refresh icons for visible markers (used after async icon load)
  private func refreshVisibleMarkerIcons() {
    // Only refresh image-style markers as they use async loading
    for (id, gmsMarker) in renderedSingleMarkers {
      if let markerData = clusterableMarkerData[id],
         markerData.config.style == .image {
        // Re-fetch icon from cache (now should have the loaded image)
        if let icon = MarkerIconFactory.createIcon(for: markerData) {
          gmsMarker.icon = icon
        }
      }
    }

    for (id, gmsMarker) in nonClusteredMarkers {
      if let markerData = clusterableMarkerData[id],
         markerData.config.style == .image {
        if let icon = MarkerIconFactory.createIcon(for: markerData) {
          gmsMarker.icon = icon
        }
      }
    }
  }

  func updateSettings() {
    gmsMapView.isMyLocationEnabled = showsUserLocation ?? false
    gmsMapView.settings.zoomGestures = zoomEnabled ?? true
    gmsMapView.settings.scrollGestures = scrollEnabled ?? true
    gmsMapView.settings.rotateGestures = rotateEnabled ?? true
    gmsMapView.settings.tiltGestures = pitchEnabled ?? true
    gmsMapView.settings.myLocationButton = showsMyLocationButton ?? false
    gmsMapView.mapType = convertMapType(mapType)
    applyMapStyle()
    performClustering()
  }

  // MARK: - Cluster Configuration

  private func updateClusterConfig() {
    clusteringManager.clusterConfig = clusterConfig
    performClustering()
  }

  // MARK: - Clustering

  /// Debounce timer for clustering
  private var clusteringDebounceTimer: Timer?
  private let clusteringDebounceInterval: TimeInterval = 0.1 // 100ms debounce

  func performClustering() {
    // Cancel any pending clustering
    clusteringDebounceTimer?.invalidate()

    // Debounce to prevent rapid re-clustering during animations
    clusteringDebounceTimer = Timer.scheduledTimer(withTimeInterval: clusteringDebounceInterval, repeats: false) { [weak self] _ in
      self?.performClusteringImmediate()
    }
  }

  private func performClusteringImmediate() {
    guard gmsMapView.frame.size.width > 0 && gmsMapView.frame.size.height > 0
    else {
      return
    }

    let enabled = clusterConfig?.enabled ?? true
    guard enabled else {
      clearRenderedMarkersToPool()
      renderAllMarkersIndividually()
      return
    }

    let visibleRegion = gmsMapView.projection.visibleRegion()
    let zoom = gmsMapView.camera.zoom
    let mapSize = gmsMapView.frame.size

    let result = clusteringManager.clusterWithVisibleRegion(
      visibleRegion,
      zoom: zoom,
      mapSize: mapSize
    )

    // Use incremental update with marker reuse
    performIncrementalClusterUpdate(
      newClusters: result.clusters,
      newSingleMarkers: result.singleMarkers
    )
  }

  /// Track markers that are currently hidden (part of a cluster)
  private var hiddenClusteredMarkers: [String: GMSMarker] = [:]

  /// Incremental cluster update - reuses existing markers when possible
  /// This prevents texture allocation exhaustion by minimizing new GMSMarker creation
  private func performIncrementalClusterUpdate(
    newClusters: [NitroClusterEngine.ClusterDataResult],
    newSingleMarkers: [MarkerData]
  ) {
    // Track which marker IDs are now in clusters (within visible region)
    let newSingleMarkerIds = Set(newSingleMarkers.map { $0.id })
    var clusteredMarkerIds = Set<String>()
    for cluster in newClusters {
      for id in cluster.markerIds {
        clusteredMarkerIds.insert(id)
      }
    }

    // 1. Hide markers that are NOW part of a visible cluster
    // Instead of returning to pool, just hide them for fast re-show
    // BUT: never hide the currently selected marker
    for (id, marker) in renderedSingleMarkers {
      if clusteredMarkerIds.contains(id) && id != selectedMarkerId {
        // Hide marker but keep it ready for re-use
        marker.map = nil
        hiddenClusteredMarkers[id] = marker
      }
    }
    // Remove hidden markers from rendered dict (except selected marker)
    for id in clusteredMarkerIds {
      if id != selectedMarkerId {
        renderedSingleMarkers.removeValue(forKey: id)
      }
    }

    // 2. Show markers that should be single (visible and not clustered)
    for markerData in newSingleMarkers {
      if let existingMarker = renderedSingleMarkers[markerData.id] {
        // Already visible - nothing to do
        continue
      }

      if let hiddenMarker = hiddenClusteredMarkers.removeValue(forKey: markerData.id) {
        // Re-show previously hidden marker (no texture allocation!)
        hiddenMarker.map = gmsMapView
        renderedSingleMarkers[markerData.id] = hiddenMarker
      } else {
        // Create new marker from pool
        let marker = getMarkerFromPool()
        configureGMSMarker(marker, from: markerData)
        marker.map = gmsMapView
        renderedSingleMarkers[markerData.id] = marker
      }
    }

    // 3. Clean up hidden markers that are no longer needed
    // (markers that were removed from the map entirely)
    var hiddenToRemove: [String] = []
    for (id, _) in hiddenClusteredMarkers {
      if clusterableMarkerData[id] == nil {
        hiddenToRemove.append(id)
      }
    }
    for id in hiddenToRemove {
      if let marker = hiddenClusteredMarkers.removeValue(forKey: id) {
        returnMarkerToPool(marker)
      }
    }

    // 4. Update clusters - simple recreation (cluster icons are cached)
    updateClusterMarkers(newClusters)
  }

  private func updateClusterMarkers(_ newClusters: [NitroClusterEngine.ClusterDataResult]) {
    // Return old cluster markers to pool
    for marker in renderedClusterMarkers {
      returnMarkerToPool(marker)
    }
    renderedClusterMarkers.removeAll()

    let minClusterSize = clusterConfig?.minimumClusterSize ?? 2

    // Create new cluster markers
    // Note: Cluster icons are cached by NitroClusterIconGenerator, so this is cheap
    for cluster in newClusters {
      // If the selected marker is in this cluster, adjust the count
      let containsSelectedMarker = selectedMarkerId != nil && cluster.markerIds.contains(selectedMarkerId!)
      let adjustedCount = containsSelectedMarker ? cluster.count - 1 : cluster.count
      
      // Skip this cluster if after excluding the selected marker it's below minimum size
      if adjustedCount < Int(minClusterSize) {
        continue
      }
      
      let marker = getMarkerFromPool()
      marker.position = cluster.coordinate
      marker.groundAnchor = CGPoint(x: 0.5, y: 0.5)

      if let icon = clusteringManager.clusterIcon(forCount: adjustedCount) {
        marker.icon = icon
      }

      // Store the adjusted marker IDs (excluding selected marker)
      let adjustedMarkerIds = containsSelectedMarker 
        ? cluster.markerIds.filter { $0 != selectedMarkerId }
        : cluster.markerIds
      
      marker.userData = ClusterUserData(
        markerIds: adjustedMarkerIds,
        count: adjustedCount
      )

      if let animationStyle = clusterConfig?.animationStyle {
        applyClusterAnimation(marker, style: animationStyle)
      }

      marker.map = gmsMapView
      renderedClusterMarkers.append(marker)
    }
  }

  /// Get a marker from the reuse pool or create a new one
  private func getMarkerFromPool() -> GMSMarker {
    if let marker = markerReusePool.popLast() {
      // Reset marker state before reuse
      marker.map = nil
      marker.icon = nil
      marker.userData = nil
      return marker
    }
    return GMSMarker()
  }

  /// Return a marker to the reuse pool
  private func returnMarkerToPool(_ marker: GMSMarker) {
    marker.map = nil
    // Only pool markers up to the limit to prevent memory bloat
    if markerReusePool.count < maxPoolSize {
      marker.icon = nil  // Release icon reference to free texture
      marker.userData = nil
      markerReusePool.append(marker)
    }
  }

  private func clearRenderedMarkersToPool() {
    for marker in renderedClusterMarkers {
      returnMarkerToPool(marker)
    }
    renderedClusterMarkers.removeAll()

    for (_, marker) in renderedSingleMarkers {
      returnMarkerToPool(marker)
    }
    renderedSingleMarkers.removeAll()

    for (_, marker) in hiddenClusteredMarkers {
      returnMarkerToPool(marker)
    }
    hiddenClusteredMarkers.removeAll()
  }

  private func renderAllMarkersIndividually() {
    for (_, markerData) in clusterableMarkerData {
      // Only create markers that don't already exist
      if renderedSingleMarkers[markerData.id] == nil {
        let marker = getMarkerFromPool()
        configureGMSMarker(marker, from: markerData)
        marker.map = gmsMapView
        renderedSingleMarkers[markerData.id] = marker
      }
    }
  }

  /// Configure a GMSMarker with marker data (for initial setup)
  private func configureGMSMarker(_ gmsMarker: GMSMarker, from markerData: MarkerData) {
    gmsMarker.position = CLLocationCoordinate2D(
      latitude: markerData.coordinate.latitude,
      longitude: markerData.coordinate.longitude
    )
    gmsMarker.title = markerData.title
    gmsMarker.snippet = markerData.description
    gmsMarker.isDraggable = markerData.draggable
    gmsMarker.opacity = Float(markerData.opacity)
    gmsMarker.rotation = markerData.rotation
    gmsMarker.zIndex = Int32(markerData.zIndex)
    gmsMarker.groundAnchor = CGPoint(
      x: markerData.anchor.x,
      y: markerData.anchor.y
    )
    gmsMarker.userData = markerData.id
    gmsMarker.icon = MarkerIconFactory.createIcon(for: markerData)

    switch markerData.animation {
    case .pop:
      gmsMarker.appearAnimation = .pop
    case .fadein:
      gmsMarker.appearAnimation = .fadeIn
    case .none:
      gmsMarker.appearAnimation = .none
    }
  }

  private func applyClusterAnimation(
    _ marker: GMSMarker,
    style: ClusterAnimationStyle
  ) {
    switch style {
    case .bounce, .spring:
      marker.appearAnimation = .pop
    case .fade:
      marker.appearAnimation = .fadeIn
    case .scale, .default:
      marker.appearAnimation = .pop
    }
  }

  // MARK: - Camera Methods

  func animateToRegion(_ region: Region, duration: Double?) {
    let camera = GMSCameraPosition.camera(
      withLatitude: region.latitude,
      longitude: region.longitude,
      zoom: calculateZoom(for: region)
    )

    let durationSeconds = (duration ?? 300) / 1000.0

    CATransaction.begin()
    CATransaction.setAnimationDuration(durationSeconds)
    gmsMapView.animate(to: camera)
    CATransaction.commit()
  }

  func fitToCoordinates(
    _ coordinates: [Coordinate],
    edgePadding: EdgePadding?,
    animated: Bool?
  ) {
    guard coordinates.count >= 2 else {
      if let first = coordinates.first {
        animateToRegion(
          Region(
            latitude: first.latitude,
            longitude: first.longitude,
            latitudeDelta: 0.05,
            longitudeDelta: 0.05
          ),
          duration: animated ?? true ? 300 : 0
        )
      }
      return
    }

    let clCoordinates = coordinates.map {
      CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
    }

    var bounds = GMSCoordinateBounds(
      coordinate: clCoordinates[0],
      coordinate: clCoordinates[1]
    )

    for coord in clCoordinates.dropFirst(2) {
      bounds = bounds.includingCoordinate(coord)
    }

    guard bounds.isValid else { return }

    let padding = UIEdgeInsets(
      top: CGFloat(edgePadding?.top ?? 50),
      left: CGFloat(edgePadding?.left ?? 50),
      bottom: CGFloat(edgePadding?.bottom ?? 50),
      right: CGFloat(edgePadding?.right ?? 50)
    )

    let cameraUpdate = GMSCameraUpdate.fit(bounds, with: padding)

    if animated ?? true {
      gmsMapView.animate(with: cameraUpdate)
    } else {
      gmsMapView.moveCamera(cameraUpdate)
    }
  }

  func animateCamera(_ camera: Camera, duration: Double?) {
    let gmsCamera = GMSCameraPosition.camera(
      withLatitude: camera.center.latitude,
      longitude: camera.center.longitude,
      zoom: Float(camera.zoom),
      bearing: camera.heading,
      viewingAngle: camera.pitch
    )

    let durationSeconds = (duration ?? 300) / 1000.0

    CATransaction.begin()
    CATransaction.setAnimationDuration(durationSeconds)
    gmsMapView.animate(to: gmsCamera)
    CATransaction.commit()
  }

  func setCamera(_ camera: Camera) {
    let gmsCamera = GMSCameraPosition.camera(
      withLatitude: camera.center.latitude,
      longitude: camera.center.longitude,
      zoom: Float(camera.zoom),
      bearing: camera.heading,
      viewingAngle: camera.pitch
    )
    gmsMapView.camera = gmsCamera
  }

  func getCamera() -> Camera {
    let cam = gmsMapView.camera
    return Camera(
      center: Coordinate(
        latitude: cam.target.latitude,
        longitude: cam.target.longitude
      ),
      pitch: cam.viewingAngle,
      heading: cam.bearing,
      altitude: Double(cam.zoom) * 1000,
      zoom: Double(cam.zoom)
    )
  }

  func getMapBoundaries() -> MapBoundaries? {
    guard gmsMapView.frame.size.width > 0,
      gmsMapView.frame.size.height > 0
    else {
      return nil
    }

    let visibleRegion = gmsMapView.projection.visibleRegion()
    let bounds = GMSCoordinateBounds(region: visibleRegion)

    guard bounds.isValid else { return nil }

    return MapBoundaries(
      northEast: Coordinate(
        latitude: bounds.northEast.latitude,
        longitude: bounds.northEast.longitude
      ),
      southWest: Coordinate(
        latitude: bounds.southWest.latitude,
        longitude: bounds.southWest.longitude
      )
    )
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
      self.performClustering()
    }
  }

  private func addMarkerSync(_ markerData: MarkerData) {
    removeMarkerSync(markerData.id)

    if markerData.clusteringEnabled && (clusterConfig?.enabled ?? true) {
      clusterableMarkerData[markerData.id] = markerData
      clusteringManager.addMarker(markerData)
    } else {
      // Use pooled marker for non-clustered markers too
      let marker = getMarkerFromPool()
      configureGMSMarker(marker, from: markerData)
      marker.map = gmsMapView
      nonClusteredMarkers[markerData.id] = marker
    }
  }

  func updateMarker(_ marker: MarkerData) {
    DispatchQueue.main.async { [weak self] in
      self?.updateMarkerInPlace(marker)
    }
  }

  /// Update marker in-place without triggering full re-clustering
  /// This prevents texture allocation exhaustion by reusing existing GMSMarker objects
  private func updateMarkerInPlace(_ markerData: MarkerData) {
    let id = markerData.id

    // Update stored data
    if clusterableMarkerData[id] != nil {
      clusterableMarkerData[id] = markerData
      clusteringManager.removeMarker(id)
      clusteringManager.addMarker(markerData)
    }

    // Update rendered marker in-place (no remove/re-add)
    if let gmsMarker = renderedSingleMarkers[id] {
      updateGMSMarkerProperties(gmsMarker, from: markerData)
    } else if let gmsMarker = hiddenClusteredMarkers[id] {
      // Update hidden marker too so it's ready when re-shown
      updateGMSMarkerProperties(gmsMarker, from: markerData)
    } else if let gmsMarker = nonClusteredMarkers[id] {
      updateGMSMarkerProperties(gmsMarker, from: markerData)
    }
    // If marker not in any dict, it will be created with new data when clustering runs
  }

  /// Update GMSMarker properties in-place without creating a new marker object
  private func updateGMSMarkerProperties(_ gmsMarker: GMSMarker, from markerData: MarkerData) {
    gmsMarker.position = CLLocationCoordinate2D(
      latitude: markerData.coordinate.latitude,
      longitude: markerData.coordinate.longitude
    )
    gmsMarker.title = markerData.title
    gmsMarker.snippet = markerData.description
    gmsMarker.isDraggable = markerData.draggable
    gmsMarker.opacity = Float(markerData.opacity)
    gmsMarker.rotation = markerData.rotation
    gmsMarker.zIndex = Int32(markerData.zIndex)
    gmsMarker.groundAnchor = CGPoint(
      x: markerData.anchor.x,
      y: markerData.anchor.y
    )

    // Only regenerate icon if needed - cache will handle deduplication
    if let newIcon = MarkerIconFactory.createIcon(for: markerData) {
      gmsMarker.icon = newIcon
    }
  }

  func removeMarker(_ id: String) {
    DispatchQueue.main.async { [weak self] in
      self?.removeMarkerSync(id)
      self?.performClustering()
    }
  }

  private func removeMarkerSync(_ id: String) {
    clusteringManager.removeMarker(id)
    clusterableMarkerData.removeValue(forKey: id)

    if let marker = renderedSingleMarkers[id] {
      marker.map = nil
      renderedSingleMarkers.removeValue(forKey: id)
    }

    if let marker = nonClusteredMarkers[id] {
      marker.map = nil
      nonClusteredMarkers.removeValue(forKey: id)
    }
  }

  func clearMarkers() {
    DispatchQueue.main.async { [weak self] in
      self?.clearMarkersSync()
    }
  }

  private func clearMarkersSync() {
    clusteringManager.clearMarkers()
    clusterableMarkerData.removeAll()
    clearRenderedMarkersToPool()

    for (_, marker) in nonClusteredMarkers {
      returnMarkerToPool(marker)
    }
    nonClusteredMarkers.removeAll()
  }

  func selectMarker(_ id: String) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }

      // Deselect previous marker if exists
      if let previousId = self.selectedMarkerId, previousId != id {
        self.updateMarkerSelectionState(previousId, selected: false)
        
        // If the previous marker was pulled out of a cluster, hide it back
        if let marker = self.renderedSingleMarkers[previousId],
           self.clusterableMarkerData[previousId] != nil {
          // Check if this marker should be back in a cluster
          // For now, just trigger a re-cluster to put it back
        }
      }

      // Select new marker
      self.selectedMarkerId = id
      self.updateMarkerSelectionState(id, selected: true)

      // Get marker position and animate to it
      var markerPosition: CLLocationCoordinate2D?
      
      if let marker = self.renderedSingleMarkers[id] {
        self.gmsMapView.selectedMarker = marker
        markerPosition = marker.position
      } else if let marker = self.nonClusteredMarkers[id] {
        self.gmsMapView.selectedMarker = marker
        markerPosition = marker.position
      } else if let hiddenMarker = self.hiddenClusteredMarkers[id] {
        // Marker is part of a cluster - pull it out and show it
        self.hiddenClusteredMarkers.removeValue(forKey: id)
        
        // Update the marker icon to show selected state
        if let markerData = self.clusterableMarkerData[id] {
          hiddenMarker.icon = MarkerIconFactory.createIcon(for: markerData)
        }
        
        // Show the marker on the map
        hiddenMarker.map = self.gmsMapView
        self.renderedSingleMarkers[id] = hiddenMarker
        self.gmsMapView.selectedMarker = hiddenMarker
        markerPosition = hiddenMarker.position
        
        // Re-cluster to update cluster counts (the selected marker is now excluded)
        self.performClustering()
      }
      
      // Animate camera to marker position
      if let position = markerPosition {
        let camera = GMSCameraPosition.camera(
          withLatitude: position.latitude,
          longitude: position.longitude,
          zoom: self.gmsMapView.camera.zoom  // Keep current zoom
        )
        
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.3)
        self.gmsMapView.animate(to: camera)
        CATransaction.commit()
      }
    }
  }

  /// Update a marker's visual selection state by regenerating its icon
  private func updateMarkerSelectionState(_ id: String, selected: Bool) {
    guard let data = clusterableMarkerData[id] else { return }
    
    // Use injected handler to create updated marker data with selection state
    guard let updatedData = selectionHandler.updateSelectionState(for: data, selected: selected) else {
      return
    }
    
    // Update stored data
    clusterableMarkerData[id] = updatedData
    clusteringManager.removeMarker(id)
    clusteringManager.addMarker(updatedData)
    
    // Regenerate icon and apply to GMSMarker
    if let gmsMarker = renderedSingleMarkers[id] {
      gmsMarker.icon = MarkerIconFactory.createIcon(for: updatedData)
    } else if let gmsMarker = nonClusteredMarkers[id] {
      gmsMarker.icon = MarkerIconFactory.createIcon(for: updatedData)
    }
  }

  // MARK: - Clustering Control

  func setClusteringEnabled(_ enabled: Bool) {
    let existingConfig = self.clusterConfig
    let config = ClusterConfig(
      enabled: enabled,
      minimumClusterSize: existingConfig?.minimumClusterSize ?? 2,
      maxZoom: existingConfig?.maxZoom ?? 20,
      backgroundColor: existingConfig?.backgroundColor
        ?? MarkerColor(r: 0, g: 122, b: 255, a: 255),
      textColor: existingConfig?.textColor
        ?? MarkerColor(r: 255, g: 255, b: 255, a: 255),
      borderWidth: existingConfig?.borderWidth ?? 2,
      borderColor: existingConfig?.borderColor
        ?? MarkerColor(r: 255, g: 255, b: 255, a: 255),
      animatesClusters: existingConfig?.animatesClusters ?? true,
      animationDuration: existingConfig?.animationDuration ?? 0.3,
      animationStyle: existingConfig?.animationStyle ?? .default
    )
    self.clusterConfig = config
    performClustering()
  }

  func refreshClusters() {
    DispatchQueue.main.async { [weak self] in
      self?.performClustering()
    }
  }

  // MARK: - Map Style

  func setMapStyle(_ style: [MapStyleElement]?) {
    DispatchQueue.main.async { [weak self] in
      self?.customMapStyle = style
    }
  }

  func setDarkMode(_ enabled: Bool) {
    DispatchQueue.main.async { [weak self] in
      self?.darkMode = enabled
    }
  }

  private func applyMapStyle() {
    guard let styleElements = customMapStyle, !styleElements.isEmpty else {
      gmsMapView.mapStyle = nil
      return
    }

    do {
      let jsonArray = styleElements.map { element -> [String: Any] in
        var dict: [String: Any] = [:]
        if let featureType = element.featureType {
          dict["featureType"] = featureType
        }
        if let elementType = element.elementType {
          dict["elementType"] = elementType
        }

        dict["stylers"] = element.stylers.map { styler -> [String: Any] in
          var s: [String: Any] = [:]
          if let color = styler.color { s["color"] = color }
          if let visibility = styler.visibility { s["visibility"] = visibility }
          if let weight = styler.weight { s["weight"] = weight }
          if let saturation = styler.saturation { s["saturation"] = saturation }
          if let lightness = styler.lightness { s["lightness"] = lightness }
          if let gamma = styler.gamma { s["gamma"] = gamma }
          return s
        }
        return dict
      }

      let jsonData = try JSONSerialization.data(withJSONObject: jsonArray)
      let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"
      gmsMapView.mapStyle = try GMSMapStyle(jsonString: jsonString)
    } catch {
      print("GoogleMapProvider: Failed to apply map style: \(error)")
    }
  }

  private func applyDarkMode() {
    if let isDark = darkMode {
      gmsMapView.overrideUserInterfaceStyle = isDark ? .dark : .light
    }
  }

  // MARK: - Helper Methods

  private func updateCameraToInitialRegion() {
    guard let region = initialRegion else { return }

    let camera = GMSCameraPosition.camera(
      withLatitude: region.latitude,
      longitude: region.longitude,
      zoom: calculateZoom(for: region)
    )
    gmsMapView.animate(to: camera)
  }

  private func calculateZoom(for region: Region) -> Float {
    let delta = max(region.latitudeDelta, region.longitudeDelta)

    switch delta {
    case ..<0.01: return 16
    case ..<0.05: return 14
    case ..<0.1: return 12
    case ..<0.5: return 10
    case ..<1.0: return 8
    case ..<5.0: return 6
    default: return 4
    }
  }

  private func convertMapType(_ type: MapType?) -> GMSMapViewType {
    switch type {
    case .satellite: return .satellite
    case .hybrid: return .hybrid
    case .standard, .none: return .normal
    }
  }

  // MARK: - Public Accessors for Delegate

  func getCurrentRegion() -> Region {
    let cam = gmsMapView.camera
    let visibleRegion = gmsMapView.projection.visibleRegion()
    let bounds = GMSCoordinateBounds(region: visibleRegion)

    return Region(
      latitude: cam.target.latitude,
      longitude: cam.target.longitude,
      latitudeDelta: bounds.northEast.latitude - bounds.southWest.latitude,
      longitudeDelta: bounds.northEast.longitude - bounds.southWest.longitude
    )
  }
}
