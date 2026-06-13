import MapKit

/// MKAnnotation backing one establishment pin. Carries the result code so the
/// annotation view can tint itself and join a same-color cluster.
final class EstablishmentAnnotation: NSObject, MKAnnotation {
    let establishmentID: String
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let resultCode: Int
    let score: Int?
    let rawResult: String?

    init(pin: MapPin) {
        self.establishmentID = pin.id
        self.coordinate = pin.coordinate
        self.title = pin.name
        self.resultCode = pin.resultCode
        self.score = pin.score
        self.rawResult = pin.rawResult
    }

    var result: InspectionResult { InspectionResult(rawValue: resultCode) ?? .other }
}
