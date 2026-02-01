import Foundation
import GoogleMapsUtils
import UIKit

class NitroClusterIconGenerator: GMUDefaultClusterIconGenerator {

  private var config: ClusterConfig?

  func updateConfig(_ config: ClusterConfig?) {
    self.config = config
  }

  override func icon(forSize size: UInt) -> UIImage {
    let diameter: CGFloat = size < 10 ? 30 : (size < 100 ? 35 : 40)

    let bgColor =
      config.map {
        let color = $0.backgroundColor.toMarkerColor()
        return UIColor(
          red: CGFloat(color.r) / 255,
          green: CGFloat(color.g) / 255,
          blue: CGFloat(color.b) / 255,
          alpha: CGFloat(color.a) / 255
        )
      } ?? UIColor(red: 0, green: 0.478, blue: 1, alpha: 1)

    let textColor =
      config.map {
        let color = $0.textColor.toMarkerColor()
        return UIColor(
          red: CGFloat(color.r) / 255,
          green: CGFloat(color.g) / 255,
          blue: CGFloat(color.b) / 255,
          alpha: CGFloat(color.a) / 255
        )
      } ?? .white

    let borderWidth = CGFloat(config?.borderWidth ?? 2)
    let borderColor =
      config.map {
        let color = $0.borderColor.toMarkerColor()
        return UIColor(
          red: CGFloat(color.r) / 255,
          green: CGFloat(color.g) / 255,
          blue: CGFloat(color.b) / 255,
          alpha: CGFloat(color.a) / 255
        )
      } ?? .white

    let renderer = UIGraphicsImageRenderer(
      size: CGSize(width: diameter, height: diameter)
    )
    return renderer.image { context in
      let rect = CGRect(
        x: borderWidth,
        y: borderWidth,
        width: diameter - borderWidth * 2,
        height: diameter - borderWidth * 2
      )

      // Border
      borderColor.setFill()
      context.cgContext.fillEllipse(
        in: CGRect(x: 0, y: 0, width: diameter, height: diameter)
      )

      // Background
      bgColor.setFill()
      context.cgContext.fillEllipse(in: rect)

      // Text
      let text = "\(size)"
      let font = UIFont.boldSystemFont(ofSize: diameter * 0.35)
      let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: textColor,
      ]
      let textSize = text.size(withAttributes: attributes)
      let textRect = CGRect(
        x: (diameter - textSize.width) / 2,
        y: (diameter - textSize.height) / 2,
        width: textSize.width,
        height: textSize.height
      )
      text.draw(in: textRect, withAttributes: attributes)
    }
  }
}
