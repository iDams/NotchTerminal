import Foundation
import CoreGraphics

struct WindowSessionSnapshot: Equatable {
    let id: UUID
    let number: Int
    let displayID: CGDirectDisplayID
    let workingDirectory: String
    let expandedFrame: CGRect
    let isDockedToNotch: Bool
}

enum WindowSessionLogic {
    static func serializedSession(
        from snapshot: WindowSessionSnapshot,
        normalizeWorkingDirectory: (String) -> String,
        creationTimestamp: Date = Date()
    ) -> TerminalSession {
        TerminalSession(
            id: snapshot.id,
            workingDirectory: normalizeWorkingDirectory(snapshot.workingDirectory),
            windowWidth: snapshot.expandedFrame.width,
            windowHeight: snapshot.expandedFrame.height,
            isDockedToNotch: snapshot.isDockedToNotch,
            lastKnownDisplayID: String(snapshot.displayID),
            creationTimestamp: creationTimestamp
        )
    }

    static func orderedWindowIDs(
        from snapshots: [WindowSessionSnapshot],
        where predicate: ((WindowSessionSnapshot) -> Bool)? = nil
    ) -> [UUID] {
        snapshots
            .filter { predicate?($0) ?? true }
            .sorted { $0.number < $1.number }
            .map(\.id)
    }

    static func renumberedNumbersByID(from snapshots: [WindowSessionSnapshot]) -> [UUID: Int] {
        Dictionary(
            uniqueKeysWithValues: orderedWindowIDs(from: snapshots)
                .enumerated()
                .map { index, id in (id, index + 1) }
        )
    }

    static func orderedWindowIDs(
        on displayID: CGDirectDisplayID,
        from snapshots: [WindowSessionSnapshot]
    ) -> [UUID] {
        orderedWindowIDs(from: snapshots) { $0.displayID == displayID }
    }

    static func nextWindowNumber(from snapshots: [WindowSessionSnapshot]) -> Int {
        orderedWindowIDs(from: snapshots).count + 1
    }
}
