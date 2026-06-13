import Foundation

/// Free cloud translation for free-text violation comments — used in the
/// simulator (where Apple's on-device framework may lack language models).
/// Uses Google's keyless `translate_a` endpoint (generous limits).
struct CommentTranslator: Sendable {
    /// Translate a (possibly long) comment by splitting it into chunks under the
    /// API's length cap and joining the pieces.
    func translate(_ text: String, to langCode: String) async -> String? {
        var output = ""
        for chunk in Self.chunks(text, maxLength: 1000) {
            guard let translated = await translateChunk(chunk, to: langCode) else {
                return output.isEmpty ? nil : output   // partial is better than nothing
            }
            output += translated
        }
        return output.isEmpty ? nil : output
    }

    private func translateChunk(_ chunk: String, to langCode: String) async -> String? {
        var components = URLComponents(string: "https://translate.googleapis.com/translate_a/single")!
        components.queryItems = [
            URLQueryItem(name: "client", value: "gtx"),
            URLQueryItem(name: "sl", value: "en"),
            URLQueryItem(name: "tl", value: langCode),
            URLQueryItem(name: "dt", value: "t"),
            URLQueryItem(name: "q", value: chunk),
        ]
        guard let url = components.url,
              let (data, response) = try? await URLSession.shared.data(from: url),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [Any],
              let segments = json.first as? [Any]
        else { return nil }
        // segments = [ ["translated", "original", …], … ]; join the pieces.
        var output = ""
        for segment in segments {
            if let pair = segment as? [Any], let piece = pair.first as? String { output += piece }
        }
        let result = output.trimmingCharacters(in: .whitespaces)
        return result.isEmpty ? nil : result
    }

    /// Split text into chunks no longer than `maxLength`, breaking on spaces.
    static func chunks(_ text: String, maxLength: Int) -> [String] {
        if text.count <= maxLength { return [text] }
        var chunks: [String] = []
        var current = ""
        for word in text.split(separator: " ") {
            if current.count + word.count + 1 > maxLength {
                if !current.isEmpty { chunks.append(current); current = "" }
                if word.count > maxLength {
                    var rest = Substring(word)
                    while rest.count > maxLength {
                        chunks.append(String(rest.prefix(maxLength)))
                        rest = rest.dropFirst(maxLength)
                    }
                    current = String(rest)
                } else {
                    current = String(word)
                }
            } else {
                current += current.isEmpty ? String(word) : " " + word
            }
        }
        if !current.isEmpty { chunks.append(current) }
        return chunks
    }
}
