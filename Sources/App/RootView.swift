import SwiftUI

/// App root: runs first-launch bootstrap/seed install, then shows the main
/// tabs. Built around the "diner on-site quick check" flow — map + nearby/search.
struct RootView: View {
    let establishments: EstablishmentRepository
    let inspections: InspectionRepository
    let location: LocationManager
    let filter: FilterModel
    let translations: TranslationStore
    @Environment(SyncService.self) private var sync

    var body: some View {
        // Data bootstrap runs once at the App level (so a language switch, which
        // recreates this view via `.id`, never re-runs it).
        content
            .environment(translations)
    }

    @ViewBuilder
    private var content: some View {
        // The language picker is owned by the App; here we only show the map
        // (or a download fallback when there's genuinely no seed data yet).
        switch sync.state {
        case .failed(let message):
            // A sync failure only blocks the UI when there's genuinely no data.
            // With a seed (or partial download) present, show the map — the
            // failure was just a background refresh that couldn't complete.
            if sync.establishmentCount > 0 {
                map
            } else {
                ContentUnavailableView {
                    Label(localized("error.loadFailed"), systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                } actions: {
                    Button(localized("error.retry")) { Task { await sync.fullBootstrap() } }
                }
            }

        case .done:
            map

        case .idle, .syncing:
            // Seed data present → straight to the map; only show progress
            // when there's genuinely nothing yet (seed missing → downloading).
            if sync.establishmentCount > 0 {
                map
            } else {
                LoadingView(note: syncNote, fraction: progressValue, count: sync.establishmentCount)
            }
        }
    }

    private var map: some View {
        MapScreen(establishments: establishments, inspections: inspections,
                  location: location, filter: filter)
    }

    private var progressValue: Double {
        if case .syncing(let fraction, _) = sync.state { return fraction }
        return 0
    }

    private var syncNote: String {
        if case .syncing(_, let note) = sync.state { return note }
        return localized("loading.preparing")
    }
}
