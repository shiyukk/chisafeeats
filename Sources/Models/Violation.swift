import Foundation

/// One parsed citation from an inspection's `violations` blob.
struct Violation: Identifiable, Sendable {
    let id = UUID()
    let number: String?
    let title: String
    let comment: String?
    /// Chicago renumbered the inspection checklist in July 2018, so the same
    /// number means different things before/after. `isLegacy` (the source
    /// inspection predates the cutoff) selects the right severity/category map.
    let isLegacy: Bool

    /// Cutoff for the post-July-2018 FDA-aligned checklist renumbering.
    static let renumberCutoff = "2018-07-01"

    var num: Int? { number.flatMap { Int($0) } }

    var severity: ViolationSeverity { ViolationSeverity(number: num, legacy: isLegacy) }

    var category: HealthCategory { HealthCategory.category(for: num, legacy: isLegacy) }

    /// Chinese title (in Chinese mode) when the violation number is a known
    /// *current* standard item; otherwise the original English food-code title.
    /// Legacy-numbered items fall back to English (the ZH map is post-2018 only).
    var localizedTitle: String {
        if !isLegacy, currentAppLanguage() == .zh, let zh = FoodCodeZH.violationTitle(number: num) {
            return zh
        }
        return title
    }

    /// Parse the pipe-separated `violations_raw` string. Each entry looks like:
    /// "18. SOME TITLE - Comments: detail text". Parts are best-effort. Pass the
    /// source inspection `date` so pre-2018 numbers resolve against the old map.
    static func parse(_ raw: String?, date: String? = nil) -> [Violation] {
        guard let raw, !raw.isEmpty else { return [] }
        let legacy = date.map { String($0.prefix(10)) < renumberCutoff } ?? false
        return raw.components(separatedBy: " | ").compactMap { entry in
            let entry = entry.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !entry.isEmpty else { return nil }

            var number: String?
            var body = entry
            // Leading "NN. " is the violation number.
            if let dot = entry.firstIndex(of: "."),
               entry[entry.startIndex..<dot].allSatisfy(\.isNumber) {
                number = String(entry[entry.startIndex..<dot])
                body = String(entry[entry.index(after: dot)...]).trimmingCharacters(in: .whitespaces)
            }

            // Split title from comments.
            var title = body
            var comment: String?
            if let range = body.range(of: "- Comments:") {
                title = String(body[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                comment = String(body[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            }
            return Violation(number: number,
                             title: title.isEmpty ? entry : title,
                             comment: comment?.isEmpty == true ? nil : comment,
                             isLegacy: legacy)
        }
    }
}
