import Foundation

/// One problem found in a PAST inspection, for the health-check history: the
/// specific finding, the year, and that inspection's result (so a failed year
/// can be flagged in red). Shown once per (issue, year) so EVERY year's record
/// surfaces — a fail is never masked by a later passing inspection.
struct PastFinding: Identifiable {
    let number: Int
    let category: HealthCategory
    let problem: String
    let year: String
    let resultCode: Int?
    /// The inspection this finding came from, so tapping jumps to exactly that
    /// inspection (not just the year's most recent one).
    let inspectionId: String
    /// True when this issue is no longer present in the latest inspection
    /// (i.e. it has since been fixed → shown as 已整改).
    let resolved: Bool
    var id: String { "\(number)|\(year)" }
}

enum HistorySummary {
    /// Every distinct (issue, year) across the WHOLE history. Within a year the
    /// worst-result occurrence of an issue wins, so a fail isn't hidden behind a
    /// same-year re-inspection. Issues are NOT collapsed across years, so a fail
    /// from any year always appears (tagged with that year's result).
    static func findings(history: [(id: String, date: String, resultCode: Int?, violations: [Violation])],
                         translations: [String: String] = [:]) -> [PastFinding] {
        // "Current" findings belong to the most recent ACTUAL inspection
        // (pass/conditions/fail). A later "No Entry" / closed visit carries no
        // findings and must NOT mark everything resolved (#5).
        let scored = history.filter { InspectionResult(rawValue: $0.resultCode ?? -1)?.isScored == true }
        let latestDate = scored.map(\.date).max() ?? ""
        let latestYear = String(latestDate.prefix(4))
        let latestNumbers = Set(scored.filter { $0.date == latestDate }
            .flatMap { $0.violations.compactMap(\.num) })
        var byKey: [String: PastFinding] = [:]
        for entry in history {
            let year = String(entry.date.prefix(4))
            for violation in entry.violations {
                guard let number = violation.num else { continue }
                let problem = ProblemText.specific(violation, translations: translations)
                    ?? (violation.isLegacy ? nil : FoodCodeZH.violationMeaning(number: number))
                    ?? violation.localizedTitle
                guard !problem.isEmpty else { continue }
                let key = "\(number)|\(year)"
                let candidate = PastFinding(number: number,
                                            category: violation.category,
                                            problem: problem, year: year,
                                            resultCode: entry.resultCode,
                                            inspectionId: entry.id,
                                            resolved: !(latestNumbers.contains(number) && year == latestYear))
                if let existing = byKey[key] {
                    if resultRank(entry.resultCode) > resultRank(existing.resultCode) {
                        byKey[key] = candidate
                    }
                } else {
                    byKey[key] = candidate
                }
            }
        }
        return Array(byKey.values)
    }

    /// Severity of an inspection result for "keep the worst in a year": a failed
    /// inspection outranks conditions, which outranks a pass.
    private static func resultRank(_ code: Int?) -> Int {
        switch InspectionResult(rawValue: code ?? InspectionResult.other.rawValue) ?? .other {
        case .fail: return 3
        case .passWithConditions: return 2
        case .pass: return 1
        default: return 0
        }
    }
}
