import SwiftUI

/// Renders the parsed violations of a single inspection, most severe first,
/// each tagged with its severity tier so critical issues stand out.
struct ViolationList: View {
    let violations: [Violation]
    var translations: [String: String] = [:]

    private var sorted: [Violation] {
        violations.sorted { a, b in
            if a.severity != b.severity { return a.severity < b.severity }
            return (Int(a.number ?? "") ?? 999) < (Int(b.number ?? "") ?? 999)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(sorted) { violation in
                HStack(alignment: .top, spacing: 8) {
                    // Category topic icon (same set as the checkup card), tinted
                    // by severity.
                    Image(systemName: categoryIcon(violation))
                        .font(.footnote)
                        .foregroundStyle(violation.severity.color)
                        .frame(width: 20)
                    // The inspector's specific finding.
                    Text(detail(for: violation))
                        .font(.footnote)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func categoryIcon(_ violation: Violation) -> String {
        guard violation.num != nil else { return "checklist" }
        return violation.category.symbol
    }

    private func detail(for violation: Violation) -> String {
        if let comment = violation.comment {
            if let t = translations[comment] {
                // Chinese gets the legal-phrase polish; other languages as-is.
                let c = ProblemText.clean(t)
                return currentAppLanguage() == .zh ? FoodCodeZH.polishComment(c) : c
            }
            return ProblemText.sentenceCased(ProblemText.clean(comment))   // English original
        }
        // Fall back to the plain meaning only when there's no specific comment.
        return FoodCodeZH.violationMeaning(number: violation.number.flatMap { Int($0) })
            ?? violation.localizedTitle
    }
}
