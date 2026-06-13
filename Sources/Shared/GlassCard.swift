import SwiftUI

extension View {
    /// Wrap content in the app's standard frosted-glass card.
    func glassCard(cornerRadius: CGFloat = 16) -> some View {
        self.padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
    }
}

/// A titled section: a small gray header above a glass card — the standard
/// grouping used on the About and Filter sheets.
struct GlassGroup<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            content.glassCard()
        }
    }
}
