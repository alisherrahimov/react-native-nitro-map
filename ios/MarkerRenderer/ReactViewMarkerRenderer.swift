import UIKit
import QuartzCore

/// Renderer for capturing React Native views as marker icons
/// Works with New Architecture (Fabric) only
class ReactViewMarkerRenderer {
  
  /// Capture a React Native view by its nativeID and return as UIImage
  /// - Parameters:
  ///   - nativeId: The nativeID prop value (maps to accessibilityIdentifier)
  ///   - viewTag: React Native view tag (fallback)
  ///   - width: Expected width of the view
  ///   - height: Expected height of the view
  /// - Returns: UIImage of the captured view, or nil if capture failed
  static func captureView(nativeId: String, viewTag: Int, width: CGFloat, height: CGFloat) -> UIImage? {
    print("[ReactViewMarkerRenderer] 📸 CAPTURE CALLED: nativeId='\(nativeId)', viewTag=\(viewTag), size=\(width)x\(height)")
    
    // Find root view
    guard let rootView = findRootView() else {
      print("[ReactViewMarkerRenderer] Could not find root view")
      return nil
    }
    
    // First try to find by nativeID (accessibilityIdentifier)
    var targetView: UIView? = findView(withNativeId: nativeId, in: rootView)
    
    // Fallback: try finding by tag
    if targetView == nil {
      print("[ReactViewMarkerRenderer] nativeId lookup failed, trying viewTag: \(viewTag)")
      targetView = findView(withTag: viewTag, in: rootView)
    }
    
    guard let view = targetView else {
      print("[ReactViewMarkerRenderer] Could not find view with nativeId='\(nativeId)' or viewTag=\(viewTag)")
      return nil
    }
    
    print("[ReactViewMarkerRenderer] Found view: \(type(of: view)), bounds=\(view.bounds), hidden=\(view.isHidden), alpha=\(view.alpha)")
    
    // Log subview hierarchy for debugging
    logSubviewHierarchy(view, indent: "  ")
    
    // Use the actual view bounds if dimensions are invalid
    var captureSize = CGSize(width: width, height: height)
    if captureSize.width <= 0 || captureSize.height <= 0 {
      captureSize = view.bounds.size
    }
    
    guard captureSize.width > 0 && captureSize.height > 0 else {
      print("[ReactViewMarkerRenderer] Invalid capture size: \(captureSize)")
      return nil
    }
    
    // Temporarily ensure view is visible for capture
    let originalAlpha = view.alpha
    let originalHidden = view.isHidden
    view.alpha = 1.0
    view.isHidden = false
    
    // CRITICAL: Force all pending Core Animation transactions to complete
    // This is essential for Fabric text which renders through CALayer
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    
    // Force layout and display updates on all layers
    forceDisplayRecursively(view)
    
    CATransaction.commit()
    
    // Flush all pending CATransactions to ensure layers are updated
    CATransaction.flush()
    
    // Small run loop spin to ensure everything is committed
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
    
    // Another flush after run loop
    CATransaction.flush()
    
    let renderer = UIGraphicsImageRenderer(size: captureSize)
    
    // Use drawHierarchy with afterScreenUpdates:true for Fabric compatibility
    var image = renderer.image { _ in
      view.drawHierarchy(in: CGRect(origin: .zero, size: captureSize), afterScreenUpdates: true)
    }
    
    // If drawHierarchy produced empty image, try layer.render as fallback
    if isImageEmpty(image) {
      print("[ReactViewMarkerRenderer] drawHierarchy produced empty image, trying layer.render")
      image = renderer.image { context in
        view.layer.render(in: context.cgContext)
      }
    }
    
    // Restore original state
    view.alpha = originalAlpha
    view.isHidden = originalHidden
    
    print("[ReactViewMarkerRenderer] Captured image size: \(image.size)")
    return image
  }
  
  /// Force display update on all layers recursively
  private static func forceDisplayRecursively(_ view: UIView) {
    // Force the layer to update its contents
    view.layer.setNeedsLayout()
    view.layer.setNeedsDisplay()
    view.layer.layoutIfNeeded()
    view.layer.displayIfNeeded()
    
    // Also update the view
    view.setNeedsLayout()
    view.setNeedsDisplay()
    view.layoutIfNeeded()
    
    // For text views, try to force redraw
    let typeName = String(describing: type(of: view))
    if typeName.contains("Paragraph") || typeName.contains("Text") {
      // Force text layer to redraw by marking it as needing display
      view.layer.contents = nil
      view.layer.setNeedsDisplay()
      view.layer.displayIfNeeded()
    }
    
    for subview in view.subviews {
      forceDisplayRecursively(subview)
    }
  }
  
  /// Log subview hierarchy for debugging
  private static func logSubviewHierarchy(_ view: UIView, indent: String) {
    for subview in view.subviews {
      let typeName = String(describing: type(of: subview))
      print("[ReactViewMarkerRenderer] \(indent)\(typeName): frame=\(subview.frame), alpha=\(subview.alpha)")
      logSubviewHierarchy(subview, indent: indent + "  ")
    }
  }
  
  /// Check if image is effectively empty (all transparent or single color)
  private static func isImageEmpty(_ image: UIImage) -> Bool {
    guard let cgImage = image.cgImage else { return true }
    let width = cgImage.width
    let height = cgImage.height
    
    // Quick check - if image is very small, consider it valid
    if width < 2 || height < 2 { return true }
    
    // Sample a few pixels to see if there's actual content
    guard let dataProvider = cgImage.dataProvider,
          let data = dataProvider.data,
          let bytes = CFDataGetBytePtr(data) else {
      return true
    }
    
    // Check if all alpha values are 0 (fully transparent)
    let bytesPerPixel = 4
    let length = CFDataGetLength(data)
    var hasContent = false
    
    // Sample every 100th pixel
    for i in stride(from: 3, to: min(length, 4000), by: bytesPerPixel * 10) {
      if bytes[i] > 0 { // Alpha channel
        hasContent = true
        break
      }
    }
    
    return !hasContent
  }
  
  /// Find the root React Native view
  private static func findRootView() -> UIView? {
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let window = windowScene.windows.first else {
      return nil
    }
    return window.rootViewController?.view
  }
  
  /// Find view by nativeID (accessibilityIdentifier in iOS)
  private static func findView(withNativeId nativeId: String, in view: UIView) -> UIView? {
    // Check accessibilityIdentifier (where nativeID is stored)
    if view.accessibilityIdentifier == nativeId {
      return view
    }
    
    // Also check testID which might be stored in accessibilityLabel
    if view.accessibilityLabel == nativeId {
      return view
    }
    
    // Recursively search subviews
    for subview in view.subviews {
      if let found = findView(withNativeId: nativeId, in: subview) {
        return found
      }
    }
    
    return nil
  }
  
  /// Find view by tag (fallback)
  private static func findView(withTag tag: Int, in view: UIView) -> UIView? {
    if view.tag == tag {
      return view
    }
    
    for subview in view.subviews {
      if let found = findView(withTag: tag, in: subview) {
        return found
      }
    }
    
    return nil
  }
}
