import Foundation
import GRDB

/// A deduplicated food establishment — the unit the map pins represent.
/// Carries a denormalized snapshot of its most recent inspection so the map
/// can color pins without joining the `inspection` table.
struct EstablishmentRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "establishment"

    var id: String                  // dedup key: "L:<license>" or "A:<hash>"
    var license: String?
    var dbaName: String
    var akaName: String?
    var facilityType: String?
    var risk: Int?                  // 1/2/3
    var address: String?
    var city: String?
    var state: String?
    var zip: String?
    var latitude: Double?
    var longitude: Double?
    // Denormalized "latest inspection" snapshot:
    var latestResult: String?
    var latestResultCode: Int?
    var latestInspectionDate: String?   // ISO8601
    var latestInspectionId: String?     // tie-breaks same-day events
    var isOutOfBusiness: Bool
    var score: Int?

    enum CodingKeys: String, CodingKey {
        case id, license
        case dbaName = "dba_name"
        case akaName = "aka_name"
        case facilityType = "facility_type"
        case risk, address, city, state, zip, latitude, longitude
        case latestResult = "latest_result"
        case latestResultCode = "latest_result_code"
        case latestInspectionDate = "latest_inspection_date"
        case latestInspectionId = "latest_inspection_id"
        case isOutOfBusiness = "is_out_of_business"
        case score
    }

    enum Columns {
        static let id = Column(CodingKeys.id)
        static let latitude = Column(CodingKeys.latitude)
        static let longitude = Column(CodingKeys.longitude)
        static let risk = Column(CodingKeys.risk)
        static let latestResultCode = Column(CodingKeys.latestResultCode)
        static let latestInspectionDate = Column(CodingKeys.latestInspectionDate)
        static let isOutOfBusiness = Column(CodingKeys.isOutOfBusiness)
    }
}
