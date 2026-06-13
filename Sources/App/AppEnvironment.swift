import Foundation

/// Composition root: builds the database, sync service, and repositories once
/// and hands them to the view tree.
@MainActor
final class AppEnvironment {
    let database: DatabaseManager
    let sync: SyncService
    let establishments: EstablishmentRepository
    let inspections: InspectionRepository
    let location = LocationManager()
    let filter = FilterModel()
    let translations: TranslationStore
    let languageManager: LanguageManager

    init(database: DatabaseManager, languageManager: LanguageManager) {
        self.languageManager = languageManager
        self.database = database
        self.sync = SyncService(db: database)
        self.establishments = EstablishmentRepository(reader: database.reader)
        self.inspections = InspectionRepository(reader: database.reader, writer: database.writer)
        self.translations = TranslationStore(
            repository: TranslationRepository(writer: database.writer))
    }

    /// Expand the bundled seed and open the database. `nonisolated` so it runs
    /// OFF the main thread — opening a freshly-written ~113 MB DB on the main
    /// actor stalled the launch ("stuck on preparing" until kill + relaunch).
    /// If the file is corrupt, wipe it (plus WAL/SHM), reinstall the seed, retry.
    nonisolated static func openDatabase() -> DatabaseManager {
        do {
            return try DatabaseManager(url: try DatabaseManager.defaultURL())
        } catch {
            guard let url = try? DatabaseManager.defaultURL() else {
                fatalError("Database location unavailable: \(error)")
            }
            // Attempt 2: wipe a corrupt DB and re-expand the bundled seed.
            wipe(url)
            _ = SeedInstaller.installIfNeeded(at: url)
            if let db = try? DatabaseManager(url: url) { return db }
            // Attempt 3: the bundled seed itself is unusable — start from an EMPTY
            // database (a 0-byte file makes SeedInstaller skip) so the app still
            // launches and downloads fresh data instead of crash-looping forever.
            wipe(url)
            FileManager.default.createFile(atPath: url.path, contents: nil)
            if let db = try? DatabaseManager(url: url) { return db }
            fatalError("Database unrecoverable: \(error)")
        }
    }

    private nonisolated static func wipe(_ url: URL) {
        for suffix in ["", "-wal", "-shm"] {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + suffix))
        }
    }

    /// Build the environment. The heavy work — seed decompression AND opening
    /// the database — happens entirely off the main thread; only the light
    /// store wiring runs on the main actor.
    static func make(languageManager: LanguageManager) async -> AppEnvironment {
        let database = await Task.detached(priority: .userInitiated) {
            openDatabase()
        }.value
        // Scores are precomputed in the bundled seed and kept current by the
        // importer on every sync, so there's no first-launch score backfill.
        return AppEnvironment(database: database, languageManager: languageManager)
    }
}
