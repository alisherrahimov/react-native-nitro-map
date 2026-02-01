import UIKit

/// Global marker icon cache with aggressive texture reuse
final class MarkerIconCache {
  static let shared = MarkerIconCache()

  // Use NSCache for automatic memory management
  private let cache = NSCache<NSString, UIImage>()

  // Separate cache for URL image data to avoid repeated network calls
  private let urlImageCache = NSCache<NSString, UIImage>()

  // Track unique icon count for debugging
  private var uniqueIconCount = 0
  private var cacheHits = 0
  private var cacheMisses = 0

  private init() {
    // Increased limits to handle more markers without texture exhaustion
    cache.countLimit = 500 // Max 500 unique icons (was 200)
    cache.totalCostLimit = 100 * 1024 * 1024 // 100MB max (was 50MB)

    urlImageCache.countLimit = 200
    urlImageCache.totalCostLimit = 50 * 1024 * 1024

    // Listen for memory warnings to clear caches
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleMemoryWarning),
      name: UIApplication.didReceiveMemoryWarningNotification,
      object: nil
    )
  }

  @objc private func handleMemoryWarning() {
    // Clear half the cache on memory warning instead of all
    // This keeps frequently used icons while freeing memory
    print("[MarkerIconCache] Memory warning received, clearing caches")
    cache.removeAllObjects()
    urlImageCache.removeAllObjects()
    uniqueIconCount = 0
  }

  func getIcon(forKey key: String) -> UIImage? {
    if let cached = cache.object(forKey: key as NSString) {
      cacheHits += 1
      logStatsIfNeeded()
      return cached
    }
    cacheMisses += 1
    logStatsIfNeeded()
    return nil
  }

  func setIcon(_ image: UIImage, forKey key: String) {
    // Calculate cost based on image size for better memory management
    let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
    cache.setObject(image, forKey: key as NSString, cost: cost)
    uniqueIconCount += 1

    if uniqueIconCount % 100 == 0 {
      print("[MarkerIconCache] Cached \(uniqueIconCount) unique icons")
    }
  }
  
  private func logStatsIfNeeded() {
    let total = cacheHits + cacheMisses
    if total > 0 && total % 500 == 0 {
      let hitRate = Double(cacheHits) / Double(total) * 100
      print("[MarkerIconCache] Stats: hits=\(cacheHits), misses=\(cacheMisses), hitRate=\(String(format: "%.1f", hitRate))%, unique=\(uniqueIconCount)")
    }
  }

  func getURLImage(forKey key: String) -> UIImage? {
    return urlImageCache.object(forKey: key as NSString)
  }

  func setURLImage(_ image: UIImage, forKey key: String) {
    let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
    urlImageCache.setObject(image, forKey: key as NSString, cost: cost)
  }

  func clear() {
    cache.removeAllObjects()
    urlImageCache.removeAllObjects()
    uniqueIconCount = 0
  }

  /// Generate a simplified cache key for price markers
  /// Reduces texture diversity by bucketing similar configurations
  static func priceMarkerKey(
    price: String,
    currency: String,
    selected: Bool
  ) -> String {
    // Normalize price to reduce unique textures
    return "price_\(price)_\(currency)_\(selected)"
  }

  /// Generate cache key for image markers
  static func imageMarkerKey(
    source: String,
    width: Double,
    height: Double,
    cornerRadius: Double
  ) -> String {
    // Round dimensions to reduce unique keys
    let w = Int(width / 5) * 5  // Round to nearest 5
    let h = Int(height / 5) * 5
    let r = Int(cornerRadius / 5) * 5
    // Use stable hash for cache key
    let sourceHash = stableHash(source)
    return "image_\(sourceHash)_\(w)_\(h)_\(r)"
  }

  /// Stable hash that doesn't change between app launches
  private static func stableHash(_ string: String) -> Int {
    var hash = 5381
    for char in string.utf8 {
      hash = ((hash << 5) &+ hash) &+ Int(char)
    }
    return abs(hash)
  }
}

class MarkerIconFactory {
  
  static func createIcon(for markerData: MarkerData) -> UIImage? {
    switch markerData.config.style {
    case .image:
      return createImageMarkerIcon(markerData.config.image)
    case .pricemarker:
      return createPriceMarkerIcon(markerData.config.priceMarker)
    case .default:
      return nil
    }
  }
  
  // MARK: - Price Marker Icon
  private static func createPriceMarkerIcon(_ config: PriceMarkerStyle?) -> UIImage? {
    guard let config = config else { return nil }
    
    // Generate normalized cache key
    let cacheKey = MarkerIconCache.priceMarkerKey(
      price: config.price,
      currency: config.currency,
      selected: config.selected
    )
    
    // Check cache first
    if let cachedImage = MarkerIconCache.shared.getIcon(forKey: cacheKey) {
      return cachedImage
    }
    
    // Generate new icon
    let image = PriceMarkerRenderer.render(config: config)
    
    // Cache the result
    MarkerIconCache.shared.setIcon(image, forKey: cacheKey)
    
    return image
  }
  
