import AppKit
import Foundation

struct PendingOrbCommandState: Equatable {
    let event: TerminalCommandOrbEvent
    var hasFailed: Bool = false
}

struct TerminalCommandBrandingState {
    let displayTitle: String
    let displayIcon: NSImage?
    let preferMouseReporting: Bool
}

enum TerminalCommandLifecycleLogic {
    struct SubmittedCommandUpdate {
        let lastSubmittedCommand: String
        let brandingState: TerminalCommandBrandingState?
        let pendingOrbCommand: PendingOrbCommandState?
        let emittedOrbEvent: TerminalCommandOrbEvent?
    }

    static func submittedCommandUpdate(
        command: String,
        currentDisplayTitle: String,
        currentDisplayIcon: NSImage?,
        defaultDisplayIcon: NSImage?,
        displayID: CGDirectDisplayID,
        terminalNumber: Int
    ) -> SubmittedCommandUpdate {
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = trimmedCommand.lowercased()
        let branding = CLICommandBrandingResolver.branding(for: command)
        let orbEvent = TerminalCommandOrbClassifier.makeEvent(
            command: command,
            displayID: displayID,
            terminalNumber: terminalNumber
        )

        let brandingState: TerminalCommandBrandingState?
        if let newTitle = branding.title {
            if currentDisplayTitle != newTitle || currentDisplayIcon !== branding.icon {
                brandingState = TerminalCommandBrandingState(
                    displayTitle: newTitle,
                    displayIcon: branding.icon,
                    preferMouseReporting: (newTitle == "opencode")
                )
            } else {
                brandingState = nil
            }
        } else if lowered == "exit" || lowered == "quit" {
            brandingState = TerminalCommandBrandingState(
                displayTitle: "NotchTerminal",
                displayIcon: defaultDisplayIcon,
                preferMouseReporting: false
            )
        } else if lowered.hasPrefix("/") {
            brandingState = nil
        } else if currentDisplayIcon != nil {
            brandingState = TerminalCommandBrandingState(
                displayTitle: "NotchTerminal",
                displayIcon: defaultDisplayIcon,
                preferMouseReporting: false
            )
        } else {
            brandingState = nil
        }

        return SubmittedCommandUpdate(
            lastSubmittedCommand: trimmedCommand,
            brandingState: brandingState,
            pendingOrbCommand: orbEvent.map { PendingOrbCommandState(event: $0) },
            emittedOrbEvent: orbEvent
        )
    }

    static func failedOrbState(
        for text: String,
        pending: PendingOrbCommandState
    ) -> (PendingOrbCommandState, TerminalCommandOrbEvent)? {
        guard !pending.hasFailed, outputLooksLikeFailure(text) else { return nil }

        var failed = pending
        failed.hasFailed = true
        return (failed, TerminalCommandOrbClassifier.makeCompletionEvent(from: pending.event, status: .error))
    }

    static func outputLooksLikeFailure(_ text: String) -> Bool {
        let lowered = text.lowercased()
        let patterns = [
            "npm error",
            "npm err!",
            "enoent",
            "command failed",
            "error:",
            "fatal:",
            "traceback (most recent call last)",
            "build failed",
            "test failed",
            "no such file or directory"
        ]
        return patterns.contains { lowered.contains($0) }
    }
}
