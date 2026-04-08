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

    struct DirectoryChangeUpdate {
        let normalizedWorkingDirectory: String
        let projectContext: ProjectContext?
        let remainingPendingOrbCommand: PendingOrbCommandState?
        let emittedCompletionEvent: TerminalCommandOrbEvent?
    }

    static func interruptUpdate(
        currentDisplayTitle: String,
        currentPreferMouseReporting: Bool,
        defaultDisplayIcon: NSImage?
    ) -> TerminalCommandBrandingState? {
        guard currentPreferMouseReporting,
              CLICommandBrandingResolver.isBrandedCommand(currentDisplayTitle) else {
            return nil
        }

        return TerminalCommandBrandingState(
            displayTitle: "NotchTerminal",
            displayIcon: defaultDisplayIcon,
            preferMouseReporting: false
        )
    }

    static func foregroundBrandingUpdate(
        branding: CLICommandBranding?,
        currentDisplayTitle: String,
        currentDisplayIcon: NSImage?,
        defaultDisplayIcon: NSImage?
    ) -> TerminalCommandBrandingState? {
        if let branding, let title = branding.title {
            if currentDisplayTitle != title || (currentDisplayIcon == nil) != (branding.icon == nil) {
                return TerminalCommandBrandingState(
                    displayTitle: title,
                    displayIcon: branding.icon,
                    preferMouseReporting: (title == "opencode")
                )
            }
            return nil
        }

        if CLICommandBrandingResolver.isBrandedCommand(currentDisplayTitle) {
            return TerminalCommandBrandingState(
                displayTitle: "NotchTerminal",
                displayIcon: defaultDisplayIcon,
                preferMouseReporting: false
            )
        }

        return nil
    }

    static func submittedCommandUpdate(
        command: String,
        currentDisplayTitle: String,
        currentDisplayIcon: NSImage?,
        currentPreferMouseReporting: Bool,
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
            if currentDisplayTitle != newTitle || (currentDisplayIcon == nil) != (branding.icon == nil) {
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
        } else if currentPreferMouseReporting,
                  CLICommandBrandingResolver.isBrandedCommand(currentDisplayTitle) {
            // Interactive prompt text from tools like OpenCode should not
            // clear provider branding while the tool is still active.
            brandingState = nil
        } else if CLICommandBrandingResolver.isBrandedCommand(currentDisplayTitle) {
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

    static func directoryChangeUpdate(
        rawDirectory: String,
        pending: PendingOrbCommandState?,
        fileManager: FileManager = .default
    ) -> DirectoryChangeUpdate {
        let normalizedWorkingDirectory = TerminalWindowContextResolver.normalizedWorkingDirectory(
            rawDirectory,
            fileManager: fileManager
        )
        let projectContext = ProjectContextResolver.resolve(from: normalizedWorkingDirectory, fileManager: fileManager)

        guard let pending else {
            return DirectoryChangeUpdate(
                normalizedWorkingDirectory: normalizedWorkingDirectory,
                projectContext: projectContext,
                remainingPendingOrbCommand: nil,
                emittedCompletionEvent: nil
            )
        }

        let completionEvent = pending.hasFailed
            ? nil
            : TerminalCommandOrbClassifier.makeCompletionEvent(from: pending.event, status: .success)

        return DirectoryChangeUpdate(
            normalizedWorkingDirectory: normalizedWorkingDirectory,
            projectContext: projectContext,
            remainingPendingOrbCommand: nil,
            emittedCompletionEvent: completionEvent
        )
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
