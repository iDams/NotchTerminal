import Foundation
import AppKit

struct CLICommandBranding {
    let title: String
    let icon: NSImage?
}

enum CLICommandBrandingResolver {
    private static let iconByCommand: [String: String] = [
        "opencode": "/Users/marco/Documents/project/NotchTerminal/NotchTerminal/Resources/CLIIcons/opencode-logo-dark.svg"
    ]

    static func branding(for command: String) -> CLICommandBranding {
        let normalized = normalize(command)
        let icon = loadIcon(for: normalized)
        return CLICommandBranding(title: normalized, icon: icon)
    }

    private static func normalize(_ command: String) -> String {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "shell" }

        var tokens = trimmed.split(whereSeparator: \.isWhitespace).map(String.init)
        while let first = tokens.first, first.contains("=") {
            tokens.removeFirst()
        }
        while let first = tokens.first, ["sudo", "env", "nohup", "time", "command"].contains(first) {
            tokens.removeFirst()
        }

        guard let raw = tokens.first else { return "shell" }
        let base = URL(fileURLWithPath: raw).lastPathComponent
        return base.isEmpty ? "shell" : base
    }

    private static func loadIcon(for normalizedCommand: String) -> NSImage? {
        guard let iconPath = iconByCommand[normalizedCommand] else { return nil }
        guard FileManager.default.fileExists(atPath: iconPath) else { return nil }

        if let image = NSImage(contentsOfFile: iconPath) {
            return image
        }

        let fallback = NSWorkspace.shared.icon(forFile: iconPath)
        fallback.size = NSSize(width: 14, height: 14)
        return fallback
    }
}
