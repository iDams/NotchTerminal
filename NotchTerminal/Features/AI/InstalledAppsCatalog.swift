import Foundation

enum InstalledAppsCatalog {
    static func load() -> [AICronjobInstalledApp] {
        let searchRoots = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Applications", isDirectory: true)
        ]

        let fileManager = FileManager.default
        var appsByBundleID: [String: AICronjobInstalledApp] = [:]

        for root in searchRoots {
            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }

            for case let url as URL in enumerator {
                guard url.pathExtension == "app" else { continue }
                guard let bundle = Bundle(url: url),
                      let bundleIdentifier = bundle.bundleIdentifier,
                      !bundleIdentifier.isEmpty else {
                    enumerator.skipDescendants()
                    continue
                }

                let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                    ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                    ?? url.deletingPathExtension().lastPathComponent

                let app = AICronjobInstalledApp(
                    bundleIdentifier: bundleIdentifier,
                    displayName: displayName,
                    appPath: url.path
                )

                if let existing = appsByBundleID[bundleIdentifier] {
                    if existing.displayName.localizedCaseInsensitiveCompare(app.displayName) == .orderedDescending {
                        appsByBundleID[bundleIdentifier] = app
                    }
                } else {
                    appsByBundleID[bundleIdentifier] = app
                }

                enumerator.skipDescendants()
            }
        }

        return appsByBundleID.values.sorted {
            if $0.displayName == $1.displayName {
                return $0.bundleIdentifier < $1.bundleIdentifier
            }
            return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }
}
