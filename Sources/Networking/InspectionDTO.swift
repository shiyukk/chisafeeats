import Foundation

/// Codable mirror of one raw row from the Chicago Food Inspections SODA API.
/// Decoding is tolerant: most fields are optional and `latitude`/`longitude`
/// arrive as strings (and are sometimes absent).
struct InspectionDTO: Codable, Sendable {
    var inspectionId: String
    var dbaName: String?
    var akaName: String?
    var license: String?
    var facilityType: String?
    var risk: String?
    var address: String?
    var city: String?
    var state: String?
    var zip: String?
    var inspectionDate: String?
    var inspectionType: String?
    var results: String?
    var latitude: String?
    var longitude: String?
    var violations: String?

    enum CodingKeys: String, CodingKey {
        case inspectionId = "inspection_id"
        case dbaName = "dba_name"
        case akaName = "aka_name"
        case license = "license_"
        case facilityType = "facility_type"
        case risk
        case address
        case city
        case state
        case zip
        case inspectionDate = "inspection_date"
        case inspectionType = "inspection_type"
        case results
        case latitude
        case longitude
        case violations
    }
}
