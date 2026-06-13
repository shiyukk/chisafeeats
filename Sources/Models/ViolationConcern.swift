import SwiftUI

/// A diner-facing "red flag" distilled from an inspection's violations — the
/// scary stuff (pests, rodents, temperature abuse…) surfaced as a quick chip so
/// it isn't buried in a list of citations.
struct ViolationConcern: Identifiable, Hashable {
    let id: String
    let symbol: String
    let label: String
    let isHigh: Bool
    var color: Color { isHigh ? .red : .orange }
}

/// A row of concern chips (wrapping), with an optional title.
struct ConcernChips: View {
    let concerns: [ViolationConcern]
    var title: String?

    var body: some View {
        if !concerns.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                if let title {
                    Text(title).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                }
                FlowLayout(spacing: 6) {
                    ForEach(concerns) { concern in
                        HStack(spacing: 4) {
                            Image(systemName: concern.symbol).font(.caption2)
                            Text(concern.label).font(.caption.weight(.semibold))
                        }
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(concern.color.opacity(0.18), in: Capsule())
                        .foregroundStyle(concern.color)
                    }
                }
            }
        }
    }
}

// Chips wrap using the shared `FlowLayout` (defined in FilterSheet.swift).
