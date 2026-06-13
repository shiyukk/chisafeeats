import Foundation
import GRDB

/// Async query facade for inspection history of a single establishment.
struct InspectionRepository: Sendable {
    let reader: DatabaseReader
    var writer: DatabaseWriter
    var client = SODAClient()

    /// Merged history across several license records (siblings), newest first.
    func history(establishmentIDs ids: [String]) async throws -> [InspectionRecord] {
        guard !ids.isEmpty else { return [] }
        return try await reader.read { db in
            let placeholders = databaseQuestionMarks(count: ids.count)
            return try InspectionRecord.fetchAll(db, sql: """
                SELECT * FROM inspection WHERE establishment_id IN (\(placeholders))
                ORDER BY inspection_date DESC
                """, arguments: StatementArguments(ids))
        }
    }

    /// The bundled seed trims violation text from old (<2023) inspections to stay
    /// small. Fetch it on demand from the live API for the given inspection ids
    /// and cache it back into the database. Returns id → violation text.
    func backfillViolations(forInspectionIDs ids: [String]) async -> [String: String] {
        guard !ids.isEmpty else { return [:] }
        let quoted = ids.map { "'\($0)'" }.joined(separator: ",")
        let query = SODAQuery(select: "inspection_id,violations",
                              whereClause: "inspection_id in (\(quoted))", limit: ids.count)
        guard let rows = try? await client.fetch(query) else { return [:] }
        var built: [String: String] = [:]
        for row in rows where !(row.violations ?? "").isEmpty {
            built[row.inspectionId] = row.violations
        }
        let fetched = built
        guard !fetched.isEmpty else { return [:] }
        try? await writer.write { db in
            for (id, violations) in fetched {
                try db.execute(sql: "UPDATE inspection SET violations_raw = ? WHERE inspection_id = ?",
                               arguments: [violations, id])
            }
        }
        return fetched
    }
}
