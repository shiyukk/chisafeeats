import SwiftUI

/// A diner-facing "health checkup": every food-code violation rolled up into a
/// handful of categories people actually care about, each with a clear status —
/// so a diner sees at a glance what (if anything) was wrong.
enum HealthCategory: String, CaseIterable, Identifiable {
    case pests, temperature, hygiene, food, water, facility, management
    var id: String { rawValue }

    var title: String {
        switch self {
        case .pests: localized("cat.pests")
        case .temperature: localized("cat.temperature")
        case .hygiene: localized("cat.hygiene")
        case .food: localized("cat.food")
        case .water: localized("cat.water")
        case .facility: localized("cat.facility")
        case .management: localized("cat.management")
        }
    }

    var symbol: String {
        switch self {
        case .pests: "ant.fill"
        case .temperature: "thermometer.medium"
        case .hygiene: "hand.raised.fill"
        case .food: "fork.knife"
        case .water: "drop.fill"
        case .facility: "sparkles"
        case .management: "graduationcap.fill"
        }
    }

    /// Which category a checklist item belongs to. `legacy` picks the pre-July
    /// 2018 numbering (totally different from the current FDA checklist).
    static func category(for number: Int?, legacy: Bool = false) -> HealthCategory {
        guard let number else { return .management }
        if legacy { return legacyCategory(number) }
        switch number {       // post-July-2018 FDA checklist (1–63)
        case 38: return .pests
        case 12, 18, 19, 20, 21, 22, 33, 34, 35, 36: return .temperature
        case 6, 7, 8, 9, 10, 40, 46: return .hygiene
        case 11, 13, 14, 15, 16, 17, 23, 24, 25, 26, 27, 29, 30, 31, 32, 37, 39, 42: return .food
        case 50, 51, 52, 53, 54: return .water
        case 28, 41, 43, 44, 45, 47, 48, 49, 55, 56: return .facility
        default: return .management   // 1–5, 57–64
        }
    }

    /// Pre-July-2018 Chicago checklist (items 1–44 + 70), built from the city's
    /// old violation vocabulary — old #13/#18 are pests, old #38 is ventilation.
    private static func legacyCategory(_ number: Int) -> HealthCategory {
        switch number {
        case 13, 18: return .pests
        case 2, 3, 17, 40: return .temperature
        case 5, 6, 11, 12: return .hygiene
        case 4, 16, 25, 30, 42: return .food
        case 9, 10: return .water
        case 8, 19, 24, 26, 31, 32, 33, 34, 35, 36, 37, 38, 39, 41, 43: return .facility
        default: return .management   // 1, 7, 14, 15, 20, 21, 27, 28, 29, 44, 70…
        }
    }
}

enum HealthStatus: Int, Comparable {
    case ok = 0, caution = 1, problem = 2   // green / amber / red

    static func < (a: HealthStatus, b: HealthStatus) -> Bool { a.rawValue < b.rawValue }

    var color: Color {
        switch self {
        case .ok: .green
        case .caution: .orange
        case .problem: .red
        }
    }
    var label: String {
        switch self {
        case .ok: localized("status.ok")
        case .caution: localized("status.caution")
        case .problem: localized("status.problem")
        }
    }
}

/// One row of the checkup: a category and its current status.
struct HealthFinding: Identifiable {
    let category: HealthCategory
    let status: HealthStatus
    var id: String { category.rawValue }
}

enum HealthCheck {
    /// Evaluate an inspection's violations into one finding per category, in a
    /// fixed diner-priority order.
    static func findings(for violations: [Violation]) -> [HealthFinding] {
        var byCategory: [HealthCategory: [Violation]] = [:]
        for violation in violations where violation.num != nil {
            byCategory[violation.category, default: []].append(violation)
        }
        return HealthCategory.allCases.map { category in
            HealthFinding(category: category,
                          status: status(for: category, byCategory[category] ?? []))
        }
    }

    private static func status(for category: HealthCategory, _ group: [Violation]) -> HealthStatus {
        guard !group.isEmpty else { return .ok }
        // Pests: an actual sighting is a real problem; a preventive note (a gap to
        // seal) is only a caution, even though both are item #38.
        if category == .pests {
            return group.contains { actualPestSighting($0.comment) } ? .problem : .caution
        }
        let worst = group.map(\.severity).min() ?? .other
        return worst == .priority ? .problem : .caution
    }

    /// True if the comment describes pests actually present (vs. a preventive note
    /// like "seal the gap to prevent entry of pests").
    static func actualPestSighting(_ comment: String?) -> Bool {
        guard let text = comment?.lowercased() else { return false }
        let signs = ["roach", "cockroach", "rodent", "mouse", "mice", "droppings",
                     "gnaw", "fruit fly", "flies", "maggot", "infestation"]
        return signs.contains { text.range(of: "\\b\($0)", options: .regularExpression) != nil }
    }
}
