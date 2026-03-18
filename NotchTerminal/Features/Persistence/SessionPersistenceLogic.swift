import Foundation
import CoreGraphics

struct SessionRestorePlan: Equatable {
    let session: TerminalSession
    let displayID: CGDirectDisplayID
    let shouldStartMinimized: Bool
}

/// Maps stored session snapshots into restore/update decisions without pulling
/// persistence APIs or UI concerns into the call sites.
enum SessionPersistenceLogic {
    static func resolvedDisplayID(from raw: String, fallback: CGDirectDisplayID = CGMainDisplayID()) -> CGDirectDisplayID {
        guard let parsed = UInt32(raw) else { return fallback }
        return CGDirectDisplayID(parsed)
    }

    static func restorePlans(
        from sessions: [TerminalSession],
        fallbackDisplayID: CGDirectDisplayID = CGMainDisplayID()
    ) -> [SessionRestorePlan] {
        // Docked windows come back minimized so the notch can own their initial
        // presentation instead of flashing full window chrome on launch.
        sessions.map { session in
            SessionRestorePlan(
                session: session,
                displayID: resolvedDisplayID(from: session.lastKnownDisplayID, fallback: fallbackDisplayID),
                shouldStartMinimized: session.isDockedToNotch
            )
        }
    }

    static func updatePersistedSession(_ persisted: TerminalSession, from snapshot: TerminalSession) {
        // Keeping this field-to-field makes it obvious which runtime values are
        // expected to survive app relaunch.
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
