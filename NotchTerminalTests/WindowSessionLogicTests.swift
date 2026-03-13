import XCTest
@testable import NotchTerminal

final class WindowSessionLogicTests: XCTestCase {
    func testSerializedSessionMapsSnapshotFields() {
        let id = UUID()
        let snapshot = WindowSessionSnapshot(
            id: id,
            number: 4,
            displayID: 123,
            workingDirectory: "/tmp/project",
            expandedFrame: CGRect(x: 10, y: 20, width: 800, height: 500),
            isDockedToNotch: true,
            isAlwaysOnTop: true,
            isCompact: true,
            isMaximized: true,
            displayTitle: "codex",
            projectRootPath: "/tmp",
            projectName: "tmp",
            lastSubmittedCommand: "npm run dev",
            preMaximizeFrame: CGRect(x: 30, y: 40, width: 700, height: 420)
        )
        let timestamp = Date(timeIntervalSince1970: 1234)

        let session = WindowSessionLogic.serializedSession(
            from: snapshot,
            normalizeWorkingDirectory: { path in path.uppercased() },
            creationTimestamp: timestamp
        )

        XCTAssertEqual(session.id, id)
        XCTAssertEqual(session.workingDirectory, "/TMP/PROJECT")
        XCTAssertEqual(session.windowWidth, 800)
        XCTAssertEqual(session.windowHeight, 500)
        XCTAssertTrue(session.isDockedToNotch)
        XCTAssertTrue(session.isAlwaysOnTop)
        XCTAssertTrue(session.isCompact)
        XCTAssertTrue(session.isMaximized)
        XCTAssertEqual(session.displayTitle, "codex")
        XCTAssertEqual(session.projectRootPath, "/tmp")
        XCTAssertEqual(session.projectName, "tmp")
        XCTAssertEqual(session.lastSubmittedCommand, "npm run dev")
        XCTAssertEqual(session.lastKnownDisplayID, "123")
        XCTAssertEqual(session.preMaximizeFrame, CGRect(x: 30, y: 40, width: 700, height: 420))
        XCTAssertEqual(session.creationTimestamp, timestamp)
    }

    func testOrderedWindowIDsSortByNumberAndSupportsFiltering() {
        let first = makeSnapshot(number: 3, displayID: 1)
        let second = makeSnapshot(number: 1, displayID: 2)
        let third = makeSnapshot(number: 2, displayID: 2)

        let ordered = WindowSessionLogic.orderedWindowIDs(from: [first, second, third])
        let filtered = WindowSessionLogic.orderedWindowIDs(from: [first, second, third]) { $0.displayID == 2 }

        XCTAssertEqual(ordered, [second.id, third.id, first.id])
        XCTAssertEqual(filtered, [second.id, third.id])
    }

    func testRenumberedNumbersByIDRemovesGaps() {
        let first = makeSnapshot(number: 7, displayID: 1)
        let second = makeSnapshot(number: 2, displayID: 1)
        let third = makeSnapshot(number: 9, displayID: 2)

        let renumbered = WindowSessionLogic.renumberedNumbersByID(from: [first, second, third])

        XCTAssertEqual(renumbered[second.id], 1)
        XCTAssertEqual(renumbered[first.id], 2)
        XCTAssertEqual(renumbered[third.id], 3)
    }

    func testOrderedWindowIDsOnDisplayReturnsOnlyMatchingDisplayInOrder() {
        let first = makeSnapshot(number: 5, displayID: 2)
        let second = makeSnapshot(number: 1, displayID: 1)
        let third = makeSnapshot(number: 3, displayID: 2)

        let ordered = WindowSessionLogic.orderedWindowIDs(on: 2, from: [first, second, third])

        XCTAssertEqual(ordered, [third.id, first.id])
    }

    func testNextWindowNumberUsesRenumberedCount() {
        let snapshots = [
            makeSnapshot(number: 10, displayID: 1),
            makeSnapshot(number: 40, displayID: 2),
            makeSnapshot(number: 99, displayID: 2)
        ]

        XCTAssertEqual(WindowSessionLogic.nextWindowNumber(from: snapshots), 4)
        XCTAssertEqual(WindowSessionLogic.nextWindowNumber(from: []), 1)
    }

    func testSnapshotProjectionMapsFieldsIntoSnapshot() {
        let id = UUID()
        let snapshot = WindowSessionLogic.snapshot(
            from: .init(
                id: id,
                number: 8,
                displayID: 77,
                workingDirectory: "/tmp/app",
                expandedFrame: CGRect(x: 5, y: 6, width: 700, height: 480),
                isDockedToNotch: true,
                isAlwaysOnTop: true,
                isCompact: false,
                isMaximized: true,
                displayTitle: "codex",
                projectRootPath: "/tmp",
                projectName: "tmp",
                lastSubmittedCommand: "npm run dev",
                preMaximizeFrame: CGRect(x: 1, y: 2, width: 3, height: 4)
            )
        )

        XCTAssertEqual(snapshot.id, id)
        XCTAssertEqual(snapshot.number, 8)
        XCTAssertEqual(snapshot.displayID, 77)
        XCTAssertEqual(snapshot.workingDirectory, "/tmp/app")
        XCTAssertEqual(snapshot.displayTitle, "codex")
        XCTAssertEqual(snapshot.projectRootPath, "/tmp")
        XCTAssertEqual(snapshot.projectName, "tmp")
        XCTAssertEqual(snapshot.lastSubmittedCommand, "npm run dev")
        XCTAssertEqual(snapshot.preMaximizeFrame, CGRect(x: 1, y: 2, width: 3, height: 4))
    }

    func testSerializedSessionsMapsMultipleSnapshots() {
        let snapshots = [
            makeSnapshot(number: 1, displayID: 11),
            makeSnapshot(number: 2, displayID: 12)
        ]

        let sessions = WindowSessionLogic.serializedSessions(
            from: snapshots,
            normalizeWorkingDirectory: { $0 + "/normalized" },
            creationTimestamp: Date(timeIntervalSince1970: 44)
        )

        XCTAssertEqual(sessions.count, 2)
        XCTAssertEqual(sessions.map(\.lastKnownDisplayID), ["11", "12"])
        XCTAssertEqual(sessions.map(\.workingDirectory), ["/tmp/normalized", "/tmp/normalized"])
        XCTAssertTrue(sessions.allSatisfy { $0.creationTimestamp == Date(timeIntervalSince1970: 44) })
    }

    private func makeSnapshot(number: Int, displayID: CGDirectDisplayID) -> WindowSessionSnapshot {
        WindowSessionSnapshot(
            id: UUID(),
            number: number,
            displayID: displayID,
            workingDirectory: "/tmp",
            expandedFrame: CGRect(x: 0, y: 0, width: 640, height: 480),
            isDockedToNotch: false,
            isAlwaysOnTop: false,
            isCompact: false,
            isMaximized: false,
            displayTitle: "NotchTerminal",
            projectRootPath: nil,
            projectName: nil,
            lastSubmittedCommand: nil,
            preMaximizeFrame: nil
        )
    }
}
