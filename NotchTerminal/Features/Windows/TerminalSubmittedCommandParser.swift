import Foundation

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
        let finalCommand = (isHistoryRecall || trimmedRawInputLine.isEmpty) ? extractedCommand : trimmedRawInputLine
        return finalCommand.isEmpty ? nil : finalCommand
    }

    private static func extractedCommand(from visibleLine: String, rawInputLine: String) -> String {
        guard !visibleLine.isEmpty else { return "" }

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
        let components = visibleLine.components(separatedBy: "  ").filter {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return components.last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private static func containsHistoryRecallSequence(_ rawInputLine: String) -> Bool {
        rawInputLine.contains("OA") || rawInputLine.contains("[A")
    }
}
