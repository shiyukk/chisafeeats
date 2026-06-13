import Foundation
import GRDB

/// Async query facade over the establishment table. Viewport, search, and
/// nearby queries all accept a shared `FilterCriteria`.
struct EstablishmentRepository: Sendable {
    let reader: DatabaseReader

    /// Keep food/dining places only — exclude non-food institutions (schools,
    /// daycares, children's services, long-term care, hospitals, shelters,
    /// churches), matched by keyword to catch spelling/case variants.
    private static let excludeNonFood = """
         AND (facility_type IS NULL OR (
            instr(lower(facility_type), 'school') = 0
            AND instr(lower(facility_type), 'daycare') = 0
            AND instr(lower(facility_type), 'children') = 0
            AND instr(lower(facility_type), 'long term care') = 0
            AND instr(lower(facility_type), 'hospital') = 0
            AND instr(lower(facility_type), 'shelter') = 0
            AND instr(lower(facility_type), 'church') = 0
         ))
        """

    /// The food-only scoping applies ONLY to the default view. When the user
    /// explicitly selects a facility category (which may BE a school/daycare/
    /// hospital), drop it so those chips can actually return results.
    private static func nonFoodClause(_ filter: FilterCriteria) -> String {
        filter.facilityTypes.isEmpty ? excludeNonFood : ""
    }

    /// Most recently inspected establishments (fallback list when no location).
    func recent(limit: Int = 200) async throws -> [EstablishmentRecord] {
        try await reader.read { db in
            try EstablishmentRecord
                .order(EstablishmentRecord.Columns.latestInspectionDate.desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    /// Up to `limit` pins inside the viewport (a render cap, not a data cap):
    /// at city-wide zoom MapKit clusters these; ordering by risk keeps the most
    /// concerning places when capped.
    func pins(in box: BoundingBox, filter: FilterCriteria = FilterCriteria(),
              limit: Int = 1_500) async throws -> [MapPin] {
        // One row already == one venue (licenses are merged at import), so no
        // GROUP BY is needed — dropping it removes a temp B-tree per viewport
        // query. ORDER BY sample_key takes a spatially-uniform capped sample.
        var sql = """
            SELECT id, latitude, longitude, dba_name, latest_result_code, latest_result, score,
                   latest_inspection_date AS latest
            FROM establishment
            WHERE latitude BETWEEN ? AND ? AND longitude BETWEEN ? AND ? AND latitude IS NOT NULL
            """ + Self.nonFoodClause(filter)
        var args: [DatabaseValueConvertibleBox] = [
            .double(box.minLat), .double(box.maxLat), .double(box.minLon), .double(box.maxLon),
        ]
        appendFilter(filter, to: &sql, args: &args)
        sql += " ORDER BY sample_key LIMIT ?"
        args.append(.int(limit))
        let finalSQL = sql, finalArgs = args
        return try await reader.read { db in
            try MapPin.fetchAll(db, sql: finalSQL, arguments: Self.statementArguments(finalArgs))
        }
    }

    /// Full establishment record by id (for the detail screen header).
    func establishment(id: String) async throws -> EstablishmentRecord? {
        try await reader.read { try EstablishmentRecord.fetchOne($0, key: id) }
    }

    /// All license records at the same name+address (a venue often holds several
    /// licenses). Includes the given establishment itself.
    func siblings(of e: EstablishmentRecord) async throws -> [EstablishmentRecord] {
        let name = e.dbaName.lowercased().trimmingCharacters(in: .whitespaces)
        let address = (e.address ?? "").lowercased().trimmingCharacters(in: .whitespaces)
        let zip = e.zip ?? ""
        return try await reader.read { db in
            try EstablishmentRecord.fetchAll(db, sql: """
                SELECT * FROM establishment
                WHERE lower(trim(dba_name)) = ?
                  AND lower(trim(COALESCE(address, ''))) = ?
                  AND COALESCE(zip, '') = ?
                """, arguments: [name, address, zip])
        }
    }

    /// Name/address text search. Caller sorts by distance when a location exists.
    func search(matching query: String, filter: FilterCriteria = FilterCriteria(),
                limit: Int = 100) async throws -> [EstablishmentRecord] {
        let like = "%\(query.trimmingCharacters(in: .whitespaces))%"
        // Search finds anything by name (incl. schools/hospitals) — no food-only
        // scoping here; an explicit facility chip still narrows via appendFilter.
        var sql = "SELECT * FROM establishment WHERE (dba_name LIKE ? OR aka_name LIKE ? OR address LIKE ?)"
        var args: [DatabaseValueConvertibleBox] = [.text(like), .text(like), .text(like)]
        appendFilter(filter, to: &sql, args: &args)
        sql += " ORDER BY latest_inspection_date DESC LIMIT ?"
        args.append(.int(limit))
        return try await fetch(sql, args)
    }

    /// Nearest establishments to a coordinate. Box-filters (index-friendly) then
    /// orders by approximate squared distance — longitude weighted by cos²(lat).
    func nearby(latitude: Double, longitude: Double, filter: FilterCriteria = FilterCriteria(),
                boxDegrees: Double = 0.06, limit: Int = 100) async throws -> [EstablishmentRecord] {
        let lonWeight = pow(cos(latitude * .pi / 180), 2)
        var sql = """
            SELECT * FROM establishment
            WHERE latitude BETWEEN ? AND ? AND longitude BETWEEN ? AND ? AND latitude IS NOT NULL
            """ + Self.nonFoodClause(filter)
        var args: [DatabaseValueConvertibleBox] = [
            .double(latitude - boxDegrees), .double(latitude + boxDegrees),
            .double(longitude - boxDegrees), .double(longitude + boxDegrees),
        ]
        appendFilter(filter, to: &sql, args: &args)
        sql += " ORDER BY (latitude - ?)*(latitude - ?) + (longitude - ?)*(longitude - ?) * ? LIMIT ?"
        args += [.double(latitude), .double(latitude), .double(longitude), .double(longitude),
                 .double(lonWeight), .int(limit)]
        return try await fetch(sql, args)
    }

    // MARK: - Helpers

    private func fetch(_ sql: String, _ args: [DatabaseValueConvertibleBox]) async throws -> [EstablishmentRecord] {
        try await reader.read { db in
            try EstablishmentRecord.fetchAll(db, sql: sql, arguments: Self.statementArguments(args))
        }
    }

    private func appendFilter(_ filter: FilterCriteria, to sql: inout String,
                              args: inout [DatabaseValueConvertibleBox]) {
        let (conditions, boxes) = filter.sqlConditions()
        guard !conditions.isEmpty else { return }
        sql += " AND " + conditions
        args += boxes
    }

    private static func statementArguments(_ boxes: [DatabaseValueConvertibleBox]) -> StatementArguments {
        StatementArguments(boxes.map { box -> any DatabaseValueConvertible in
            switch box {
            case .int(let i): i
            case .double(let d): d
            case .text(let t): t
            }
        })
    }
}
