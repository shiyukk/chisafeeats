import Foundation

/// Parsing helpers for the dataset's ISO8601 dates (e.g. "2026-06-04T00:00:00.000").
enum InspectionDate {
    // The dataset's dates carry no timezone (e.g. "2026-06-03T00:00:00.000"),
    // which ISO8601DateFormatter rejects. Parse the date portion directly.
    private static let parser: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "America/Chicago")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func date(from string: String?) -> Date? {
        guard let string else { return nil }
        return parser.date(from: String(string.prefix(10)))
    }

    /// Locale-formatted date for display, e.g. "May 10, 2023" / "2023年5月10日",
    /// in the app's chosen language (falls back to the raw ISO prefix).
    static func display(_ string: String?) -> String {
        guard let date = date(from: string) else { return String((string ?? "").prefix(10)) }
        return date.formatted(.dateTime.year().month().day()
            .locale(Locale(identifier: currentAppLanguage().code)))
    }

    /// Whole days between the inspection date and now (nil if unparseable).
    static func daysAgo(from string: String?, now: Date = .now) -> Int? {
        guard let date = date(from: string) else { return nil }
        return Calendar.current.dateComponents([.day], from: date, to: now).day
    }

    /// Human-friendly recency, e.g. "今天 / 3 天前 / 2 个月前 / 1 年前".
    static func relative(from string: String?, now: Date = .now) -> String? {
        guard let days = daysAgo(from: string, now: now) else { return nil }
        switch days {
        case ..<0: return localized("time.recent")
        case 0: return localized("time.today")
        case 1...30: return localized("time.daysAgo", days)
        case 31...364: return localized("time.monthsAgo", days / 30)
        default: return localized("time.yearsAgo", days / 365)
        }
    }
}
