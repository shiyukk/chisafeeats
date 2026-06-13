import Foundation
import GRDB

/// One raw inspection event, keyed by the source's stable `inspection_id`.
/// Multiple events roll up to a single `EstablishmentRecord`.
struct InspectionRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    static let databaseTableName = "inspection"

    var inspectionId: String
    var establishmentId: String
    var inspectionDate: String      // ISO8601
    var inspectionType: String?
    var results: String?
    var resultsCode: Int?
    var risk: Int?
    var violationsRaw: String?

    enum CodingKeys: String, CodingKey {
        case inspectionId = "inspection_id"
        case establishmentId = "establishment_id"
        case inspectionDate = "inspection_date"
        case inspectionType = "inspection_type"
        case results
        case resultsCode = "results_code"
        case risk
        case violationsRaw = "violations_raw"
    }

    enum Columns {
        static let inspectionId = Column(CodingKeys.inspectionId)
        static let establishmentId = Column(CodingKeys.establishmentId)
        static let inspectionDate = Column(CodingKeys.inspectionDate)
    }
}
