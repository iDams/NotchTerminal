import Foundation
import CoreGraphics

enum TerminalCommandOrbKind: Equatable {
    case package
    case git
    case build
    case test
    case download
    case generic
}

enum TerminalCommandOrbStatus: Equatable {
    case running
    case success
    case error
}

struct TerminalCommandOrbEvent: Identifiable, Equatable {
    let id = UUID()
    let displayID: CGDirectDisplayID
    let terminalNumber: Int
    let kind: TerminalCommandOrbKind
    let status: TerminalCommandOrbStatus
    let command: String
    let duration: TimeInterval
    let isPersistent: Bool
}

enum TerminalCommandOrbClassifier {
    static func makeEvent(
        command: String,
        displayID: CGDirectDisplayID,
        terminalNumber: Int
    ) -> TerminalCommandOrbEvent? {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let normalized = normalize(trimmed)
        guard !normalized.isEmpty else { return nil }

        guard let kind = classify(normalized) else { return nil }
        return TerminalCommandOrbEvent(
            displayID: displayID,
            terminalNumber: terminalNumber,
            kind: kind,
            status: .running,
            command: trimmed,
            duration: 2.0,
            isPersistent: isPersistentCommand(normalized)
        )
    }

    private static func normalize(_ command: String) -> String {
        var tokens = command.split(whereSeparator: \.isWhitespace).map(String.init)
        while let first = tokens.first, first.contains("=") {
            tokens.removeFirst()
        }
        while let first = tokens.first, ["sudo", "env", "nohup", "time", "command"].contains(first) {
            tokens.removeFirst()
        }
        guard let raw = tokens.first else { return "" }
        
        let base = URL(fileURLWithPath: raw).lastPathComponent
        guard !base.isEmpty else { return "" }
        
        if tokens.count > 1 {
            return base + " " + tokens.dropFirst().joined(separator: " ")
        }
        return base
    }

    static func makeCompletionEvent(
        from event: TerminalCommandOrbEvent,
        status: TerminalCommandOrbStatus
    ) -> TerminalCommandOrbEvent {
        TerminalCommandOrbEvent(
            displayID: event.displayID,
            terminalNumber: event.terminalNumber,
            kind: event.kind,
            status: status,
            command: event.command,
            duration: status == .error ? 1.6 : 1.0,
            isPersistent: false
        )
    }

    private static func isPersistentCommand(_ command: String) -> Bool {
        let lowered = command.lowercased()
        let persistentPrefixes = [
            "npm run dev",
            "npm run start",
            "pnpm dev",
            "pnpm start",
            "yarn dev",
            "yarn start",
            "bun dev",
            "bun run dev",
            "vite",
            "next dev",
            "astro dev",
            "nuxt dev"
        ]
        return persistentPrefixes.contains { lowered.hasPrefix($0) }
    }

    private static func classify(_ command: String) -> TerminalCommandOrbKind? {
        let lowered = command.lowercased()

        if isTrivialCommand(lowered) {
            return nil
        }

        if lowered.hasPrefix("git ") {
            return .git
        }

        if lowered.contains("npm install") || lowered.contains("pnpm install") || lowered.contains("yarn install") || lowered.contains("bun install") {
            return .download
        }

        if lowered.contains("curl ") || lowered.contains("wget ") || lowered.contains("aria2") || lowered.contains("git clone") {
            return .download
        }

        if lowered.hasPrefix("npm ") || lowered.hasPrefix("pnpm ") || lowered.hasPrefix("yarn ") || lowered.hasPrefix("bun ") {
            return .package
        }

        if lowered.hasPrefix("vite")
            || lowered.hasPrefix("next dev")
            || lowered.hasPrefix("astro dev")
            || lowered.hasPrefix("nuxt dev")
        {
            return .package
        }

        if lowered.contains("pytest") || lowered.contains("vitest") || lowered.contains("jest") || lowered.contains("swift test") || lowered.contains("cargo test") || lowered.contains("npm test") {
            return .test
        }

        if lowered.contains("xcodebuild") || lowered.contains("swift build") || lowered.contains("cargo build") || lowered.contains("make ") || lowered.contains(" cmake") || lowered.contains("gradle") {
            return .build
        }

        return .generic
    }

    private static func isTrivialCommand(_ command: String) -> Bool {
        let trivialPrefixes = [
            "ls",
            "pwd",
            "cd ",
            "echo ",
            "clear",
            "which ",
            "whoami",
            "cat ",
            "mkdir ",
            "touch ",
            "open "
        ]

        return trivialPrefixes.contains { prefix in
            command == prefix || command.hasPrefix(prefix)
        }
    }
}
