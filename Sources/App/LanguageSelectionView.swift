import SwiftUI

/// First-launch screen: pick a display language before entering the map.
/// Intentionally bilingual (中文 / English) since no language is chosen yet;
/// the option rows themselves show each language's own native name.
struct LanguageSelectionView: View {
    let onSelect: (AppLanguage) -> Void

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 32)

            Image(systemName: "globe")
                .font(.system(size: 46, weight: .regular))
                .foregroundStyle(.tint)

            // Title follows the system language (the app defaults to the system
            // language until the user picks one here).
            Text(localized("language.choose")).font(.title2.weight(.bold))

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(AppLanguage.allCases) { language in
                        Button { onSelect(language) } label: {
                            HStack {
                                Text(language.nativeName).font(.body.weight(.medium))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.footnote).foregroundStyle(.secondary)
                            }
                            .glassCard()
                            .contentShape(Rectangle())   // whole card is tappable
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
