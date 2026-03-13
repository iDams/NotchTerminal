import AppKit
import Foundation

struct TerminalWindowPresentationSnapshot {
    let id: UUID
    let number: Int
    let displayID: CGDirectDisplayID
    let title: String
    let projectName: String?
    let workingDirectory: String
    let lastCommand: String?
    let icon: NSImage?
    let preview: NSImage?
    let isMinimized: Bool
    let isAlwaysOnTop: Bool
    let isActive: Bool
}

enum TerminalWindowPresentationLogic {
    static func items(from snapshots: [TerminalWindowPresentationSnapshot]) -> [TerminalWindowItem] {
        snapshots
            .sorted { $0.number < $1.number }
            .map(item(from:))
    }

    static func item(from snapshot: TerminalWindowPresentationSnapshot) -> TerminalWindowItem {
        TerminalWindowItem(
            id: snapshot.id,
            number: snapshot.number,
            displayID: snapshot.displayID,
            title: snapshot.title,
            projectName: snapshot.projectName,
            workingDirectory: snapshot.workingDirectory,
            lastCommand: snapshot.lastCommand,
            icon: snapshot.icon,
            preview: snapshot.preview,
            isMinimized: snapshot.isMinimized,
            isAlwaysOnTop: snapshot.isAlwaysOnTop,
            isActive: snapshot.isActive
        )
    }
}
