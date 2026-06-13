import SwiftUI

/// The "is this place clean?" answer, front and center. Big colored verdict,
/// recency, violation count, risk, and a plain-language one-liner.
struct VerdictCard: View {
    let establishment: EstablishmentRecord
    /// The most recent inspection (history.first), for violation count + recency.
    let latest: InspectionRecord?
    var translations: [String: String] = [:]
    /// Serious issues seen in the past but not the latest check.
    var seriousFlags: [SeriousHistory.Flag] = []
    @Environment(\.openURL) private var openURL
    @State private var showScoreInfo = false

    private var result: InspectionResult {
        InspectionResult(rawValue: establishment.latestResultCode ?? InspectionResult.other.rawValue) ?? .other
    }
    private var violations: [Violation] {
        Violation.parse(latest?.violationsRaw, date: latest?.inspectionDate)
    }
    private var priorityCount: Int {
        violations.filter { $0.severity == .priority }.count
    }
    /// The latest inspection's issue categories (caution/problem), worst first,
    /// as chips — so the summary matches the checkup card below.
    private var latestConcerns: [ViolationConcern] {
        HealthCheck.findings(for: violations)
            .filter { $0.status != .ok }
            .sorted { $0.status > $1.status }
            .map { ViolationConcern(id: $0.category.id, symbol: $0.category.symbol,
                                    label: $0.category.title, isHigh: $0.status == .problem) }
    }
    private var recency: String? {
        InspectionDate.relative(from: establishment.latestInspectionDate)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: result.iconName)
                    .font(.system(size: 34))
                    .foregroundStyle(result.textColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.displayLabel(raw: establishment.latestResult))
                        .font(.title2.bold())
                        .foregroundStyle(result.textColor)
                    if let recency {
                        Text(localized("verdict.lastCheck", recency))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if result.isScored, let score = establishment.score {
                    Button { showScoreInfo = true } label: {
                        VStack(spacing: 0) {
                            Text("\(score)").font(.system(size: 30, weight: .heavy, design: .rounded))
                                .foregroundStyle(result.textColor)
                            HStack(spacing: 2) {
                                Text(localized("verdict.score"))
                                Image(systemName: "info.circle").font(.system(size: 9))
                            }
                            .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showScoreInfo) {
                        scoreInfo.presentationCompactAdaptation(.popover)
                    }
                }
            }

            // One dynamic line: count (+ critical) and what areas it touches.
            Text(summary)
                .font(.subheadline)
                .foregroundStyle(.primary)

            // The issue categories this visit (same source as the checkup card),
            // worst first — the "涉及" of the summary line.
            if !latestConcerns.isEmpty {
                ConcernChips(concerns: latestConcerns, title: nil)
            }

            // History alert: serious issues that were found before but not now.
            if !seriousFlags.isEmpty {
                Divider().overlay(result.color.opacity(0.25))
                VStack(alignment: .leading, spacing: 6) {
                    Label(localized("history.alert"), systemImage: "flag.fill")
                        .font(.caption.weight(.semibold)).foregroundStyle(.red)
                    ForEach(seriousFlags) { flag in
                        HStack(spacing: 8) {
                            Image(systemName: flag.symbol).font(.caption2).foregroundStyle(.red)
                            Text(flag.text).font(.caption)
                            Spacer(minLength: 4)
                            Text(localized("history.alertGone")).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if let address = establishment.address {
                let full = [address, establishment.city, establishment.zip]
                    .compactMap { $0 }.joined(separator: " ")
                Divider().overlay(result.color.opacity(0.25))
                Button { openInMaps(full) } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.and.ellipse").font(.caption)
                        Text(full).multilineTextAlignment(.leading)
                        Spacer(minLength: 4)
                        Image(systemName: "map").font(.caption)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.tint)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Tinted glass — same material family as the checkup/history cards, but
        // colored by the result so the verdict reads as the headline.
        .glassEffect(.regular.tint(result.color.opacity(0.18)),
                     in: RoundedRectangle(cornerRadius: 16))
    }

    /// Plain-language explanation of the derived hygiene score.
    private var scoreInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localized("score.explainTitle")).font(.headline)
            Text(localized("score.explainBody"))
                .font(.subheadline).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(width: 280)
    }

    private func openInMaps(_ address: String) {
        var components = URLComponents(string: "https://maps.apple.com/")!
        var items = [URLQueryItem(name: "q", value: establishment.dbaName)]
        if let lat = establishment.latitude, let lon = establishment.longitude {
            items.append(URLQueryItem(name: "ll", value: "\(lat),\(lon)"))
        } else {
            items.append(URLQueryItem(name: "address", value: address))
        }
        components.queryItems = items
        if let url = components.url { openURL(url) }
    }

/// One dynamic line summarizing the latest inspection: count, how many are
    /// critical, and (when there are findings) lead-in to the category chips.
    private var summary: String {
        if establishment.isOutOfBusiness { return localized("verdict.sentenceClosed") }
        if violations.isEmpty {
            // "No violations" only fits a pass; a fail/conditions with no detail
            // text means the data didn't include it (common for old records).
            return result == .pass ? localized("verdict.clean") : localized("verdict.noDetails")
        }
        if priorityCount > 0 {
            return localized("verdict.foundCritical", violations.count, priorityCount)
        }
        return localized("verdict.found", violations.count)
    }
}
