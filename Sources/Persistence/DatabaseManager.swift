import Foundation
import GRDB

/// Owns the single `DatabasePool` for the app. The only type that touches the
/// database file; everyone else borrows `reader`/`writer`. `DatabasePool` runs
/// in WAL mode, so the map can keep reading the viewport while a sync writes.
final class DatabaseManager: Sendable {
    let pool: DatabasePool

    /// Read/write facades. `DatabasePool` is `Sendable`; query closures get a
    /// `Database` connection and run off the main thread.
    var reader: DatabaseReader { pool }
    var writer: DatabaseWriter { pool }

    init(url: URL) throws {
        // Expand the bundled seed on first launch (no-op if a DB already exists
        // or no seed is bundled), so the app is offline-ready immediately.
        SeedInstaller.installIfNeeded(at: url)

        var config = Configuration()
        config.prepareDatabase { db in
            // Enforce foreign keys (cascade delete of inspections).
            try db.execute(sql: "PRAGMA foreign_keys = ON")
        }
        pool = try DatabasePool(path: url.path, configuration: config)
        try Migrations.makeMigrator().migrate(pool)
    }

    /// Default on-disk location under Application Support.
    static func defaultURL() throws -> URL {
        let dir = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true)
        return dir.appendingPathComponent("chicago_food_safety.sqlite")
    }
}
