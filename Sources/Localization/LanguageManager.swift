import SwiftUI

/// The languages the app can display.
enum AppLanguage: String, CaseIterable, Identifiable {
    // Fully localized UI.
    case zh = "zh-Hans"
    case en = "en"
    case es = "es"
    case ja = "ja"
    case ko = "ko"
    // Added for US-wide reach. UI labels fall back to English for now; the
    // inspection content (comments) translates on-device via Apple Translation.
    case pl = "pl"
    case ru = "ru"
    case pt = "pt-BR"
    case fr = "fr"
    case uk = "uk"

    var id: String { rawValue }
    var code: String { rawValue }
    /// MyMemory translator language code (nil for English — comments are English).
    var translatorCode: String? {
        switch self {
        case .en: nil
        case .zh: "zh-CN"
        case .es: "es"
        case .ja: "ja"
        case .ko: "ko"
        case .pl: "pl"
        case .ru: "ru"
        case .pt: "pt"
        case .fr: "fr"
        case .uk: "uk"
        }
    }
    var nativeName: String {
        switch self {
        case .zh: "中文"
        case .en: "English"
        case .es: "Español"
        case .ja: "日本語"
        case .ko: "한국어"
        case .pl: "Polski"
        case .ru: "Русский"
        case .pt: "Português"
        case .fr: "Français"
        case .uk: "Українська"
        }
    }

    /// Best match for the device's preferred languages among the ones we ship —
    /// used as the default before the user has explicitly chosen one.
    static var systemDefault: AppLanguage {
        for preferred in Locale.preferredLanguages {
            let base = Locale(identifier: preferred).language.languageCode?.identifier ?? ""
            switch base {
            case "zh": return .zh          // we ship Simplified only
            case "pt": return .pt
            default:
                if let match = AppLanguage.allCases.first(where: { $0.code == base }) { return match }
            }
        }
        return .en
    }
}

/// Light / dark / follow-system appearance choice.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var nameKey: String {
        switch self {
        case .system: "appearance.system"
        case .light: "appearance.light"
        case .dark: "appearance.dark"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// Holds the chosen display language and appearance, persists them, and routes
/// string lookups to the matching `.lproj` so the UI switches without a restart.
@MainActor
@Observable
final class LanguageManager {
    private static let key = "appLanguage"

    var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: Self.key)
            Bundle.setAppLanguage(language.code)
        }
    }

    var appearance: AppearanceMode {
        didSet { UserDefaults.standard.set(appearance.rawValue, forKey: "appearance") }
    }

    /// Whether the user has picked a language on the first-launch screen. Until
    /// then we show the language picker instead of the map.
    var languageChosen: Bool {
        didSet { UserDefaults.standard.set(languageChosen, forKey: "languageChosen") }
    }

    init() {
        let saved = UserDefaults.standard.string(forKey: Self.key).flatMap(AppLanguage.init(rawValue:))
        language = saved ?? .systemDefault
        appearance = UserDefaults.standard.string(forKey: "appearance")
            .flatMap(AppearanceMode.init(rawValue:)) ?? .system
        languageChosen = UserDefaults.standard.bool(forKey: "languageChosen")
        Bundle.setAppLanguage((saved ?? .systemDefault).code)
    }

    var locale: Locale { Locale(identifier: language.code) }
}

// MARK: - Runtime language override (bundle re-class)

nonisolated(unsafe) private var languageBundleKey: UInt8 = 0

/// English `.lproj`, used as the fallback for languages that aren't fully
/// translated yet (so they show English, never raw keys).
private let englishBundle: Bundle? =
    Bundle.main.path(forResource: "en", ofType: "lproj").flatMap(Bundle.init(path:))

/// A `Bundle` subclass whose string lookups defer to a per-language bundle,
/// falling back to English for any key the chosen language is missing.
final class LanguageBundle: Bundle, @unchecked Sendable {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        let sentinel = "\u{1}\u{2}\u{3}"
        if let bundle = objc_getAssociatedObject(self, &languageBundleKey) as? Bundle {
            let result = bundle.localizedString(forKey: key, value: sentinel, table: tableName)
            if result != sentinel { return result }
        }
        if let english = englishBundle {
            return english.localizedString(forKey: key, value: value, table: tableName)
        }
        return super.localizedString(forKey: key, value: value, table: tableName)
    }
}

/// The currently selected app language (reads the persisted choice).
func currentAppLanguage() -> AppLanguage {
    UserDefaults.standard.string(forKey: "appLanguage").flatMap(AppLanguage.init(rawValue:)) ?? .systemDefault
}

/// Look up a UI string in the user's chosen language. Routes through
/// `NSLocalizedString` so the runtime bundle re-class applies.
func localized(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

/// Localized format string with arguments, e.g. `localized("health.needAttention", count)`.
func localized(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: NSLocalizedString(key, comment: ""), arguments: arguments)
}

extension Bundle {
    /// Point `Bundle.main` string lookups at the given language's `.lproj`.
    static func setAppLanguage(_ code: String) {
        if !(Bundle.main is LanguageBundle) {
            object_setClass(Bundle.main, LanguageBundle.self)
        }
        let langBundle = Bundle.main.path(forResource: code, ofType: "lproj").flatMap(Bundle.init(path:))
        objc_setAssociatedObject(Bundle.main, &languageBundleKey, langBundle, .OBJC_ASSOCIATION_RETAIN)
    }
}
