import SwiftUI

/// English is the default; German is the only other option, switchable in
/// Settings. Deliberately a plain lookup instead of .strings/String Catalogs —
/// this is a runtime in-app toggle independent of the system locale, which
/// bundle-based localization doesn't support out of the box.
enum AppLanguage: String, CaseIterable {
    case english = "en"
    case german = "de"

    var displayName: String {
        switch self {
        case .english: "English"
        case .german: "Deutsch"
        }
    }
}

/// `t("Move", "Verschieben", language)` — pick the string for the current language.
func t(_ en: String, _ de: String, _ language: AppLanguage) -> String {
    language == .german ? de : en
}

/// AppKit code (menus, etc.) isn't a SwiftUI View, so it can't hold an
/// `@AppStorage` property — it just reads the same UserDefaults key directly.
extension AppLanguage {
    static var current: AppLanguage {
        UserDefaults.standard.string(forKey: "language").flatMap(AppLanguage.init) ?? .english
    }
}
