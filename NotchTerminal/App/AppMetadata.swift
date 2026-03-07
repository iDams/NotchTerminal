import Foundation

enum AppMetadata {
    private static let bundle = Bundle.main

    static var displayName: String {
        string(for: "CFBundleDisplayName")
        ?? string(for: kCFBundleNameKey as String)
        ?? "NotchTerminal"
    }

    static var version: String {
        string(for: "CFBundleShortVersionString") ?? "1.0.0"
    }

    static var build: String {
        string(for: kCFBundleVersionKey as String) ?? "1"
    }

    static var versionDisplay: String {
        String(format: "settings.about.versionFormat".localized, version, build)
    }

    private static func string(for key: String) -> String? {
        guard let value = bundle.object(forInfoDictionaryKey: key) as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
