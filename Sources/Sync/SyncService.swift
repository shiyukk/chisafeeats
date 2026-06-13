import Foundation
import GRDB

/// Orchestrates data sync and exposes observable state to the UI.
///
/// Three paths:
///  - `fullBootstrap()`  — download the entire dataset (used to GENERATE the
///     bundled seed, and as a fallback if the seed is ever missing).
///  - `incrementalSync()` — fetch only events newer than `last_sync_date`.
///  - `bootstrapIfNeeded()` — pick the right one at launch.
@Observable
@MainActor
final class SyncService {
    enum State: Equatable, Sendable {
        case idle
        case syncing(fraction: Double, note: String)
        case done
        case failed(String)
    }

    private(set) var state: State = .idle
    private(set) var establishmentCount = 0

    private let db: DatabaseManager
    private let client: SODAClient

    /// SODA allows up to 50k rows/request, so the full ~311k dataset is ~7
    /// requests — few enough to avoid anonymous rate limits, no app token needed.
    private let pageSize = 50_000

    init(db: DatabaseManager, client: SODAClient = SODAClient()) {
        self.db = db
        self.client = client
    }

    /// At launch: if we already have data (from the bundled seed or a prior run),
    /// just refresh deltas; otherwise download everything.
    func bootstrapIfNeeded() async {
        establishmentCount = (try? await db.reader.read { try EstablishmentRecord.fetchCount($0) }) ?? 0
        // Gate on the sync ANCHOR, not the row count. A complete dataset (seed or
        // a finished download) has last_sync_date set → just freshen deltas. A
        // partial, interrupted download leaves rows but NO anchor (saved only on
        // completion) — re-run the idempotent full bootstrap instead of freezing
        // forever on partial data.
        let anchor = (try? await lastSyncDate()).flatMap { $0 }
        if anchor != nil {
            state = .done
            await incrementalSync()   // best-effort freshen
        } else {
            await fullBootstrap()
        }
    }

    // MARK: - Full bootstrap (all rows)

    func fullBootstrap() async {
        state = .syncing(fraction: 0, note: localized("loading.downloading"))
        do {
            let total = try await client.count()
            var offset = 0
            var maxDate: String?
            while true {
                let page = try await client.fetch(SODAQuery(
                    order: "inspection_date DESC, inspection_id DESC",
                    limit: pageSize,
                    offset: offset
                ))
                if page.isEmpty { break }

                let pageMax = try await db.writer.write { db in
                    try InspectionImporter.ingest(page, into: db)
                }
                if let pageMax, maxDate == nil || pageMax > maxDate! { maxDate = pageMax }

                offset += page.count
                establishmentCount = (try? await db.reader.read { try EstablishmentRecord.fetchCount($0) }) ?? establishmentCount
                state = .syncing(fraction: total > 0 ? min(1, Double(offset) / Double(total)) : 0,
                                 note: localized("loading.imported", offset, total))
                if page.count < pageSize { break }
            }

            if let maxDate { try await saveSyncDate(maxDate) }
            establishmentCount = try await db.reader.read { try EstablishmentRecord.fetchCount($0) }
            state = .done
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    // MARK: - Incremental delta sync

    func incrementalSync() async {
        guard let last = try? await lastSyncDate(), let last else { return }
        do {
            var offset = 0
            var maxDate: String? = last
            while true {
                let escaped = last.replacingOccurrences(of: "'", with: "''")
                let page = try await client.fetch(SODAQuery(
                    whereClause: "inspection_date >= '\(escaped)'",
                    order: "inspection_date DESC, inspection_id DESC",
                    limit: pageSize,
                    offset: offset
                ))
                if page.isEmpty { break }

                let pageMax = try await db.writer.write { db in
                    try InspectionImporter.ingest(page, into: db)
                }
                if let pageMax, pageMax > (maxDate ?? "") { maxDate = pageMax }

                offset += page.count
                if page.count < pageSize { break }
            }
            if let maxDate { try await saveSyncDate(maxDate) }
            establishmentCount = try await db.reader.read { try EstablishmentRecord.fetchCount($0) }
        } catch {
            // Offline or transient failure: keep showing cached data silently.
        }
    }

    // MARK: - sync_meta helpers

    private func lastSyncDate() async throws -> String?? {
        try await db.reader.read { db in
            try String.fetchOne(db, sql: "SELECT last_sync_date FROM sync_meta WHERE id = 1")
        }
    }

    private func saveSyncDate(_ date: String) async throws {
        try await db.writer.write { db in
            try db.execute(
                sql: "UPDATE sync_meta SET last_sync_date = ?, last_sync_at = ? WHERE id = 1",
                arguments: [date, ISO8601DateFormatter().string(from: .now)]
            )
        }
    }
}
