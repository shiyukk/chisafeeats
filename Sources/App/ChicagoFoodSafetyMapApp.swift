import SwiftUI

@main
struct ChicagoFoodSafetyMapApp: App {
    var body: some Scene {
        WindowGroup { AppRootView() }
    }
}

/// Owns app-wide state and first-launch setup. State lives on a VIEW (not the
/// App struct) so `@State` + `.task` behave canonically — assigning
/// `appEnvironment` reliably re-renders the tree.
struct AppRootView: View {
    @State private var languageManager = LanguageManager()
    @State private var appEnvironment: AppEnvironment?

    var body: some View {
        content
            .environment(languageManager)
            .preferredColorScheme(languageManager.appearance.colorScheme)
            .task {
                guard appEnvironment == nil else { return }
                // make() does the heavy work (seed expand + DB open) off-main.
                let env = await AppEnvironment.make(languageManager: languageManager)
                appEnvironment = env            // on the main actor → re-renders
                await env.sync.bootstrapIfNeeded()   // incremental sync when seeded
            }
    }

    @ViewBuilder
    private var content: some View {
        // The map (or a "preparing" placeholder) is ALWAYS the base layer, keyed
        // only on appEnvironment. The first-launch language picker is a separate
        // full-screen overlay that simply disappears once a language is chosen —
        // so the base never has to re-render through a branch switch.
        mainContent
            .overlay {
                if !languageManager.languageChosen {
                    LanguageSelectionView { language in
                        languageManager.language = language
                        languageManager.languageChosen = true
                    }
                    .background(Color(.systemBackground))
                    .ignoresSafeArea()
                }
            }
    }

    @ViewBuilder
    private var mainContent: some View {
        if let appEnvironment {
            RootView(
                establishments: appEnvironment.establishments,
                inspections: appEnvironment.inspections,
                location: appEnvironment.location,
                filter: appEnvironment.filter,
                translations: appEnvironment.translations
            )
            .environment(appEnvironment.sync)
            .environment(\.locale, languageManager.locale)
            .id(languageManager.language)
        } else {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                VStack(spacing: 16) {
                    ProgressView()
                    Text(localized("loading.preparing"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
