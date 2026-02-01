import Foundation
import GoogleMaps
import NitroModules
import YandexMapsMobile

class HybridNitroMapConfig: HybridNitroMapConfigSpec {

  // Static flag to track initialization across all instances
  private static var isInitialized = false

  func NitroMapInitialize(apiKey: String, provider: MapProvider) {
    // Use static flag to prevent duplicate initialization
    guard !HybridNitroMapConfig.isInitialized else {
      print("[NitroMap] Already initialized, skipping...")
      return
    }
    
    // Set initialized BEFORE async dispatch to prevent race conditions
    HybridNitroMapConfig.isInitialized = true
    
    DispatchQueue.main.async {
      switch provider {
      case .apple:
        break
      case .google:
        GMSServices.provideAPIKey(apiKey)
        print("[NitroMap] Google Maps initialized")
        break
      case .yandex:
        YMKMapKit.setApiKey(apiKey)
        YMKMapKit.sharedInstance()
        print("[NitroMap] Yandex Maps initialized")
        break
      }
    }
  }

  func IsNitroMapInitialized() -> Bool {
    return HybridNitroMapConfig.isInitialized
  }
}
