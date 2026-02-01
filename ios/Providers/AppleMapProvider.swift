import Foundation
import MapKit
import UIKit

/// Apple Maps implementation of MapProviderProtocol using MapKit
@available(iOS 17.0, *)
class AppleMapProvider: NSObject, MapProviderProtocol {

  // MARK: - Properties

  let mkMapView: MKMapView
  var mapView: UIView { return mkMapView }

  private var mapDelegate: AppleMapDelegate?

  // MARK: - Injected Dependencies (Production-Ready DI Pattern)
  
  private let clusteringManager: ClusteringManagerProtocol
  private let selectionHandler: MarkerSelectionHandling
  private let styleProvider: MapStyleProviding

  // Marker storage
  private var markers: [String: MKAnnotation] = [:]  // All annotation references
  private var markerData: [String: MarkerData] = [:]  // MarkerData cache
  private var clusterableMarkerData: [String: MarkerData] = [:]  // Clusterable marker data

  // Rendered markers (from clustering engine)
  private var renderedClusterAnnotations: [MKAnnotation] = []
  private var renderedSingleAnnotations: [String: MKAnnotation] = [:]
  private var nonClusteredAnnotations: [String: MKAnnotation] = [:]

  // MARK: - Protocol Properties

  // tashkent region
  //  latitude: 41.2995,
  //     longitude: 69.2401,
  //     latitudeDelta: 0.15,
  //     longitudeDelta: 0.15,

  var initialRegion: Region? = Region(
    latitude: 41.2995,
    longitude: 69.2401,
    latitudeDelta: 0.15,
    longitudeDelta: 0.15
  )
  {
    didSet { updateCameraToInitialRegion() }
  }

  var showsUserLocation: Bool? {
    didSet { mkMapView.showsUserLocation = showsUserLocation ?? false }
  }

  var zoomEnabled: Bool? {
    didSet { mkMapView.isZoomEnabled = zoomEnabled ?? true }
  }

  var scrollEnabled: Bool? {
    didSet { mkMapView.isScrollEnabled = scrollEnabled ?? true }
  }

  var rotateEnabled: Bool? {
    didSet { mkMapView.isRotateEnabled = rotateEnabled ?? true }
  }

  var pitchEnabled: Bool? {
    didSet { mkMapView.isPitchEnabled = pitchEnabled ?? true }
  }

  var mapType: MapType? {
    didSet { mkMapView.mapType = convertMapType(mapType) }
  }

