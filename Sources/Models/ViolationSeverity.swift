import SwiftUI

/// Severity tier of a Chicago food-code violation, derived from its checklist
/// number (post-July-2018 FDA-aligned checklist, items 1–63):
///   1–29  Priority            — direct foodborne-illness risk
///   30–44 Priority Foundation — supports a priority item
///   45–63 Core                — facility / maintenance, no immediate hazard
enum ViolationSeverity: Int, Comparable, Sendable {
    case priority = 0
    case priorityFoundation = 1
    case core = 2
    case other = 3

    /// `legacy` selects the pre-July-2018 Chicago numbering (1–14 critical /
    /// 15–29 serious / 30–44 minor) instead of the post-2018 FDA checklist.
    init(number: Int?, legacy: Bool = false) {
        switch (legacy, number) {
        case (true, .some(1...14)):  self = .priority
        case (true, .some(15...29)): self = .priorityFoundation
        case (true, .some(30...44)): self = .core
        case (false, .some(1...29)):  self = .priority
        case (false, .some(30...44)): self = .priorityFoundation
        case (false, .some(45...63)): self = .core
        default: self = .other
        }
    }

    var color: Color {
        switch self {
        case .priority: .red
        case .priorityFoundation: .orange
        case .core: .gray
        case .other: .secondary
        }
    }

    static func < (lhs: ViolationSeverity, rhs: ViolationSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
