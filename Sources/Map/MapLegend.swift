import SwiftUI

/// Compact, collapsible color legend for the map.
struct MapLegend: View {
    @State private var expanded = true

    private struct Item: Identifiable {
        let id = UUID()
        let color: Color
        let text: String
    }

    private var items: [Item] {
        [
            .init(color: InspectionResult.pass.color, text: InspectionResult.pass.label),
            .init(color: InspectionResult.passWithConditions.color,
                  text: InspectionResult.passWithConditions.label),
            .init(color: InspectionResult.fail.color, text: InspectionResult.fail.label),
            .init(color: RatingStyle.noScore, text: localized("legend.unchecked")),
        ]
    }

    var body: some View {
        if expanded { expandedPanel } else { collapsedButton }
    }

    private var expandedPanel: some View {
        VStack(alignment: .leading, spacing: 9) {
            // Header doubles as the collapse control.
            Button { withAnimation(.snappy) { expanded = false } } label: {
                Text(localized("legend.title")).font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(.plain)

            ForEach(items) { item in
                HStack(spacing: 8) {
                    Circle().fill(item.color)
                        .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 1))
                        .frame(width: 12, height: 12)
                    Text(item.text).font(.system(size: 13)).lineLimit(1).fixedSize()
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 13)
        .foregroundStyle(.primary)
        // Hug the widest label (so "有条件通过" / other languages fit); the
        // Divider collapses to that width instead of stretching the panel.
        .fixedSize(horizontal: true, vertical: false)
        // Capsule-family soft corners, matching the search box / panels.
        .glassEffect(.regular.interactive(),
                     in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var collapsedButton: some View {
        // Collapsed: a round glass button, matching the filter / locate buttons.
        Button { withAnimation(.snappy) { expanded = true } } label: {
            Image(systemName: "circle.hexagongrid.fill")
                .font(.title3)
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Circle())
    }
}
