import Foundation
import SwiftUI

@Observable
@MainActor
final class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    private let userOverrideKey = "userLanguageOverride"
    private let supportedLanguageCodes = ["en", "es", "fr", "ja"]

    var currentLanguage: String {
        if let userOverride = UserDefaults.standard.string(forKey: userOverrideKey) {
            return userOverride
        }
        return systemLanguage
    }

    var systemLanguage: String {
        let preferredLanguages = Locale.preferredLanguages
        guard let firstLanguage = preferredLanguages.first else {
            return "en"
        }
        let languageCode = String(firstLanguage.prefix(2))
        return supportedLanguageCodes.contains(languageCode) ? languageCode : "en"
    }

    var userHasSelectedLanguage: Bool {
        UserDefaults.standard.string(forKey: userOverrideKey) != nil
    }

    func setLanguage(_ languageCode: String) {
        guard supportedLanguageCodes.contains(languageCode) else { return }
        UserDefaults.standard.set(languageCode, forKey: userOverrideKey)
        objectWillChange.send()
    }

    func resetToSystemLanguage() {
        UserDefaults.standard.removeObject(forKey: userOverrideKey)
        objectWillChange.send()
    }

    func displayName(for languageCode: String) -> String {
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
