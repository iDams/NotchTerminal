import AppKit
import Foundation

enum TerminalWindowContextResolver {
    static func restoredBranding(for session: TerminalSession?) -> CLICommandBranding {
        guard let session else {
            return CLICommandBranding(title: nil, icon: nil)
        }

        let trimmedTitle = session.displayTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, trimmedTitle != "NotchTerminal" else {
            return CLICommandBranding(title: nil, icon: nil)
        }

        return CLICommandBrandingResolver.branding(for: trimmedTitle)
    }

    static func normalizedWorkingDirectory(
        _ raw: String?,
        fileManager: FileManager = .default,
        fallback: String = NSHomeDirectory()
    ) -> String {
        let candidate = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty, candidate.hasPrefix("/"), candidate != "/" else { return fallback }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: candidate, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return fallback
        }
        return candidate
    }

    static func resolvedProjectContext(
        for workingDirectory: String,
        session: TerminalSession?,
        fileManager: FileManager = .default
    ) -> ProjectContext? {
        if let resolved = ProjectContextResolver.resolve(from: workingDirectory, fileManager: fileManager) {
            return resolved
        }

        guard let rootPath = session?.projectRootPath,
              let projectName = session?.projectName,
              !rootPath.isEmpty,
              !projectName.isEmpty else {
            return nil
        }

        return ProjectContext(rootPath: rootPath, displayName: projectName)
    }
}
