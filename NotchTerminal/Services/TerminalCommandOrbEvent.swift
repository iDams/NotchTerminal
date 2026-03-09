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

struct TerminalCommandOrbEvent: Identifiable, Equatable {
    let id = UUID()
    let displayID: CGDirectDisplayID
    let terminalNumber: Int
    let kind: TerminalCommandOrbKind
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

        guard let kind = classify(trimmed) else { return nil }
        return TerminalCommandOrbEvent(
            displayID: displayID,
            terminalNumber: terminalNumber,
            kind: kind,
            command: trimmed,
            duration: 2.0,
            isPersistent: isPersistentCommand(trimmed)
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

        if lowered.contains("pytest") || lowered.contains("vitest") || lowered.contains("jest") || lowered.contains("swift test") || lowered.contains("cargo test") || lowered.contains("npm test") {
            return .test
        }

        if lowered.contains("xcodebuild") || lowered.contains("swift build") || lowered.contains("cargo build") || lowered.contains("make ") || lowered.contains(" cmake") || lowered.contains("gradle") {
            return .build
        }

        return .generic
    }
}
