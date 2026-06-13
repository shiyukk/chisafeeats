import CoreLocation
import GRDB

/// Slim, Sendable projection of an establishment for map annotations.
/// Carries only what a pin needs — no violations blob — so viewport queries
/// stay cheap.
struct MapPin: Decodable, FetchableRecord, Sendable, Identifiable {
    let id: String
    let latitude: Double
    let longitude: Double
    let name: String
    let resultCode: Int
    let score: Int?
    let rawResult: String?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var result: InspectionResult {
        InspectionResult(rawValue: resultCode) ?? .other
    }

    enum CodingKeys: String, CodingKey {
        case id, latitude, longitude, score
        case name = "dba_name"
        case resultCode = "latest_result_code"
        case rawResult = "latest_result"
    }
}

/// A geographic rectangle for bounding-box queries.
struct BoundingBox: Sendable {
    let minLat: Double
    let maxLat: Double
    let minLon: Double
    let maxLon: Double

    /// True if `other` lies entirely within this box.
    func contains(_ other: BoundingBox) -> Bool {
        other.minLat >= minLat && other.maxLat <= maxLat
            && other.minLon >= minLon && other.maxLon <= maxLon
    }
}
