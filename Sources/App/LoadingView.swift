import SwiftUI

/// Minimal progress shown only as a fallback when there's genuinely no data yet
/// (bundled seed missing → downloading). No brand splash — the app opens to the
/// language picker / map directly.
struct LoadingView: View {
    let note: String
    let fraction: Double
    let count: Int

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text(count > 0 ? localized("loading.count", note, count) : note)
                .font(.caption).foregroundStyle(.secondary)
                .contentTransition(.numericText())
            if fraction > 0 {
                ProgressView(value: fraction)
                    .tint(.accentColor)
                    .padding(.horizontal, 60)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
