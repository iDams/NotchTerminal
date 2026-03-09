import Foundation

struct ProjectContext: Equatable {
    let rootPath: String
    let displayName: String
}

enum ProjectContextResolver {
    private static let directMarkers = [
        ".git",
        "package.json",
        "pnpm-workspace.yaml",
        "Cargo.toml",
        "Package.swift",
        "Podfile",
        "docker-compose.yml",
        "docker-compose.yaml"
    ]

    private static let suffixMarkers = [
        ".xcodeproj",
        ".xcworkspace"
    ]

    static func resolve(
        from workingDirectory: String,
        fileManager: FileManager = .default
    ) -> ProjectContext? {
        let sanitized = workingDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
        guard sanitized.hasPrefix("/") else { return nil }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: sanitized, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return nil
        }

        var currentURL = URL(fileURLWithPath: sanitized, isDirectory: true)
        while true {
            if containsProjectMarker(in: currentURL, fileManager: fileManager) {
                return ProjectContext(
                    rootPath: currentURL.path,
                    displayName: currentURL.lastPathComponent.isEmpty ? currentURL.path : currentURL.lastPathComponent
                )
            }

            let parentURL = currentURL.deletingLastPathComponent()
            if parentURL.path == currentURL.path {
                return nil
            }
            currentURL = parentURL
        }
    }

    private static func containsProjectMarker(in directoryURL: URL, fileManager: FileManager) -> Bool {
        for marker in directMarkers {
            if fileManager.fileExists(atPath: directoryURL.appendingPathComponent(marker).path) {
                return true
            }
        }

        guard let children = try? fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil) else {
            return false
        }
        return children.contains { child in
            suffixMarkers.contains { child.lastPathComponent.hasSuffix($0) }
        }
    }
}
