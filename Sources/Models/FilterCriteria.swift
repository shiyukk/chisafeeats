import Foundation

/// Filter predicate shared by the map and the nearby/search list. Empty sets
/// mean "no constraint". `Sendable` so it can cross into DB read closures.
struct FilterCriteria: Sendable, Equatable {
    var results: Set<Int> = []          // latest_result_code values
    var risks: Set<Int> = []            // 1/2/3
    var facilityTypes: Set<String> = [] // selected facility CATEGORY keys (see below)
    var hideOutOfBusiness: Bool = true

    /// A facility category shown as one filter chip. `key` resolves to the
    /// `facility.<key>` label; `patterns` are lowercased substrings matched
    /// against the (inconsistent) raw `facility_type` — so one chip catches all
    /// variants (e.g. the several "Daycare …" / "Mobile …" spellings).
    struct FacilityCategory: Hashable, Identifiable, Sendable {
        let key: String
        let patterns: [String]
        var id: String { key }
    }

    /// Ordered roughly by how common the category is in Chicago.
    static let facilityCategories: [FacilityCategory] = [
        .init(key: "restaurant", patterns: ["restaurant", "golden diner"]),
        .init(key: "grocery", patterns: ["grocery"]),
        .init(key: "school", patterns: ["school"]),
        .init(key: "daycare", patterns: ["daycare", "children"]),
        .init(key: "bakery", patterns: ["bakery"]),
        .init(key: "liquor", patterns: ["liquor"]),
        .init(key: "tavern", patterns: ["tavern"]),
        .init(key: "mobile", patterns: ["mobile"]),
        .init(key: "catering", patterns: ["catering"]),
        .init(key: "longTermCare", patterns: ["long term care", "nursing"]),
        .init(key: "wholesale", patterns: ["wholesale"]),
        .init(key: "hospital", patterns: ["hospital"]),
        .init(key: "coffee", patterns: ["coffee", "cafe"]),
        .init(key: "gasStation", patterns: ["gas station"]),
        .init(key: "convenience", patterns: ["convenience"]),
        .init(key: "sharedKitchen", patterns: ["shared kitchen"]),
    ]

    var isActive: Bool {
        !results.isEmpty || !risks.isEmpty || !facilityTypes.isEmpty || !hideOutOfBusiness
    }

    /// SQL fragment (without leading AND) and its arguments, or nil if no filter.
    func sqlConditions() -> (sql: String, arguments: [DatabaseValueConvertibleBox]) {
        var clauses: [String] = []
        var args: [DatabaseValueConvertibleBox] = []

        if !results.isEmpty {
            clauses.append("latest_result_code IN (\(placeholders(results.count)))")
            args += results.sorted().map { .int($0) }
        }
        if !risks.isEmpty {
            clauses.append("risk IN (\(placeholders(risks.count)))")
            args += risks.sorted().map { .int($0) }
        }
        if !facilityTypes.isEmpty {
            // Expand each selected category to its LIKE patterns; a place matches
            // if its facility_type contains ANY selected category's pattern.
            let patterns = Self.facilityCategories
                .filter { facilityTypes.contains($0.key) }
                .flatMap(\.patterns)
            if !patterns.isEmpty {
                let likes = patterns.map { _ in "instr(lower(facility_type), ?) > 0" }
                clauses.append("(\(likes.joined(separator: " OR ")))")
                args += patterns.map { .text($0) }
            }
        }
        if hideOutOfBusiness {
            clauses.append("is_out_of_business = 0")
        }
        return (clauses.joined(separator: " AND "), args)
    }

    private func placeholders(_ n: Int) -> String {
        Array(repeating: "?", count: n).joined(separator: ", ")
    }
}

/// Tiny boxed value so FilterCriteria stays free of a GRDB import, and so query
/// arguments can be carried as a `Sendable` array into a DB read closure.
enum DatabaseValueConvertibleBox: Sendable {
    case int(Int)
    case double(Double)
    case text(String)
}