  // MARK: - Image Marker Icon
  private static func createImageMarkerIcon(_ config: ImageMarkerConfig?) -> UIImage? {
    guard let config = config else { return nil }

    let imageSource = config.imageBase64 ?? config.imageUrl ?? ""

    // Generate normalized cache key
    let cacheKey = MarkerIconCache.imageMarkerKey(
      source: imageSource,
      width: config.width,
      height: config.height,
      cornerRadius: config.cornerRadius
    )

    // Check cache first
    if let cachedImage = MarkerIconCache.shared.getIcon(forKey: cacheKey) {
      return cachedImage
    }

    var sourceImage: UIImage?

    if let base64 = config.imageBase64,
       let data = Data(base64Encoded: base64)
    {
      sourceImage = UIImage(data: data)
    } else if let urlString = config.imageUrl {
      // Check URL image cache first
      if let cachedURLImage = MarkerIconCache.shared.getURLImage(forKey: urlString) {
        sourceImage = cachedURLImage
      } else {
        // Load URL image on background thread to avoid blocking
        // Return placeholder and trigger async load
        loadURLImageAsync(urlString: urlString, cacheKey: cacheKey, config: config)
        // Return a placeholder image for now
        sourceImage = createPlaceholderImage(
          width: CGFloat(config.width),
          height: CGFloat(config.height)
        )
      }
    }

    let image = renderImageMarker(sourceImage: sourceImage, config: config)

    // Cache the result (will be replaced when async image loads)
    MarkerIconCache.shared.setIcon(image, forKey: cacheKey)

    return image
  }

  /// Load URL image asynchronously to prevent blocking the main thread
  private static func loadURLImageAsync(urlString: String, cacheKey: String, config: ImageMarkerConfig) {
    guard let url = URL(string: urlString) else { return }

    DispatchQueue.global(qos: .userInitiated).async {
      guard let data = try? Data(contentsOf: url),
            let image = UIImage(data: data) else {
        return
      }

      // Cache the downloaded image
      DispatchQueue.main.async {
        MarkerIconCache.shared.setURLImage(image, forKey: urlString)

        // Render the final marker icon with the loaded image
        let finalIcon = renderImageMarker(sourceImage: image, config: config)
        MarkerIconCache.shared.setIcon(finalIcon, forKey: cacheKey)

        // Post notification for markers to refresh their icons
        NotificationCenter.default.post(
          name: Notification.Name("MarkerIconLoaded"),
          object: nil,
          userInfo: ["cacheKey": cacheKey, "icon": finalIcon]
        )
      }
    }
  }

  /// Create a placeholder image while URL image loads
  private static func createPlaceholderImage(width: CGFloat, height: CGFloat) -> UIImage {
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
    return renderer.image { context in
      let rect = CGRect(x: 0, y: 0, width: width, height: height)
      UIColor.lightGray.withAlphaComponent(0.3).setFill()
      UIBezierPath(roundedRect: rect, cornerRadius: width * 0.1).fill()
    }
  }

  /// Render image marker with given source image
  private static func renderImageMarker(sourceImage: UIImage?, config: ImageMarkerConfig) -> UIImage {
    let width = CGFloat(config.width)
    let height = CGFloat(config.height)
    let cornerRadius = CGFloat(config.cornerRadius)
    let borderWidth = CGFloat(config.borderWidth)

    let borderColorValue = config.borderColor.toMarkerColor()
    let borderColor = UIColor(
      red: CGFloat(borderColorValue.r) / 255,
      green: CGFloat(borderColorValue.g) / 255,
      blue: CGFloat(borderColorValue.b) / 255,
      alpha: CGFloat(borderColorValue.a) / 255
    )

    let renderer = UIGraphicsImageRenderer(
      size: CGSize(width: width, height: height)
    )
    return renderer.image { context in
      let rect = CGRect(x: 0, y: 0, width: width, height: height)
      let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)

      // Clip to rounded rect
      path.addClip()

      // Draw image
      if let image = sourceImage {
        image.draw(in: rect)
      } else {
        UIColor.lightGray.setFill()
        UIRectFill(rect)
      }

      // Draw border
      if borderWidth > 0 {
        borderColor.setStroke()
        path.lineWidth = borderWidth
        path.stroke()
      }
    }
  }
  
  // MARK: - Cache Management
  static func clearCache() {
    MarkerIconCache.shared.clear()
  }
}
