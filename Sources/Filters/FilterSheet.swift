import SwiftUI

/// Filter editor presented from the map and nearby screens.
struct FilterSheet: View {
    @Bindable var model: FilterModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Custom header: capsule Reset / centered title / capsule Done.
            ZStack {
                Text(localized("filter.title"))
                    .font(.title3.weight(.semibold))
                HStack {
                    Button(localized("filter.reset")) { model.criteria = FilterCriteria() }
                        .disabled(!model.criteria.isActive)
                        .buttonStyle(.plain)
                        .padding(.horizontal, 18).padding(.vertical, 10)
                        .glassEffect(.regular.interactive(), in: Capsule())
                    Spacer()
                    Button(localized("common.done")) { dismiss() }
                        .fontWeight(.semibold)
                        .buttonStyle(.plain)
                        .padding(.horizontal, 18).padding(.vertical, 10)
                        .glassEffect(.regular.interactive(), in: Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 6)

            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    section(localized("filter.results")) {
                        // "Out of Business" is driven by the dedicated hide-closed
                        // toggle below — offering it here too would contradict it.
                        chips(InspectionResult.allCases.filter { $0 != .other && $0 != .outOfBusiness },
                              isOn: { model.criteria.results.contains($0.rawValue) },
                              label: { $0.label }, color: { $0.color },
                              toggle: { toggle(&model.criteria.results, $0.rawValue) })
                    }
                    section(localized("filter.risk")) {
                        chips(RiskLevel.allCases,
                              isOn: { model.criteria.risks.contains($0.rawValue) },
                              label: { $0.label }, color: { _ in .accentColor },
                              toggle: { toggle(&model.criteria.risks, $0.rawValue) })
                    }
                    section(localized("filter.facility")) {
                        chips(FilterCriteria.facilityCategories,
                              isOn: { model.criteria.facilityTypes.contains($0.key) },
                              label: { localized("facility.\($0.key)") }, color: { _ in .accentColor },
                              toggle: { toggle(&model.criteria.facilityTypes, $0.key) })
                    }
                    Toggle(localized("filter.hideClosed"), isOn: $model.criteria.hideOutOfBusiness)
                        .padding(.top, 2)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(.ultraThinMaterial)
    }

    /// A titled section: a roomy header above its content, with NO background
    /// card — chips sit directly on the translucent sheet.
    private func section<Content: View>(_ title: String,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.title3.weight(.medium))
                .foregroundStyle(.primary.opacity(0.75))
                .padding(.leading, 2)
            content()
        }
    }

    /// A wrapping row of toggle chips.
    private func chips<Item: Hashable>(
        _ items: [Item],
        isOn: @escaping (Item) -> Bool,
        label: @escaping (Item) -> String,
        color: @escaping (Item) -> Color,
        toggle: @escaping (Item) -> Void
    ) -> some View {
        FlowLayout(spacing: 10) {
            ForEach(items, id: \.self) { item in
                let on = isOn(item)
                Button { toggle(item) } label: {
                    Text(label(item))
                        .font(.body)
                        .padding(.horizontal, 16).padding(.vertical, 9)
                        .background(on ? color(item).opacity(0.16) : Color(.secondarySystemFill),
                                    in: Capsule())
                        .foregroundStyle(on ? color(item) : .primary)
                        .overlay(Capsule().stroke(on ? color(item) : .clear, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func toggle<T: Hashable>(_ set: inout Set<T>, _ value: T) {
        if set.contains(value) { set.remove(value) } else { set.insert(value) }
    }
}

/// Minimal wrapping layout for chips (iOS 16+ Layout).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[LayoutSubview]] = [[]]
        var x: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, !rows[rows.count - 1].isEmpty {
                rows.append([]); x = 0
            }
            rows[rows.count - 1].append(view); x += size.width + spacing
        }
        var height: CGFloat = 0
        for row in rows {
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            height += rowHeight + spacing
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: max(0, height - spacing))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX; y += rowHeight + spacing; rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
