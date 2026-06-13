import SwiftUI

/// One historical inspection. Expands to show parsed violations.
struct InspectionRow: View {
    let inspection: InspectionRecord
    var translations: [String: String] = [:]
    /// When this matches the row's inspection id (e.g. set by a jump from the
    /// health card), the row expands so the relevant violations are visible.
    var expandID: String?
    @State private var expanded: Bool

    init(inspection: InspectionRecord, initiallyExpanded: Bool = false,
         translations: [String: String] = [:], expandID: String? = nil) {
        self.inspection = inspection
        self.translations = translations
        self.expandID = expandID
        _expanded = State(initialValue: initiallyExpanded)
    }

    private var result: InspectionResult {
        InspectionResult(rawValue: inspection.resultsCode ?? InspectionResult.other.rawValue) ?? .other
    }
    private var violations: [Violation] { Violation.parse(inspection.violationsRaw, date: inspection.inspectionDate) }

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            if violations.isEmpty {
                Text(localized("detail.noViolations")).font(.caption).foregroundStyle(.secondary)
            } else {
                ViolationList(violations: violations, translations: translations)
                    .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
            }
            if inspection.violationsRaw?.isEmpty == false {
                // Push (not a nested sheet — that dismissed the detail) into the
                // detail's own navigation stack.
                NavigationLink {
                    RawReportView(text: inspection.violationsRaw ?? "",
                                  date: InspectionDate.display(inspection.inspectionDate))
                } label: {
                    Label(localized("detail.viewReport"), systemImage: "doc.plaintext")
                        .font(.caption)
                }
                .padding(.top, 4)
                .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
            }
        } label: {
            HStack(spacing: 10) {
                Circle().fill(result.color).frame(width: 10, height: 10)
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.displayLabel(raw: inspection.results))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(result.textColor)
                    HStack(spacing: 6) {
                        Text(InspectionDate.display(inspection.inspectionDate))
                        if let relative = InspectionDate.relative(from: inspection.inspectionDate) {
                            Text("·"); Text(relative)
                        }
                        if let type = inspection.inspectionType {
                            Text("·"); Text(FoodCodeZH.inspectionType(type) ?? type)
                        }
                    }
                    .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if !violations.isEmpty {
                    Text(localized("detail.violationCount", violations.count))
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .onChange(of: expandID) { _, target in
            if target == inspection.inspectionId { withAnimation(.snappy) { expanded = true } }
        }
    }
}

/// Full, unprocessed inspection report text, pushed as its own screen — the same
/// English verbatim, just split into one readable block per citation.
struct RawReportView: View {
    let text: String
    let date: String

    private struct Entry: Identifiable {
        let id = UUID()
        let head: String        // "29. COMPLIANCE WITH VARIANCE/…"
        let comment: String?    // text after "- Comments:"
    }

    private var entries: [Entry] {
        text.components(separatedBy: " | ").compactMap { raw in
            let entry = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !entry.isEmpty else { return nil }
            if let range = entry.range(of: "- Comments:") {
                let head = String(entry[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                let comment = String(entry[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                return Entry(head: head, comment: comment.isEmpty ? nil : comment)
            }
            return Entry(head: entry, comment: nil)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if entries.isEmpty {
                    Text(text).font(.callout)
                        .textSelection(.enabled)
                        .glassCard()
                } else {
                    ForEach(entries) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.head)
                                .font(.callout.weight(.semibold))
                                .fixedSize(horizontal: false, vertical: true)
                            if let comment = entry.comment {
                                Text(ProblemText.sentenceCased(comment))
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .textSelection(.enabled)
                        .glassCard()
                    }
                }
            }
            .padding(16)
        }
        .scrollContentBackground(.hidden)
        .navigationTitle(localized("report.title", date))
        .navigationBarTitleDisplayMode(.inline)
    }
}
