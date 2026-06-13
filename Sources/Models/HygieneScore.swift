import Foundation

/// A derived 0–100 hygiene score (the city issues pass/fail, not a number, so
/// this is our transparent rollup of the latest inspection). Higher is cleaner.
///   start at 100, subtract per-violation by severity, floor at 0.
///   a failing result is capped below 60.
enum HygieneScore {
    static func score(resultCode: Int, violations: [Violation]) -> Int? {
        let result = InspectionResult(rawValue: resultCode) ?? .other
        // No meaningful score for out-of-business / non-standard results.
        guard result != .outOfBusiness, result != .other else { return nil }

        // No violation detail (e.g. older inspections trimmed from the seed):
        // approximate from the result so conditions/fail aren't scored as perfect.
        if violations.isEmpty {
            switch result {
            case .pass: return 100
            case .passWithConditions: return 78
            case .fail: return 50
            default: return nil
            }
        }

        var penalty = 0
        for violation in violations {
            switch violation.severity {
            case .priority: penalty += 12
            case .priorityFoundation: penalty += 6
            case .core: penalty += 2
            case .other: penalty += 1
            }
        }
        var score = max(0, 100 - penalty)
        if result == .fail { score = min(score, 59) }
        return score
    }
}
