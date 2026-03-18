import Foundation
import SwiftUI

@Observable
final class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    private let userOverrideKey = "userLanguageOverride"
    private let fallbackLanguageCode = "en"
    private let supportedLanguageCodes = ["en", "es", "fr", "ja", "zh-Hans", "de", "pt-BR", "ko", "it", "ru"]
    private let supportedLanguageDisplayNames = [
        "en": "English",
        "es": "Español",
        "fr": "Français",
        "ja": "日本語",
        "zh-Hans": "简体中文",
        "de": "Deutsch",
        "pt-BR": "Português (Brasil)",
        "ko": "한국어",
        "it": "Italiano",
        "ru": "Русский"
    ]
    
    private var _updateTrigger: Int = 0
    var updateTrigger: Int {
        get { _updateTrigger }
    }

    var currentLanguage: String {
        if let userOverride = UserDefaults.standard.string(forKey: userOverrideKey) {
            return normalizedLanguageCode(from: userOverride)
        }
        return systemLanguage
    }

    var systemLanguage: String {
        guard let firstLanguage = Locale.preferredLanguages.first else {
            return fallbackLanguageCode
        }
        return normalizedLanguageCode(from: firstLanguage)
    }

    var userHasSelectedLanguage: Bool {
        UserDefaults.standard.string(forKey: userOverrideKey) != nil
    }

    func setLanguage(_ languageCode: String) {
        let normalizedCode = normalizedLanguageCode(from: languageCode)
        guard supportedLanguageCodes.contains(normalizedCode) else { return }
        UserDefaults.standard.set(normalizedCode, forKey: userOverrideKey)
        _updateTrigger += 1
        objectWillChange.send()
    }

    func resetToSystemLanguage() {
        UserDefaults.standard.removeObject(forKey: userOverrideKey)
        _updateTrigger += 1
        objectWillChange.send()
    }

    func displayName(for languageCode: String) -> String {
        if let displayName = supportedLanguageDisplayNames[languageCode] {
            return displayName
        }
        let locale = Locale(identifier: languageCode)
        return locale.localizedString(forLanguageCode: languageCode) ?? languageCode.uppercased()
    }

    var availableLanguages: [(code: String, name: String)] {
        supportedLanguageCodes.map { code in
            (code: code, name: displayName(for: code))
        }
    }
    
    func localizedString(_ key: String) -> String {
        let lang = currentLanguage
        guard let path = Bundle.main.path(forResource: lang, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return NSLocalizedString(key, comment: "")
        }
        return NSLocalizedString(key, bundle: bundle, comment: "")
    }

    private func normalizedLanguageCode(from identifier: String) -> String {
        let normalizedIdentifier = identifier.lowercased()

        if normalizedIdentifier.hasPrefix("zh-hans")
            || normalizedIdentifier.hasPrefix("zh-cn")
            || normalizedIdentifier == "zh" {
            return "zh-Hans"
        }

        if normalizedIdentifier.hasPrefix("en") { return "en" }
        if normalizedIdentifier.hasPrefix("es") { return "es" }
        if normalizedIdentifier.hasPrefix("fr") { return "fr" }
        if normalizedIdentifier.hasPrefix("ja") { return "ja" }
        if normalizedIdentifier.hasPrefix("de") { return "de" }
        if normalizedIdentifier.hasPrefix("pt-br") || normalizedIdentifier.hasPrefix("pt") { return "pt-BR" }
        if normalizedIdentifier.hasPrefix("ko") { return "ko" }
        if normalizedIdentifier.hasPrefix("it") { return "it" }
        if normalizedIdentifier.hasPrefix("ru") { return "ru" }

        return fallbackLanguageCode
    }
}

extension String {
    var localized: String {
        LanguageManager.shared.localizedString(self)
    }

    func localized(in language: String) -> String {
        guard let path = Bundle.main.path(forResource: language, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return self
        }
        return NSLocalizedString(self, bundle: bundle, comment: "")
    }
}
