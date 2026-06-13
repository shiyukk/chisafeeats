import Foundation

/// Builds a Socrata SODA query URL from `$`-prefixed parameters.
/// See https://dev.socrata.com/docs/queries/
struct SODAQuery {
    var select: String?
    var whereClause: String?
    var order: String?
    var limit: Int?
    var offset: Int?

    func queryItems() -> [URLQueryItem] {
        var items: [URLQueryItem] = []
        if let select { items.append(.init(name: "$select", value: select)) }
        if let whereClause { items.append(.init(name: "$where", value: whereClause)) }
        if let order { items.append(.init(name: "$order", value: order)) }
        if let limit { items.append(.init(name: "$limit", value: String(limit))) }
        if let offset { items.append(.init(name: "$offset", value: String(offset))) }
        return items
    }
}
