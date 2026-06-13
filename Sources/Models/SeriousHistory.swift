import Foundation

/// Serious, visceral findings a diner cares about that showed up in a PAST
/// inspection but not the most recent one — surfaced as a "曾发现…最近已无"
/// banner so a resolved-but-alarming issue (rats, dumped food, sewage) isn't
/// hidden by a clean latest checkup.
enum SeriousHistory {
    struct Flag: Identifiable {
        let kind: Kind
        let year: String
        var id: String { kind.rawValue }
        var symbol: String { kind.symbol }
        var text: String { localized("serious.everFound", year, kind.phrase) }
    }

    enum Kind: String, CaseIterable {
        case pests, discardedFood, sewage

        var symbol: String {
            switch self {
            case .pests: "ant.fill"
            case .discardedFood: "trash.fill"
            case .sewage: "drop.fill"
            }
        }
        var phrase: String {
            switch self {
            case .pests: localized("serious.pests")
            case .discardedFood: localized("serious.discarded")
            case .sewage: localized("serious.sewage")
            }
        }

        /// Match only genuinely serious wording — an actual sighting — not
        /// preventive notes like "seal the gap to prevent the entry of pests" or
        /// "prevent rodent attraction", which must NOT trip the pest flag.
        func matches(_ comment: String) -> Bool {
            switch self {
            case .pests:
                // Words that signal pests actually present (not just prevention).
                // "knat" covers inspectors' common misspelling of "gnat".
                let strong = ["pest activity", "rodent activity", "roach activity",
                              "insect activity", "droppings", "gnaw", "infestation",
                              "carcass", "feces", "roach", "cockroach", "gnat", "knat",
                              "maggot", "larvae", "vermin", "mouse nest", "mice nest"]
                return strong.contains { Self.wordMatch($0, in: comment) }
            case .discardedFood:
                return ["discard", "condemn", "destroyed"].contains { comment.contains($0) }
            case .sewage:
                return ["sewage", "sewer back", "sewage back", "waste water back"]
                    .contains { comment.contains($0) }
            }
        }

        /// Match `key` at a word boundary so "gnat" doesn't fire on "designated",
        /// "roach" on "approach", etc.
        private static func wordMatch(_ key: String, in text: String) -> Bool {
            let pattern = "\\b" + NSRegularExpression.escapedPattern(for: key)
            return text.range(of: pattern, options: .regularExpression) != nil
        }
    }

    /// Compute flags from full history (newest first). A flag fires when a kind
    /// appears in a past inspection within the last `recentYears` years but NOT
    /// in the most recent one — old issues are too stale to alarm a diner.
    static func flags(history: [(date: String, resultCode: Int?, violations: [Violation])],
                      now: Date = Date(), recentYears: Int = 5) -> [Flag] {
        // "Resolved" is judged against the latest ACTUAL inspection — a later
        // "No Entry" / closed visit must not clear a still-open serious issue (#5).
        guard let latest = history.first(where: {
            InspectionResult(rawValue: $0.resultCode ?? -1)?.isScored == true
        }) ?? history.first else { return [] }
        let cutoffYear = Calendar.current.component(.year, from: now) - recentYears
        let latestKinds = kinds(in: latest.violations)
        var flags: [Flag] = []
        for kind in Kind.allCases where !latestKinds.contains(kind) {
            if let past = history.first(where: {
                $0.date < latest.date && kinds(in: $0.violations).contains(kind)
                    && (Int($0.date.prefix(4)) ?? 0) >= cutoffYear
            }) {
                flags.append(Flag(kind: kind, year: String(past.date.prefix(4))))
            }
        }
        return flags
    }

    private static func kinds(in violations: [Violation]) -> Set<Kind> {
        var found: Set<Kind> = []
        for violation in violations {
            guard let comment = violation.comment?.lowercased() else { continue }
            for kind in Kind.allCases where kind.matches(comment) { found.insert(kind) }
        }
        return found
    }
}
