import SwiftUI

/// Normalized inspection outcome. `code` is persisted (`results_code` /
/// `latest_result_code`) so the map can color pins and filter without parsing
/// the raw string at query time. Ordering matters: higher code = more concerning,
/// so a `LIMIT`-capped viewport query ordered by risk keeps the worst places.
enum InspectionResult: Int, CaseIterable, Sendable {
    case pass = 0
    case passWithConditions = 1
    case fail = 2
    case outOfBusiness = 3
    case other = 4

    /// Parse the raw `results` string from the SODA API.
    init(raw: String?) {
        switch (raw ?? "").trimmingCharacters(in: .whitespaces).lowercased() {
        case "pass": self = .pass
        case "pass w/ conditions": self = .passWithConditions
        case "fail": self = .fail
        case "out of business": self = .outOfBusiness
        default: self = .other
        }
    }

    var label: String {
        switch self {
        case .pass: localized("result.pass")
        case .passWithConditions: localized("result.conditions")
        case .fail: localized("result.fail")
        case .outOfBusiness: localized("result.closed")
        case .other: localized("result.other")
        }
    }

    /// Display label that translates the raw "other" result strings.
    func displayLabel(raw: String?) -> String {
        guard self == .other else { return label }
        switch (raw ?? "").trimmingCharacters(in: .whitespaces).lowercased() {
        case "no entry": return localized("result.noEntry")
        case "not ready": return localized("result.notReady")
        case "business not located": return localized("result.notLocated")
        // Empty or any unexpected value → the localized generic label, so no
        // raw English ever leaks through.
        default: return label
        }
    }

    /// Whether this result yields a hygiene score (an actual inspection outcome).
    /// "No Entry" / "Out of Business" etc. do not.
    var isScored: Bool {
        self == .pass || self == .passWithConditions || self == .fail
    }

    var iconName: String {
        switch self {
        case .pass: "checkmark.seal.fill"
        case .passWithConditions: "exclamationmark.triangle.fill"
        case .fail: "xmark.octagon.fill"
        case .outOfBusiness: "xmark.circle.fill"
        case .other: "questionmark.circle.fill"
        }
    }

    /// Pin / badge tint (map dots, where yellow reads well on the map).
    var color: Color {
        switch self {
        case .pass: .green
        case .passWithConditions: .yellow
        case .fail: .red
        case .outOfBusiness: .gray
        case .other: .blue
        }
    }

    /// Text tint — plain yellow is illegible on a white sheet, so "conditions"
    /// uses adaptive orange for TEXT while the map pin stays yellow.
    var textColor: Color {
        self == .passWithConditions ? .orange : color
    }
}
