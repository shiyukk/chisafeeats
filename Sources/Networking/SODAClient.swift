import Foundation

/// Async client for the Chicago Food Inspections dataset (Socrata SODA API).
struct SODAClient: Sendable {
    static let datasetURL = URL(string: "https://data.cityofchicago.org/resource/4ijn-s7e5.json")!

    var baseURL: URL = datasetURL
    var session: URLSession = .shared

    private static let decoder = JSONDecoder()

    /// A descriptive transport error (so rate-limits aren't an opaque failure).
    enum SODAError: LocalizedError {
        case http(Int)
        var errorDescription: String? {
            switch self {
            case .http(429): return "The city's data service is busy (rate limited). Please try again shortly."
            case .http(let code): return "The city's data service returned an error (\(code))."
            }
        }
    }

    /// Decodes one row leniently: a single malformed row becomes nil instead of
    /// throwing and discarding the whole 50k-row page.
    private struct LenientRow: Decodable {
        let value: InspectionDTO?
        init(from decoder: Decoder) throws { value = try? InspectionDTO(from: decoder) }
    }

    /// Fetch a page of inspection rows. Tolerant: skips individual bad rows.
    func fetch(_ query: SODAQuery) async throws -> [InspectionDTO] {
        let data = try await get(query, timeout: 60)
        return try Self.decoder.decode([LenientRow].self, from: data).compactMap(\.value)
    }

    /// Total row count in the dataset (uses SODA `count(*)`).
    func count() async throws -> Int {
        let data = try await get(SODAQuery(select: "count(*)"), timeout: 30)
        let rows = try Self.decoder.decode([CountRow].self, from: data)
        return rows.first.flatMap { Int($0.count ?? "") } ?? 0
    }

    private struct CountRow: Codable { var count: String? }

    /// GET with status checking + bounded backoff retry on rate-limit / 5xx (the
    /// count endpoint previously ignored HTTP status entirely).
    private func get(_ query: SODAQuery, timeout: TimeInterval, retries: Int = 2) async throws -> Data {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.queryItems = query.queryItems()
        guard let url = components.url else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout

        var attempt = 0
        while true {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return data }
            if (200..<300).contains(http.statusCode) { return data }
            if (http.statusCode == 429 || (500...599).contains(http.statusCode)), attempt < retries {
                let retryAfter = http.value(forHTTPHeaderField: "Retry-After").flatMap(Double.init)
                try await Task.sleep(for: .seconds(retryAfter ?? pow(2, Double(attempt))))
                attempt += 1
                continue
            }
            throw SODAError.http(http.statusCode)
        }
    }
}
