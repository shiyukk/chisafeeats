import SwiftUI

/// A "health checkup" card. Each diner-relevant category shows its current
/// status and, right beneath it, that same category's past findings (year +
/// fixed/still-present) — so current state and history line up one-to-one.
struct HealthCheckCard: View {
    let violations: [Violation]
    var translations: [String: String] = [:]
    var pastFindings: [PastFinding] = []
    var latestDate: String?
    /// Tapping a finding jumps to that year's inspection in the history list.
    var onSelectFinding: (PastFinding) -> Void = { _ in }
    /// Categories whose fixed/historical findings the user has expanded.
    @State private var expanded: Set<HealthCategory> = []

    private var findings: [HealthFinding] {
        HealthCheck.findings(for: violations)
    }
    private var pastByCategory: [HealthCategory: [PastFinding]] {
        Dictionary(grouping: pastFindings, by: \.category).mapValues { items in
            items.sorted { $0.year != $1.year ? $0.year > $1.year : $0.number < $1.number }
        }
    }

    /// Only categories that actually have something to show (a current problem
    /// or any past finding), ordered so the most recently affected category —
    /// e.g. the one from a recent failed inspection — comes first. Empty
    /// "all clear" categories are hidden so real findings aren't buried.
    private var visibleFindings: [HealthFinding] {
        let past = pastByCategory
        let order = Dictionary(uniqueKeysWithValues:
            HealthCategory.allCases.enumerated().map { ($1, $0) })
        return findings
            .filter { $0.status != .ok || !(past[$0.category]?.isEmpty ?? true) }
            .sorted { a, b in
                let ya = past[a.category]?.first?.year ?? "9999"
                let yb = past[b.category]?.first?.year ?? "9999"
                if ya != yb { return ya > yb }
                return (order[a.category] ?? 0) < (order[b.category] ?? 0)
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(localized("health.title")).font(.headline)
                Spacer()
                if let latestDate {
                    Text(localized("health.lastCheck", latestDate))
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 0) {
                ForEach(Array(visibleFindings.enumerated()), id: \.element.id) { index, finding in
                    if index > 0 { Divider() }
                    categoryBlock(finding)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
    }

    private func categoryBlock(_ finding: HealthFinding) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Image(systemName: finding.category.symbol)
                    .font(.system(size: 15))
                    .foregroundStyle(finding.status.color)
                    .frame(width: 26, height: 26)
                    .background(finding.status.color.opacity(0.16),
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text(finding.category.title).font(.subheadline.weight(.medium))
                Spacer(minLength: 8)
                statusBadge(finding.status)
            }

            // Current issues (from the latest inspection) always show; the
            // fixed/历史 entries are collapsed behind a toggle so a long history
            // doesn't bury what matters now.
            let all = pastByCategory[finding.category] ?? []
            let fixedCount = all.filter(\.resolved).count
            let isExpanded = expanded.contains(finding.category)
            let shown = isExpanded ? all : all.filter { !$0.resolved }
            ForEach(shown) { item in
                Button { onSelectFinding(item) } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(item.problem)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 8)
                        // Fixed-width trailing block: the inspection year, colored
                        // by that year's result so a failed year reads red (with a
                        // ✕), conditions amber, a clean year green.
                        yearTag(item)
                        .font(.caption2.weight(.semibold))
                        // Size to content (never truncate) so it stays readable
                        // at large Dynamic Type sizes.
                        .fixedSize()
                        Image(systemName: "chevron.right")
                            .font(.caption2).foregroundStyle(.tertiary)
                    }
                    .padding(.leading, 38)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            if fixedCount > 0 && !isExpanded {
                Button {
                    withAnimation(.snappy) { _ = expanded.insert(finding.category) }
                } label: {
                    Text(localized("health.showFixed", fixedCount))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.green)
                        .padding(.leading, 38).padding(.top, 2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
    }

    /// Trailing tag for a past finding: "已整改" when the issue is no longer in
    /// the latest inspection, plus the year. Colored by that year's result —
    /// red for a failed year, amber for a current issue, green when fixed.
    @ViewBuilder
    private func yearTag(_ item: PastFinding) -> some View {
        let result = InspectionResult(rawValue: item.resultCode ?? InspectionResult.other.rawValue) ?? .other
        let color: Color = result == .fail ? .red : (item.resolved ? .green : .orange)
        HStack(spacing: 3) {
            if item.resolved { Text(localized("history.fixed") + " ·") }
            Text(item.year)
        }
        .foregroundStyle(color)
    }

    private func statusBadge(_ status: HealthStatus) -> some View {
        HStack(spacing: 3) {
            Image(systemName: status == .ok ? "checkmark.circle.fill"
                            : status == .caution ? "exclamationmark.circle.fill"
                            : "xmark.octagon.fill")
                .font(.caption2)
            Text(status.label).font(.caption.weight(.semibold))
        }
        .foregroundStyle(status == .ok ? Color.secondary : status.color)
    }
}
