import Foundation
import Observation

/// Shared cache + driver for violation-comment translations. Reads the local
/// cache first, then fetches missing ones from the cloud translator (capped per
/// call to respect the free API's limits) and persists them.
@Observable
@MainActor
final class TranslationStore {
    private(set) var map: [String: String] = [:]
    /// Target language the current `map` holds translations for.
    private var lang: String = "zh-Hans"

    private let repository: TranslationRepository
    private let translator = CommentTranslator()
    private let networkCapPerCall = 40

    init(repository: TranslationRepository) {
        self.repository = repository
    }

    /// Switch the cache to a target language, clearing stale-language entries.
    func prepare(for language: AppLanguage) {
        guard language.code != lang else { return }
        lang = language.code
        map.removeAll()
    }

    /// Comments still missing a translation.
    func pending(_ comments: Set<String>) -> [String] { comments.filter { map[$0] == nil } }

    /// Load any translations already cached locally for the current language.
    func loadCached(_ comments: Set<String>) async {
        await resetCacheIfOutdated()
        guard let cached = try? await repository.cached(Array(comments), lang: lang) else { return }
        for (source, target) in cached { map[source] = target }
    }

    /// Clear translations cached by older (pre-chunking) builds so they get
    /// re-translated in full.
    private func resetCacheIfOutdated() async {
        let key = "translationCacheVersion"
        let current = 2
        guard UserDefaults.standard.integer(forKey: key) < current else { return }
        try? await repository.clearAll()
        map.removeAll()
        UserDefaults.standard.set(current, forKey: key)
    }

    /// Fetch missing translations from the cloud API (simulator / Apple
    /// framework unavailable). Translated concurrently (bounded) so a long list
    /// of comments resolves in a few seconds rather than trickling in one by one.
    func fetchRemote(_ comments: [String], translatorCode: String) async {
        let batch = Array(comments.prefix(networkCapPerCall))
        guard !batch.isEmpty else { return }
        let translator = self.translator
        let maxConcurrent = 8
        var next = 0
        await withTaskGroup(of: (String, String?).self) { group in
            func addTask() {
                guard next < batch.count else { return }
                let comment = batch[next]; next += 1
                group.addTask { (comment, await translator.translate(comment, to: translatorCode)) }
            }
            for _ in 0..<min(maxConcurrent, batch.count) { addTask() }
            for await (comment, target) in group {
                if let target {
                    map[comment] = target
                    persist(source: comment, target: target)
                }
                addTask()
            }
        }
    }

    /// Persist translations produced elsewhere (e.g. Apple's on-device session).
    func record(_ results: [String: String]) {
        for (source, target) in results {
            map[source] = target
            persist(source: source, target: target)
        }
    }

    /// Write to the cache in a DETACHED task so it survives the detail screen's
    /// `.task` being cancelled when the sheet is dismissed — otherwise the GRDB
    /// write throws CancellationError and nothing is cached, so re-opening
    /// re-translates the same comments.
    private func persist(source: String, target: String) {
        let (repo, lang) = (repository, self.lang)
        Task.detached { try? await repo.store(source: source, target: target, lang: lang) }
    }
}
