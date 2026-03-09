import Foundation
import CoreGraphics

struct SessionRestorePlan: Equatable {
    let session: TerminalSession
    let displayID: CGDirectDisplayID
    let shouldStartMinimized: Bool
}

enum SessionPersistenceLogic {
    static func resolvedDisplayID(from raw: String, fallback: CGDirectDisplayID = CGMainDisplayID()) -> CGDirectDisplayID {
        guard let parsed = UInt32(raw) else { return fallback }
        return CGDirectDisplayID(parsed)
    }

    static func restorePlans(
        from sessions: [TerminalSession],
        fallbackDisplayID: CGDirectDisplayID = CGMainDisplayID()
    ) -> [SessionRestorePlan] {
        sessions.map { session in
            SessionRestorePlan(
                session: session,
                displayID: resolvedDisplayID(from: session.lastKnownDisplayID, fallback: fallbackDisplayID),
                shouldStartMinimized: session.isDockedToNotch
            )
        }
    }

    static func updatePersistedSession(_ persisted: TerminalSession, from snapshot: TerminalSession) {
        persisted.workingDirectory = snapshot.workingDirectory
        persisted.windowWidth = snapshot.windowWidth
        persisted.windowHeight = snapshot.windowHeight
        persisted.isDockedToNotch = snapshot.isDockedToNotch
        persisted.isAlwaysOnTop = snapshot.isAlwaysOnTop
        persisted.isCompact = snapshot.isCompact
        persisted.isMaximized = snapshot.isMaximized
        persisted.displayTitle = snapshot.displayTitle
        persisted.projectRootPath = snapshot.projectRootPath
        persisted.projectName = snapshot.projectName
        persisted.lastSubmittedCommand = snapshot.lastSubmittedCommand
        persisted.lastKnownDisplayID = snapshot.lastKnownDisplayID
        persisted.preMaximizeFrame = snapshot.preMaximizeFrame
    }
}
