import Foundation

/// Health-risk category the city assigns to an establishment.
/// Stored as the raw integer (1/2/3); `nil` when unknown.
enum RiskLevel: Int, CaseIterable, Sendable {
    case high = 1
    case medium = 2
    case low = 3

    /// Parse from the SODA `risk` string, e.g. "Risk 1 (High)".
    init?(raw: String?) {
        guard let raw, let first = raw.first(where: \.isNumber),
              let value = Int(String(first)), let level = RiskLevel(rawValue: value)
        else { return nil }
        self = level
    }

    var label: String {
        switch self {
        case .high: localized("risk.high")
        case .medium: localized("risk.medium")
        case .low: localized("risk.low")
        }
    }
}
