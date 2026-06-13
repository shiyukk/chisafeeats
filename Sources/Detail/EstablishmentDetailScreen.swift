import SwiftUI
@preconcurrency import Translation

/// Detail for one establishment: header with latest result, then the full
/// inspection history. Each inspection expands to its parsed violations.
struct EstablishmentDetailScreen: View {
    let establishmentID: String
    let establishments: EstablishmentRepository
    let inspections: InspectionRepository
    @Environment(TranslationStore.self) private var translationStore

    @State private var establishment: EstablishmentRecord?
    @State private var siblings: [EstablishmentRecord] = []
    @State private var history: [InspectionRecord] = []
    @State private var loaded = false
    @State private var translationConfig: TranslationSession.Configuration?
    /// Set when a health-card finding is tapped, so its inspection row expands.
    @State private var jumpTarget: String?
    /// Scroll id for the whole history card (used as the first hop when jumping).
    private static let historyAnchor = "history-card"

    /// A venue often holds several licenses (restaurant + bakery + liquor…),
    /// each its own record with its own inspection history. We merge them and
    /// tag each inspection with the license it belongs to.
    /// Merging several licenses can record the SAME real-world inspection twice
    /// (e.g. one opening-day visit logged under each license number). Drop only
    /// byte-identical duplicates — same date + type + result AND the same
    /// violations — so every genuinely distinct inspection in a year is kept.
    static func dedupedHistory(_ items: [InspectionRecord]) -> [InspectionRecord] {
        var seen = Set<String>()
        var out: [InspectionRecord] = []
        for item in items {
            let key = [String(item.inspectionDate.prefix(10)),
                       item.inspectionType ?? "",
                       item.resultsCode.map(String.init) ?? item.results ?? "",
                       item.violationsRaw ?? ""].joined(separator: "\u{1}")
            if seen.insert(key).inserted { out.append(item) }
        }
        return out.sorted { $0.inspectionDate > $1.inspectionDate }
    }


    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(spacing: 14) {
            if let establishment {
                let parsedHistory = history.map {
                    (id: $0.inspectionId,
                     date: String($0.inspectionDate.prefix(10)),
                     resultCode: $0.resultsCode,
                     violations: Violation.parse($0.violationsRaw, date: $0.inspectionDate))
                }
                // The "current" health check reflects the most recent ACTUAL
                // inspection (pass/conditions/fail), never a "No Entry" / closed
                // visit that carries no findings (#5).
                let latestActual = parsedHistory.first {
                    InspectionResult(rawValue: $0.resultCode ?? -1)?.isScored == true
                }
                // Custom header (nav bar is hidden): centered, multi-line title
                // hugging the grabber, type · aka below, with a back button in
                // the corner when pushed.
                ZStack(alignment: .top) {
                    VStack(spacing: 4) {
                        Text(establishment.dbaName)
                            .font(.title2.weight(.bold))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.6)
                            .frame(maxWidth: .infinity)
                        if let subtitle = headerSubtitle(establishment) {
                            Text(subtitle)
                                .font(.subheadline).foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 44)
                    .padding(.top, 10)   // small gap below the sheet's grabber
                }
                .padding(.bottom, 2)

                // History alert moves into the verdict card.
                let seriousFlags = SeriousHistory.flags(
                    history: parsedHistory.map { (date: $0.date, resultCode: $0.resultCode, violations: $0.violations) })
                VerdictCard(establishment: establishment, latest: history.first,
                            translations: translationStore.map, seriousFlags: seriousFlags)

                // 卫生体检 (current) + 曾经发现 (history) in one card. Each finding
                // links to its inspection in the history list below.
                let latestViolations = latestActual?.violations ?? []
                let pastFindings = HistorySummary.findings(history: parsedHistory,
                                                           translations: translationStore.map)
                if !latestViolations.isEmpty || !pastFindings.isEmpty {
                    HealthCheckCard(violations: latestViolations,
                                    translations: translationStore.map,
                                    pastFindings: pastFindings,
                                    latestDate: latestActual?.date,
                                    onSelectFinding: { finding in
                                        // Jump to the exact inspection that carried
                                        // this finding (not just the year's latest).
                                        jumpTarget = finding.inspectionId
                                        // The whole detail is an eager ScrollView, so
                                        // every inspection is laid out — scrollTo lands
                                        // precisely on the target (which also expands).
                                        Task { @MainActor in
                                            try? await Task.sleep(for: .milliseconds(60))
                                            withAnimation { proxy.scrollTo(finding.inspectionId, anchor: .top) }
                                            // Clear so tapping the same finding again
                                            // re-triggers the expand/scroll.
                                            try? await Task.sleep(for: .milliseconds(600))
                                            jumpTarget = nil
                                        }
                                    })
                }
            }
            if loaded && history.isEmpty {
                Text(localized("detail.noHistory"))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if !history.isEmpty {
                // One card for the whole history — title inside the card and
                // rows separated by dividers, matching the other cards.
                VStack(alignment: .leading, spacing: 10) {
                    Text(localized("detail.history.count", history.count))
                        .font(.headline)
                    VStack(spacing: 0) {
                        ForEach(Array(history.enumerated()), id: \.element.inspectionId) { index, inspection in
                            if index > 0 { Divider() }
                            InspectionRow(inspection: inspection, initiallyExpanded: index == 0,
                                          translations: translationStore.map,
                                          expandID: jumpTarget)
                                .padding(.vertical, 10)
                                .id(inspection.inspectionId)
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
                .id(Self.historyAnchor)
            }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            guard let tapped = try? await establishments.establishment(id: establishmentID) else {
                loaded = true; return
            }
            let group = (try? await establishments.siblings(of: tapped)) ?? [tapped]
            siblings = group
            // Header reflects the most recent inspection across all licenses.
            establishment = group.max { ($0.latestInspectionDate ?? "") < ($1.latestInspectionDate ?? "") } ?? tapped
            var merged = (try? await inspections.history(establishmentIDs: group.map(\.id))) ?? []
            history = Self.dedupedHistory(merged)
            loaded = true

            // The seed trims violation text from old (<2023) inspections; fetch it
            // on demand so their detail isn't blank ("无违规记录").
            let toBackfill = merged
                .filter { $0.inspectionDate < "2023-01-01" && ($0.violationsRaw?.isEmpty ?? true) }
                .map(\.inspectionId)
            if !toBackfill.isEmpty {
                let fetched = await inspections.backfillViolations(forInspectionIDs: toBackfill)
                if !fetched.isEmpty {
                    merged = merged.map { record in
                        guard let violations = fetched[record.inspectionId] else { return record }
                        var updated = record
                        updated.violationsRaw = violations
                        return updated
                    }
                    history = Self.dedupedHistory(merged)
                }
            }
            // Translate comments into the chosen language (English shows the
            // original — no translation needed).
            let lang = currentAppLanguage()
            translationStore.prepare(for: lang)
            if let translatorCode = lang.translatorCode {
                // Newest inspection's comments first, so the verdict / health card
                // translate immediately; older history fills in progressively.
                let ordered = Self.orderedComments(history)
                await translationStore.loadCached(Set(ordered))
                #if targetEnvironment(simulator)
                // Apple's on-device models aren't always present in the simulator;
                // use the free cloud translator there (concurrent, updates live).
                await translationStore.fetchRemote(ordered.filter { translationStore.map[$0] == nil },
                                                   translatorCode: translatorCode)
                #else
                // Production: Apple's on-device translation (free, offline).
                translationConfig = TranslationSession.Configuration(
                    source: Locale.Language(identifier: "en"),
                    target: Locale.Language(identifier: lang.code))
                #endif
            }
        }
        .translationTask(translationConfig) { session in
            // Record each as it resolves (newest first) so translations appear
            // progressively instead of all at once after the whole batch.
            for comment in Self.orderedComments(history) where translationStore.map[comment] == nil {
                if let response = try? await session.translate(comment) {
                    await translationStore.record([comment: response.targetText])
                }
            }
        }
    }

    /// Unique violation comments across the history, newest inspection first, so
    /// translation work is prioritized toward what the user sees first.
    private static func orderedComments(_ history: [InspectionRecord]) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for record in history {
            for violation in Violation.parse(record.violationsRaw, date: record.inspectionDate) {
                if let comment = violation.comment, seen.insert(comment).inserted {
                    ordered.append(comment)
                }
            }
        }
        return ordered
    }

    /// "类型 · 又名 XXX" under the venue name — only the parts that exist.
    private func headerSubtitle(_ e: EstablishmentRecord) -> String? {
        var parts: [String] = []
        if let type = e.facilityType, !type.isEmpty { parts.append(FoodCodeZH.facility(type)) }
        if let aka = e.akaName, aka != e.dbaName { parts.append(localized("detail.akaInline", aka)) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
