import Foundation

enum ProblemText {
    /// The specific problem actually found — the inspector's comment, translated
    /// when available and otherwise the original. Trimmed to the finding sentence
    /// (dropping the "instructed to…" remediation). The original inspector text
    /// is ALL CAPS, so it's sentence-cased; translations are left as-is.
    static func specific(_ violation: Violation, translations: [String: String]) -> String? {
        guard let comment = violation.comment,
              !comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let translated = translations[comment]
        let sentence = firstSentence(of: clean(translated ?? comment))
        guard !sentence.isEmpty else { return nil }
        return translated == nil ? sentenceCased(sentence) : sentence
    }

    /// Strip a leading municipal/FDA citation code that often prefixes a comment
    /// — e.g. "6-301.14", "3-302.11", "6-501.111", "7-38-020(A)".
    static func clean(_ text: String) -> String {
        let pattern = #"^\s*\d+-\d+(?:[-.]\d+)*(?:\([A-Za-z0-9]+\))?[\s.:]+"#
        if let r = text.range(of: pattern, options: .regularExpression) {
            return String(text[r.upperBound...]).trimmingCharacters(in: .whitespaces)
        }
        return text
    }

    /// The first sentence. Splits on CJK terminators / newline, and on ASCII
    /// `.!?` only when followed by whitespace/end — so decimals (75.7) and codes
    /// don't get cut mid-number.
    private static func firstSentence(of text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = #"[。！？\n]|[.!?](?=\s|$)"#
        if let r = trimmed.range(of: pattern, options: .regularExpression) {
            let s = String(trimmed[..<r.lowerBound]).trimmingCharacters(in: .whitespaces)
            if !s.isEmpty { return s }
        }
        return trimmed
    }

    /// Convert ALL-CAPS inspector text to sentence case: lowercase everything,
    /// capitalize sentence starts, and keep common acronyms / units (CDPH,
    /// HACCP, a temperature's F …) uppercase.
    static func sentenceCased(_ text: String) -> String {
        var chars = Array(text.lowercased())
        var capitalizeNext = true
        for i in chars.indices {
            let c = chars[i]
            if capitalizeNext, c.isLetter {
                chars[i] = Character(c.uppercased())
                capitalizeNext = false
            } else if c == "." || c == "!" || c == "?" || c == "\n" {
                capitalizeNext = true
            } else if !c.isWhitespace {
                capitalizeNext = false
            }
        }
        var result = String(chars)
        let acronyms = ["CDPH", "HACCP", "TCS", "FDA", "USDA", "DPH", "CFPM", "PIC", "PPM"]
        for acronym in acronyms {
            result = result.replacingOccurrences(
                of: "\\b\(acronym)\\b", with: acronym,
                options: [.regularExpression, .caseInsensitive])
        }
        // Temperatures: "50 f" / "50f" → "50 F".
        result = result.replacingOccurrences(
            of: "(\\d)\\s*f\\b", with: "$1 F", options: .regularExpression)
        return result
    }
}
