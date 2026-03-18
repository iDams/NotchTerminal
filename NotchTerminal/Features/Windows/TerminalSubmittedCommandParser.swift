import Foundation

/// Extracts the command the user actually submitted from the terminal prompt.
/// The visible line can contain prompts/history UI while the raw input can be
/// empty or contain escape sequences during history recall.
enum TerminalSubmittedCommandParser {
    private static let knownCommands = [
        "npm", "pnpm", "yarn", "bun", "git", "cargo", "make", "vite", "next", "astro", "nuxt",
        "python", "python3", "node", "swift", "xcodebuild", "curl", "wget"
    ]

    static func parse(visibleLine: String, rawInputLine: String) -> String? {
        let trimmedVisibleLine = visibleLine.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedRawInputLine = rawInputLine.trimmingCharacters(in: .whitespacesAndNewlines)
        let extractedCommand = extractedCommand(from: trimmedVisibleLine, rawInputLine: trimmedRawInputLine)
        let isHistoryRecall = containsHistoryRecallSequence(trimmedRawInputLine)
        // For normal submissions the raw line is more accurate. During reverse
        // history search, the visible line is the only reliable source.
        let finalCommand = (isHistoryRecall || trimmedRawInputLine.isEmpty) ? extractedCommand : trimmedRawInputLine
        return finalCommand.isEmpty ? nil : finalCommand
    }

    private static func extractedCommand(from visibleLine: String, rawInputLine: String) -> String {
        guard !visibleLine.isEmpty else { return "" }

        // Look for the last known command token so prompts, timestamps, or
        // shell decorations in front do not become part of the parsed result.
        var bestMatchIndex: String.Index?
        for command in knownCommands {
            if let range = visibleLine.range(of: " \(command) ", options: .backwards) {
                let candidateIndex = visibleLine.index(after: range.lowerBound)
                if bestMatchIndex == nil || candidateIndex > bestMatchIndex! {
                    bestMatchIndex = candidateIndex
                }
            } else if visibleLine.hasPrefix("\(command) "), bestMatchIndex == nil {
                bestMatchIndex = visibleLine.startIndex
            }
        }

        if let bestMatchIndex {
            return String(visibleLine[bestMatchIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard containsHistoryRecallSequence(rawInputLine) else { return "" }
        // Reverse-search prompts often separate columns with double spaces; the
        // last non-empty segment is usually the surfaced command.
        let components = visibleLine.components(separatedBy: "  ").filter {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return components.last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private static func containsHistoryRecallSequence(_ rawInputLine: String) -> Bool {
        rawInputLine.contains("OA") || rawInputLine.contains("[A")
    }
}
