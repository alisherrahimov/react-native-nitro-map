import Foundation
import GoogleMaps
import GoogleMapsUtils

class NitroClusterItem: NSObject, GMUClusterItem {
  var position: CLLocationCoordinate2D
  var markerId: String
  var markerData: MarkerData

  init(markerId: String, markerData: MarkerData) {
    self.markerId = markerId
    self.markerData = markerData
    self.position = CLLocationCoordinate2D(
      latitude: markerData.coordinate.latitude,
      longitude: markerData.coordinate.longitude
    )
    super.init()
  }
}
