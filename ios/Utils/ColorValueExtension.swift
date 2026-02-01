import Foundation
import UIKit

// MARK: - ColorValue Extension
// Shared extension for converting ColorValue (hex string or MarkerColor) to MarkerColor
extension ColorValue {
  /// Extract MarkerColor from ColorValue, parsing hex string if needed
  func toMarkerColor() -> MarkerColor {
    switch self {
    case .first(let hexString):
      return ColorValue.parseHex(hexString)
    case .second(let markerColor):
      return markerColor
    }
  }

  /// Parse hex color string to MarkerColor
  private static func parseHex(_ hex: String) -> MarkerColor {
    var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

    var rgb: UInt64 = 0
    Scanner(string: hexSanitized).scanHexInt64(&rgb)

    let r, g, b: Double
    if hexSanitized.count == 6 {
      r = Double((rgb & 0xFF0000) >> 16)
      g = Double((rgb & 0x00FF00) >> 8)
      b = Double(rgb & 0x0000FF)
    } else if hexSanitized.count == 3 {
      r = Double((rgb & 0xF00) >> 8) * 17
      g = Double((rgb & 0x0F0) >> 4) * 17
      b = Double(rgb & 0x00F) * 17
    } else {
      r = 0; g = 0; b = 0
    }

    return MarkerColor(r: r, g: g, b: b, a: 255)
  }
}

// MARK: - UIColor Helper
extension ColorValue {
  /// Convert ColorValue directly to UIColor
  func toUIColor() -> UIColor {
    let color = self.toMarkerColor()
    return UIColor(
      red: CGFloat(color.r) / 255,
      green: CGFloat(color.g) / 255,
      blue: CGFloat(color.b) / 255,
      alpha: CGFloat(color.a) / 255
    )
  }
}
