import SwiftUI

/// The settings menu — appearance + display language. A system Menu (no popover
/// arrow; opens from the button). Each group is a submenu so the menu stays
/// short. `.menuOrder(.fixed)` keeps the order when it opens upward.
struct SettingsMenu<Trigger: View>: View {
    @ViewBuilder var label: Trigger
    @Environment(LanguageManager.self) private var languageManager

    var body: some View {
        Menu {
            Menu {
                ForEach(AppearanceMode.allCases) { mode in
                    Button { languageManager.appearance = mode } label: {
                        checkmarkLabel(localized(mode.nameKey),
                                       selected: languageManager.appearance == mode)
                    }
                }
            } label: {
                Label(localized("appearance.title"), systemImage: "circle.lefthalf.filled")
            }
            .menuOrder(.fixed)

            Menu {
                ForEach(AppLanguage.allCases) { language in
                    Button { languageManager.language = language } label: {
                        checkmarkLabel(language.nativeName,
                                       selected: languageManager.language == language)
                    }
                }
            } label: {
                Label(localized("language.title"), systemImage: "globe")
            }
            .menuOrder(.fixed)
        } label: {
            label
        }
        .menuOrder(.fixed)
    }

    @ViewBuilder
    private func checkmarkLabel(_ title: String, selected: Bool) -> some View {
        if selected {
            Label(title, systemImage: "checkmark")
        } else {
            Text(title)
        }
    }
}