  var showsMyLocationButton: Bool? {
    didSet {
      if #available(iOS 17.0, *) {
        mkMapView.showsUserTrackingButton = showsMyLocationButton ?? false
      }
    }
  }

  var clusterConfig: ClusterConfig? {
    didSet { updateClusterConfig() }
  }

  var customMapStyle: [MapStyleElement]? {
    didSet {
      // MapKit doesn't support custom JSON styles like Google Maps
      // Style customization is limited in MapKit
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

  // MARK: - Initialization
  
  /// Creates an AppleMapProvider with injected dependencies.
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
    
    let mapView = MKMapView(frame: .zero)
    mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    self.mkMapView = mapView

    super.init()
  }

  // MARK: - Lifecycle

  func setup() {
    mapDelegate = AppleMapDelegate(provider: self)
    mkMapView.delegate = mapDelegate

    mapDelegate = AppleMapDelegate(provider: self)
    mkMapView.delegate = mapDelegate

    // Register custom annotation view
    mkMapView.register(
      NitroAnnotationView.self,
      forAnnotationViewWithReuseIdentifier: NitroAnnotationView.reuseIdentifier
    )

    // Register C++ cluster annotation view (not MapKit's default)
    mkMapView.register(
      ClusterAnnotationView.self,
      forAnnotationViewWithReuseIdentifier: ClusterAnnotationView
        .reuseIdentifier
    )

    // Add gesture recognizers
    let tapGesture = UITapGestureRecognizer(
      target: self,
      action: #selector(handleMapTap(_:))
    )
    tapGesture.delegate = self
    mkMapView.addGestureRecognizer(tapGesture)

    let longPressGesture = UILongPressGestureRecognizer(
      target: self,
      action: #selector(handleMapLongPress(_:))
    )
    mkMapView.addGestureRecognizer(longPressGesture)

    // Notify map ready
    DispatchQueue.main.async { [weak self] in
      self?.onMapReady?()
    }
  }

  func updateSettings() {
    mkMapView.showsUserLocation = showsUserLocation ?? false
    mkMapView.isZoomEnabled = zoomEnabled ?? true
    mkMapView.isScrollEnabled = scrollEnabled ?? true
    mkMapView.isRotateEnabled = rotateEnabled ?? true
    mkMapView.isPitchEnabled = pitchEnabled ?? true
    if #available(iOS 17.0, *) {
      mkMapView.showsUserTrackingButton = showsMyLocationButton ?? false
    }
    mkMapView.mapType = convertMapType(mapType)
  }

  // MARK: - Gesture Handlers

  @objc private func handleMapTap(_ gesture: UITapGestureRecognizer) {
    guard gesture.state == .ended else { return }

    let point = gesture.location(in: mkMapView)
    let coordinate = mkMapView.convert(point, toCoordinateFrom: mkMapView)

    let event = MapPressEvent(
      coordinate: Coordinate(
        latitude: coordinate.latitude,
        longitude: coordinate.longitude
      ),
      position: Point(x: Double(point.x), y: Double(point.y))
    )
    onPress?(event)
  }

  @objc private func handleMapLongPress(_ gesture: UILongPressGestureRecognizer)
  {
    guard gesture.state == .began else { return }

    let point = gesture.location(in: mkMapView)
    let coordinate = mkMapView.convert(point, toCoordinateFrom: mkMapView)

    let event = MapPressEvent(
      coordinate: Coordinate(
        latitude: coordinate.latitude,
        longitude: coordinate.longitude
      ),
      position: Point(x: Double(point.x), y: Double(point.y))
    )
    onLongPress?(event)
  }

  // MARK: - Cluster Configuration

  private func updateClusterConfig() {
    clusteringManager.clusterConfig = clusterConfig
    performClustering()
  }

  // MARK: - C++ Clustering

  func performClustering() {
    // Skip clustering if we're animating to a selected marker
    guard !isAnimatingToMarker else { return }

    guard mkMapView.frame.size.width > 0 && mkMapView.frame.size.height > 0
    else {
      return
    }

    let enabled = clusterConfig?.enabled ?? true
    guard enabled else {
      clearRenderedMarkers()
      renderAllMarkersIndividually()
      return
    }

    // Get visible region bounds for C++ engine
    let region = mkMapView.region
    let minLat = region.center.latitude - region.span.latitudeDelta / 2
    let maxLat = region.center.latitude + region.span.latitudeDelta / 2
    let minLon = region.center.longitude - region.span.longitudeDelta / 2
    let maxLon = region.center.longitude + region.span.longitudeDelta / 2

    // Calculate zoom level from span
    let zoom = calculateZoomLevel(for: region)
    let mapSize = mkMapView.frame.size

    // Call clustering manager
    let result = clusteringManager.cluster(
      minLat: minLat,
      maxLat: maxLat,
      minLon: minLon,
      maxLon: maxLon,
      zoom: zoom,
      mapSize: mapSize
    )

    // Use diff-based update to prevent visual re-rendering
    updateMarkersWithDiff(
      clusters: result.clusters,
      singleMarkers: result.singleMarkers
    )
  }

  /// Diff-based update: only add/remove what actually changed
  private func updateMarkersWithDiff(
    clusters: [NitroClusterEngine.ClusterDataResult],
    singleMarkers: [MarkerData]
  ) {
    // Build set of new single marker IDs
    let newSingleMarkerIds = Set(singleMarkers.map { $0.id })

    // Remove single markers that are no longer in result
    let singleToRemove = renderedSingleAnnotations.keys.filter {
      !newSingleMarkerIds.contains($0)
    }
    for id in singleToRemove {
      if let annotation = renderedSingleAnnotations[id] {
        mkMapView.removeAnnotation(annotation)
        renderedSingleAnnotations.removeValue(forKey: id)
      }
    }

    // Add new single markers that aren't already rendered
    for markerData in singleMarkers {
      if renderedSingleAnnotations[markerData.id] == nil {
        renderSingleMarker(markerData)
      }
    }

    // For clusters, we need to clear and re-render since cluster composition changes
    // But this is much smaller than clearing ALL markers
    for annotation in renderedClusterAnnotations {
      mkMapView.removeAnnotation(annotation)
    }
    renderedClusterAnnotations.removeAll()

    for clusterData in clusters {
      renderCluster(clusterData)
    }
  }

  private func calculateZoomLevel(for region: MKCoordinateRegion) -> Double {
    // Convert MapKit span to approximate zoom level
    // Smaller span = higher zoom
    let delta = max(region.span.latitudeDelta, region.span.longitudeDelta)

    // Use logarithmic scale similar to Google Maps
    // zoom = log2(360 / delta)
    if delta <= 0 {
      return 21  // Max zoom
    }

    let zoom = log2(360.0 / delta)
    return min(21, max(1, zoom))  // Clamp between 1 and 21
  }

  private func clearRenderedMarkers() {
    for annotation in renderedClusterAnnotations {
      mkMapView.removeAnnotation(annotation)
    }
    renderedClusterAnnotations.removeAll()

    for (_, annotation) in renderedSingleAnnotations {
      mkMapView.removeAnnotation(annotation)
    }
    renderedSingleAnnotations.removeAll()
  }

  private func renderAllMarkersIndividually() {
    for (_, markerData) in clusterableMarkerData {
      let annotation = createAnnotation(from: markerData)
      mkMapView.addAnnotation(annotation)
      renderedSingleAnnotations[markerData.id] = annotation
    }
  }

  private func renderCluster(
    _ clusterData: NitroClusterEngine.ClusterDataResult
  ) {
    let annotation = ClusterAnnotation(
      coordinate: clusterData.coordinate,
      markerIds: clusterData.markerIds,
      count: clusterData.count
    )
    mkMapView.addAnnotation(annotation)
    renderedClusterAnnotations.append(annotation)
  }

  private func renderSingleMarker(_ markerData: MarkerData) {
    let annotation = createAnnotation(from: markerData)
    mkMapView.addAnnotation(annotation)
    renderedSingleAnnotations[markerData.id] = annotation
    markers[markerData.id] = annotation
  }

  func refreshClusters() {
    DispatchQueue.main.async { [weak self] in
      self?.performClustering()
    }
  }

  // MARK: - Camera Methods

  func animateToRegion(_ region: Region, duration: Double?) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }

      // Validate and clamp span values
      let latDelta = max(0.001, min(180.0, region.latitudeDelta))
      let lonDelta = max(0.001, min(360.0, region.longitudeDelta))

      let mkRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(
          latitude: region.latitude,
          longitude: region.longitude
        ),
        span: MKCoordinateSpan(
          latitudeDelta: latDelta,
          longitudeDelta: lonDelta
        )
      )

      // Use MKMapView's built-in animation
      let shouldAnimate = (duration ?? 300) > 0
      self.mkMapView.setRegion(mkRegion, animated: shouldAnimate)
    }
  }

  func fitToCoordinates(
    _ coordinates: [Coordinate],
    edgePadding: EdgePadding?,
    animated: Bool?
  ) {
    guard !coordinates.isEmpty else { return }

    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }

      var mkCoordinates = coordinates.map {
        CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
      }

      let polygon = MKPolygon(
        coordinates: &mkCoordinates,
        count: mkCoordinates.count
      )

      let padding = UIEdgeInsets(
        top: CGFloat(edgePadding?.top ?? 50),
        left: CGFloat(edgePadding?.left ?? 50),
        bottom: CGFloat(edgePadding?.bottom ?? 50),
        right: CGFloat(edgePadding?.right ?? 50)
      )

      self.mkMapView.setVisibleMapRect(
        polygon.boundingMapRect,
        edgePadding: padding,
        animated: animated ?? true
      )
    }
  }

  func animateCamera(_ camera: Camera, duration: Double?) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }

      let mkCamera = MKMapCamera(
        lookingAtCenter: CLLocationCoordinate2D(
          latitude: camera.center.latitude,
          longitude: camera.center.longitude
        ),
        fromDistance: self.altitudeFromZoom(camera.zoom),
        pitch: CGFloat(camera.pitch),
        heading: camera.heading
      )

      // Use setCamera with animation
      let shouldAnimate = (duration ?? 300) > 0
      if shouldAnimate {
        self.mkMapView.setCamera(mkCamera, animated: true)
      } else {
        self.mkMapView.camera = mkCamera
      }
    }
  }

  func setCamera(_ camera: Camera) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }

      let mkCamera = MKMapCamera(
        lookingAtCenter: CLLocationCoordinate2D(
          latitude: camera.center.latitude,
          longitude: camera.center.longitude
        ),
        fromDistance: self.altitudeFromZoom(camera.zoom),
        pitch: CGFloat(camera.pitch),
        heading: camera.heading
      )
      self.mkMapView.camera = mkCamera
    }
  }

  func getCamera() -> Camera {
    let cam = mkMapView.camera
    return Camera(
      center: Coordinate(
        latitude: cam.centerCoordinate.latitude,
        longitude: cam.centerCoordinate.longitude
      ),
      pitch: Double(cam.pitch),
      heading: cam.heading,
      altitude: cam.centerCoordinateDistance,
      zoom: zoomFromAltitude(cam.centerCoordinateDistance)
    )
  }

  func getMapBoundaries() -> MapBoundaries? {
    let region = mkMapView.region

    let northEast = CLLocationCoordinate2D(
      latitude: region.center.latitude + region.span.latitudeDelta / 2,
      longitude: region.center.longitude + region.span.longitudeDelta / 2
    )

    let southWest = CLLocationCoordinate2D(
      latitude: region.center.latitude - region.span.latitudeDelta / 2,
      longitude: region.center.longitude - region.span.longitudeDelta / 2
    )

    return MapBoundaries(
      northEast: Coordinate(
        latitude: northEast.latitude,
        longitude: northEast.longitude
      ),
      southWest: Coordinate(
        latitude: southWest.latitude,
        longitude: southWest.longitude
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
      // Trigger clustering after all markers are added
      self.performClustering()
    }
  }

  private func addMarkerSync(_ data: MarkerData) {
    removeMarkerSync(data.id)

    markerData[data.id] = data

    if data.clusteringEnabled && (clusterConfig?.enabled ?? true) {
      // Add to C++ cluster engine
      clusterableMarkerData[data.id] = data
      clusteringManager.addMarker(data)
      // Don't add to map directly - performClustering will render it
    } else {
      // Non-clustered marker - add directly to map
      let annotation = createAnnotation(from: data)
      markers[data.id] = annotation
      mkMapView.addAnnotation(annotation)
      nonClusteredAnnotations[data.id] = annotation
    }
  }

  private func createAnnotation(from data: MarkerData) -> NitroAnnotation {
    let annotation = NitroAnnotation(markerData: data)
    annotation.coordinate = CLLocationCoordinate2D(
      latitude: data.coordinate.latitude,
      longitude: data.coordinate.longitude
    )
    annotation.title = data.title
    annotation.subtitle = data.description
    return annotation
  }

  func updateMarker(_ marker: MarkerData) {
    DispatchQueue.main.async { [weak self] in
      self?.removeMarkerSync(marker.id)
      self?.addMarkerSync(marker)
    }
  }

  func removeMarker(_ id: String) {
    DispatchQueue.main.async { [weak self] in
      self?.removeMarkerSync(id)
    }
  }

  private func removeMarkerSync(_ id: String) {
    markerData.removeValue(forKey: id)
    clusterableMarkerData.removeValue(forKey: id)
    clusteringManager.removeMarker(id)

    // Remove rendered single annotation if exists
    if let annotation = renderedSingleAnnotations[id] {
      mkMapView.removeAnnotation(annotation)
      renderedSingleAnnotations.removeValue(forKey: id)
    }

    // Remove non-clustered annotation if exists
    if let annotation = nonClusteredAnnotations[id] {
      mkMapView.removeAnnotation(annotation)
      nonClusteredAnnotations.removeValue(forKey: id)
    }

    markers.removeValue(forKey: id)
  }

  func clearMarkers() {
    DispatchQueue.main.async { [weak self] in
      self?.clearMarkersSync()
    }
  }

  private func clearMarkersSync() {
    clusteringManager.clearMarkers()
    clusterableMarkerData.removeAll()
    clearRenderedMarkers()

    // Clear non-clustered annotations
    for (_, annotation) in nonClusteredAnnotations {
      mkMapView.removeAnnotation(annotation)
    }
    nonClusteredAnnotations.removeAll()

    markers.removeAll()
    markerData.removeAll()
  }
  private var selectedMarkerId: String?
  private var isAnimatingToMarker: Bool = false

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

      // Select annotation and animate to it
      if let annotation = self.renderedSingleAnnotations[id]
        ?? self.nonClusteredAnnotations[id]
      {
        self.mkMapView.selectAnnotation(annotation, animated: true)

        // Animate to marker position (with flag to prevent re-clustering)
        self.isAnimatingToMarker = true
        let coordinate = annotation.coordinate
        let currentRegion = self.mkMapView.region
        let newRegion = MKCoordinateRegion(
          center: coordinate,
          span: currentRegion.span
        )
        self.mkMapView.setRegion(newRegion, animated: true)

        // Reset flag after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
          self.isAnimatingToMarker = false
        }
      }
    }
  }

  /// Update a marker's visual selection state by regenerating its annotation view
  private func updateMarkerSelectionState(_ id: String, selected: Bool) {
    guard let data = markerData[id] else { return }
    
    // Use shared helper to create updated marker data with selection state
    guard let updatedData = MarkerSelectionHandler.shared.updateSelectionState(for: data, selected: selected) else {
      return
    }
    
    // Update stored data
    markerData[id] = updatedData
    
    // Update the annotation's data and refresh its view directly (no remove/add!)
    if let annotation = markers[id] as? NitroAnnotation {
      annotation.markerData = updatedData
      
      // Find and update the annotation view directly
      if let view = mkMapView.view(for: annotation) as? NitroAnnotationView {
        view.configure(with: updatedData, clusteringEnabled: true)
      }
    }
  }

  // MARK: - Clustering Control

  func setClusteringEnabled(_ enabled: Bool) {
    var config =
      clusterConfig
      ?? ClusterConfig(
        enabled: enabled,
        minimumClusterSize: 2,
        maxZoom: 20,
        backgroundColor: .second(MarkerColor(r: 0, g: 122, b: 255, a: 255)),
        textColor: .second(MarkerColor(r: 255, g: 255, b: 255, a: 255)),
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

  // MARK: - Map Style

  func setMapStyle(_ style: [MapStyleElement]?) {
    // MapKit doesn't support custom JSON styles like Google Maps
    // This is a limitation of Apple Maps
    print("AppleMapProvider: Custom map styles are not supported in MapKit")
  }

  func setDarkMode(_ enabled: Bool) {
    DispatchQueue.main.async { [weak self] in
      self?.darkMode = enabled
    }
  }

  private func applyDarkMode() {
    if let isDark = darkMode {
      mkMapView.overrideUserInterfaceStyle = isDark ? .dark : .light
    }
  }

  // MARK: - Helper Methods

  private func updateCameraToInitialRegion() {
    guard let region = initialRegion else { return }

    let mkRegion = MKCoordinateRegion(
      center: CLLocationCoordinate2D(
        latitude: region.latitude,
        longitude: region.longitude
      ),
      span: MKCoordinateSpan(
        latitudeDelta: region.latitudeDelta,
        longitudeDelta: region.longitudeDelta
      )
    )
    mkMapView.setRegion(mkRegion, animated: true)
  }

  private func convertMapType(_ type: MapType?) -> MKMapType {
    switch type {
    case .satellite: return .satellite
    case .hybrid: return .hybrid
    case .standard, .none: return .standard
    }
  }

  private func altitudeFromZoom(_ zoom: Double) -> CLLocationDistance {
    // Approximate conversion from Google Maps zoom to altitude
    return 40_000_000 / pow(2, zoom)
  }

  private func zoomFromAltitude(_ altitude: CLLocationDistance) -> Double {
    // Approximate conversion from altitude to Google Maps zoom
    return log2(40_000_000 / altitude)
  }

  func getCurrentRegion() -> Region {
    let region = mkMapView.region
    return Region(
      latitude: region.center.latitude,
      longitude: region.center.longitude,
      latitudeDelta: region.span.latitudeDelta,
      longitudeDelta: region.span.longitudeDelta
    )
  }

  // MARK: - Marker Data Accessor

  func getMarkerData(for id: String) -> MarkerData? {
    return markerData[id]
  }

  func isClusteringEnabled() -> Bool {
    return clusterConfig?.enabled ?? true
  }

  func getClusterConfig() -> ClusterConfig? {
    return clusterConfig
  }
}

// MARK: - UIGestureRecognizerDelegate

@available(iOS 17.0, *)
extension AppleMapProvider: UIGestureRecognizerDelegate {
  func gestureRecognizer(
    _ gestureRecognizer: UIGestureRecognizer,
    shouldRecognizeSimultaneouslyWith otherGestureRecognizer:
      UIGestureRecognizer
  ) -> Bool {
    return true
  }
}

// MARK: - Custom Annotation

class NitroAnnotation: MKPointAnnotation {
  var markerData: MarkerData

  init(markerData: MarkerData) {
    self.markerData = markerData
    super.init()
  }
}

// MARK: - Cluster Annotation (for C++ engine clusters)

class ClusterAnnotation: MKPointAnnotation {
  let markerIds: [String]
  let count: Int

  init(coordinate: CLLocationCoordinate2D, markerIds: [String], count: Int) {
    self.markerIds = markerIds
    self.count = count
    super.init()
    self.coordinate = coordinate
  }
}

// MARK: - C++ Cluster Annotation View

@available(iOS 17.0, *)
class ClusterAnnotationView: MKAnnotationView {
  static let reuseIdentifier = "ClusterAnnotationView"

  private weak var provider: AppleMapProvider?

  override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
    super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
    displayPriority = .required
    collisionMode = .circle
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func configure(provider: AppleMapProvider?) {
    self.provider = provider

    guard let clusterAnnotation = annotation as? ClusterAnnotation else {
      return
    }

    // Use the same icon generator as Google Maps
    let config = provider?.getClusterConfig()
    let size: CGFloat = 40

    image = createClusterIcon(
      count: clusterAnnotation.count,
      size: size,
      config: config
    )
    centerOffset = CGPoint(x: 0, y: -size / 2)
  }

  private func createClusterIcon(
    count: Int,
    size: CGFloat,
    config: ClusterConfig?
  ) -> UIImage {
    UIGraphicsBeginImageContextWithOptions(
      CGSize(width: size, height: size),
      false,
      0
    )
    guard let context = UIGraphicsGetCurrentContext() else {
      return UIImage()
    }

    let rect = CGRect(x: 0, y: 0, width: size, height: size)

    // Background
    let bgColor =
      config?.backgroundColor.toMarkerColor() ?? MarkerColor(r: 255, g: 87, b: 51, a: 255)
    context.setFillColor(
      UIColor(
        red: CGFloat(bgColor.r) / 255,
        green: CGFloat(bgColor.g) / 255,
        blue: CGFloat(bgColor.b) / 255,
        alpha: CGFloat(bgColor.a) / 255
      ).cgColor
    )
    context.fillEllipse(in: rect)

    // Border
    if let borderWidth = config?.borderWidth, borderWidth > 0 {
      let borderColor =
        config?.borderColor.toMarkerColor() ?? MarkerColor(r: 255, g: 255, b: 255, a: 255)
      context.setStrokeColor(
        UIColor(
          red: CGFloat(borderColor.r) / 255,
          green: CGFloat(borderColor.g) / 255,
          blue: CGFloat(borderColor.b) / 255,
          alpha: CGFloat(borderColor.a) / 255
        ).cgColor
      )
      context.setLineWidth(CGFloat(borderWidth))
      let inset = CGFloat(borderWidth) / 2
      context.strokeEllipse(in: rect.insetBy(dx: inset, dy: inset))
    }

    // Text
    let textColor =
      config?.textColor.toMarkerColor() ?? MarkerColor(r: 255, g: 255, b: 255, a: 255)
    let text = "\(count)"
    let attributes: [NSAttributedString.Key: Any] = [
      .font: UIFont.boldSystemFont(ofSize: size * 0.4),
      .foregroundColor: UIColor(
        red: CGFloat(textColor.r) / 255,
        green: CGFloat(textColor.g) / 255,
        blue: CGFloat(textColor.b) / 255,
        alpha: CGFloat(textColor.a) / 255
      ),
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

// MARK: - Custom Annotation View

class NitroAnnotationView: MKAnnotationView {
  static let reuseIdentifier = "NitroAnnotationView"

  override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
    super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
    canShowCallout = true
    // Disable MapKit's native clustering - using C++ engine instead
    clusteringIdentifier = nil
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func configure(with markerData: MarkerData, clusteringEnabled: Bool) {
    // Never set clusteringIdentifier - we use C++ engine, not MapKit's native clustering
    clusteringIdentifier = nil

    // Set icon
    if let icon = MarkerIconFactory.createIcon(for: markerData) {
      image = icon
    }

    // Set properties
    isDraggable = markerData.draggable
    alpha = CGFloat(markerData.opacity)

    // Set anchor
    let anchorX = markerData.anchor.x
    let anchorY = markerData.anchor.y
    centerOffset = CGPoint(
      x: (0.5 - anchorX) * bounds.width,
      y: (0.5 - anchorY) * bounds.height
    )
  }
}

// MARK: - Cluster Annotation View

class NitroClusterAnnotationView: MKAnnotationView {

  override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
    super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
    collisionMode = .circle
    centerOffset = CGPoint(x: 0, y: -10)
  }

  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func prepareForDisplay() {
    super.prepareForDisplay()

    guard let cluster = annotation as? MKClusterAnnotation else { return }

    let count = cluster.memberAnnotations.count
    image = createClusterImage(count: count)
    displayPriority = .defaultHigh
  }

  private func createClusterImage(count: Int, config: ClusterConfig? = nil)
    -> UIImage
  {
    let size: CGFloat = count > 99 ? 50 : (count > 9 ? 44 : 40)
    let rect = CGRect(x: 0, y: 0, width: size, height: size)

    UIGraphicsBeginImageContextWithOptions(rect.size, false, 0)
    guard let context = UIGraphicsGetCurrentContext() else {
      return UIImage()
    }

    // Background color
    let bgColor =
      config?.backgroundColor.toMarkerColor() ?? MarkerColor(r: 0, g: 122, b: 255, a: 255)
    context.setFillColor(
      UIColor(
        red: CGFloat(bgColor.r) / 255,
        green: CGFloat(bgColor.g) / 255,
        blue: CGFloat(bgColor.b) / 255,
        alpha: CGFloat(bgColor.a) / 255
      ).cgColor
    )
    context.fillEllipse(in: rect)

    // Border
    if let borderWidth = config?.borderWidth, borderWidth > 0 {
      let borderColor =
        config?.borderColor.toMarkerColor() ?? MarkerColor(r: 255, g: 255, b: 255, a: 255)
      context.setStrokeColor(
        UIColor(
          red: CGFloat(borderColor.r) / 255,
          green: CGFloat(borderColor.g) / 255,
          blue: CGFloat(borderColor.b) / 255,
          alpha: CGFloat(borderColor.a) / 255
        ).cgColor
      )
      context.setLineWidth(CGFloat(borderWidth))
      let inset = CGFloat(borderWidth) / 2
      context.strokeEllipse(in: rect.insetBy(dx: inset, dy: inset))
    }

    // Text
    let textColor =
      config?.textColor.toMarkerColor() ?? MarkerColor(r: 255, g: 255, b: 255, a: 255)
    let text = "\(count)"
    let attributes: [NSAttributedString.Key: Any] = [
      .font: UIFont.boldSystemFont(ofSize: size * 0.4),
      .foregroundColor: UIColor(
        red: CGFloat(textColor.r) / 255,
        green: CGFloat(textColor.g) / 255,
        blue: CGFloat(textColor.b) / 255,
        alpha: CGFloat(textColor.a) / 255
      ),
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
