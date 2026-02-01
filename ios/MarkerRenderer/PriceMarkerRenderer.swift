// ios/MarkerRenderer/PriceMarkerRenderer.swift
import UIKit

class PriceMarkerRenderer {
  
  struct Style {
    var price: String
    var currency: String
    var selected: Bool
    var backgroundColor: UIColor
    var selectedBackgroundColor: UIColor
    var textColor: UIColor
    var selectedTextColor: UIColor
    var fontSize: CGFloat
    var paddingHorizontal: CGFloat
    var paddingVertical: CGFloat
    var shadowOpacity: Float
    
    static func fromConfig(_ config: PriceMarkerStyle?) -> Style {
      guard let config = config else {
        return Style(
          price: "0",
          currency: "UZS",
          selected: false,
          backgroundColor: .white,
          selectedBackgroundColor: UIColor(red: 255/255, green: 59/255, blue: 48/255, alpha: 1),
          textColor: UIColor(red: 51/255, green: 51/255, blue: 51/255, alpha: 1),
          selectedTextColor: .white,
          fontSize: 10,
          paddingHorizontal: 8,
          paddingVertical: 6,
          shadowOpacity: 0.12
        )
      }
      
      return Style(
        price: config.price,
        currency: config.currency,
        selected: config.selected,
        backgroundColor: config.backgroundColor.map { UIColor(
          red: CGFloat($0.r) / 255,
          green: CGFloat($0.g) / 255,
          blue: CGFloat($0.b) / 255,
          alpha: CGFloat($0.a) / 255
        )} ?? .white,
        selectedBackgroundColor: config.selectedBackgroundColor.map { UIColor(
          red: CGFloat($0.r) / 255,
          green: CGFloat($0.g) / 255,
          blue: CGFloat($0.b) / 255,
          alpha: CGFloat($0.a) / 255
        )} ?? UIColor(red: 255/255, green: 59/255, blue: 48/255, alpha: 1),
        textColor: config.textColor.map { UIColor(
          red: CGFloat($0.r) / 255,
          green: CGFloat($0.g) / 255,
          blue: CGFloat($0.b) / 255,
          alpha: CGFloat($0.a) / 255
        )} ?? UIColor(red: 51/255, green: 51/255, blue: 51/255, alpha: 1),
        selectedTextColor: config.selectedTextColor.map { UIColor(
          red: CGFloat($0.r) / 255,
          green: CGFloat($0.g) / 255,
          blue: CGFloat($0.b) / 255,
          alpha: CGFloat($0.a) / 255
        )} ?? .white,
        fontSize: CGFloat(10), // config.fontSize
        paddingHorizontal: CGFloat(config.paddingHorizontal ?? 8),
        paddingVertical: CGFloat(config.paddingVertical ?? 6),
        shadowOpacity: Float(config.shadowOpacity ?? 0.12)
      )
    }
  }
  
  static func render(config: PriceMarkerStyle?) -> UIImage {
    let style = Style.fromConfig(config)
    
    // Build text: "9M UZS"
    let text = "\(style.price) \(style.currency)"
    
    // Font
    let font = UIFont.systemFont(ofSize: style.fontSize, weight: .light)
    let attributes: [NSAttributedString.Key: Any] = [.font: font]
    let textSize = text.size(withAttributes: attributes)
    
    // Calculate size with padding
    let width = textSize.width + style.paddingHorizontal * 2
    let height = textSize.height + style.paddingVertical * 2
    
    // Reduced shadow size for smaller textures (was 20, now 8)
    let shadowBlur: CGFloat = 8
    let shadowOffset: CGFloat = 2
    let canvasWidth = width + shadowBlur * 2
    let canvasHeight = height + shadowBlur + shadowOffset + shadowBlur / 2
    
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: canvasWidth, height: canvasHeight))
    
    return renderer.image { context in
      let ctx = context.cgContext
      
      // Pill rect (centered with shadow space)
      let pillRect = CGRect(
        x: shadowBlur,
        y: shadowBlur / 2,
        width: width,
        height: height
      )
      
      // Corner radius = half height for pill shape
      let cornerRadius = height / 2
      let path = UIBezierPath(roundedRect: pillRect, cornerRadius: cornerRadius)
      
      // Shadow
      ctx.saveGState()
      ctx.setShadow(
        offset: CGSize(width: 0, height: shadowOffset),
        blur: shadowBlur,
        color: UIColor.black.withAlphaComponent(CGFloat(style.shadowOpacity)).cgColor
      )
      
      // Background
      let bgColor = style.selected ? style.selectedBackgroundColor : style.backgroundColor
      bgColor.setFill()
      path.fill()
      
      ctx.restoreGState()
      
      // Text
      let textColor = style.selected ? style.selectedTextColor : style.textColor
      let textRect = CGRect(
        x: pillRect.origin.x + style.paddingHorizontal,
        y: pillRect.origin.y + style.paddingVertical,
        width: textSize.width,
        height: textSize.height
      )
      
      text.draw(in: textRect, withAttributes: [
        .font: font,
        .foregroundColor: textColor
      ])
    }
  }
}
