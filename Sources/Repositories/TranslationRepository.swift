import Foundation
import GRDB

/// Persistent cache of violation-comment translations, so each comment is
/// translated once and is then available offline.
struct TranslationRepository: Sendable {
    let writer: DatabaseWriter

    func cached(_ sources: [String], lang: String) async throws -> [String: String] {
        guard !sources.isEmpty else { return [:] }
        return try await writer.read { db in
            var result: [String: String] = [:]
            for chunk in stride(from: 0, to: sources.count, by: 400).map({ Array(sources[$0..<min($0 + 400, sources.count)]) }) {
                let placeholders = databaseQuestionMarks(count: chunk.count)
                let rows = try Row.fetchAll(db,
                    sql: "SELECT source, target FROM comment_translation WHERE lang = ? AND source IN (\(placeholders))",
                    arguments: StatementArguments([lang] + chunk))
                for row in rows { result[row["source"]] = row["target"] }
            }
            return result
        }
    }

    func clearAll() async throws {
        try await writer.write { db in try db.execute(sql: "DELETE FROM comment_translation") }
    }

    func store(source: String, target: String, lang: String) async throws {
        try await writer.write { db in
            try db.execute(sql: "INSERT OR REPLACE INTO comment_translation (source, lang, target) VALUES (?, ?, ?)",
                           arguments: [source, lang, target])
        }
    }
}
