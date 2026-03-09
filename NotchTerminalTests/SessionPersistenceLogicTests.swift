import XCTest
@testable import NotchTerminal

final class SessionPersistenceLogicTests: XCTestCase {
    func testResolvedDisplayIDParsesValidRawValue() {
        XCTAssertEqual(SessionPersistenceLogic.resolvedDisplayID(from: "123"), 123)
    }

    func testResolvedDisplayIDFallsBackForInvalidRawValue() {
        XCTAssertEqual(SessionPersistenceLogic.resolvedDisplayID(from: "not-a-display", fallback: 77), 77)
        XCTAssertEqual(SessionPersistenceLogic.resolvedDisplayID(from: "", fallback: 88), 88)
    }

    func testRestorePlansPreserveOrderAndMinimizedState() {
        let first = TerminalSession(
            id: UUID(),
            workingDirectory: "/tmp/one",
            windowWidth: 640,
            windowHeight: 480,
            isDockedToNotch: false,
            lastKnownDisplayID: "11",
            creationTimestamp: Date(timeIntervalSince1970: 1)
        )
        let second = TerminalSession(
            id: UUID(),
            workingDirectory: "/tmp/two",
            windowWidth: 800,
            windowHeight: 500,
            isDockedToNotch: true,
            lastKnownDisplayID: "invalid",
            creationTimestamp: Date(timeIntervalSince1970: 2)
        )

        let plans = SessionPersistenceLogic.restorePlans(from: [first, second], fallbackDisplayID: 42)

        XCTAssertEqual(plans.map(\.session.id), [first.id, second.id])
        XCTAssertEqual(plans.map(\.displayID), [11, 42])
        XCTAssertEqual(plans.map(\.shouldStartMinimized), [false, true])
    }

    func testUpdatePersistedSessionCopiesExpandedSessionState() {
        let persisted = TerminalSession(
            id: UUID(),
            workingDirectory: "/tmp/original",
            windowWidth: 640,
            windowHeight: 480,
            isDockedToNotch: false,
            isAlwaysOnTop: false,
            isCompact: false,
            isMaximized: false,
            displayTitle: "NotchTerminal",
            lastKnownDisplayID: "1",
            creationTimestamp: Date(timeIntervalSince1970: 10)
        )
        let snapshot = TerminalSession(
            id: persisted.id,
            workingDirectory: "/tmp/updated",
            windowWidth: 1200,
            windowHeight: 700,
            isDockedToNotch: true,
            isAlwaysOnTop: true,
            isCompact: true,
            isMaximized: true,
            displayTitle: "gemini",
            projectRootPath: "/tmp/project",
            projectName: "project",
            lastSubmittedCommand: "swift test",
            lastKnownDisplayID: "77",
            preMaximizeFrame: CGRect(x: 40, y: 50, width: 800, height: 500),
            creationTimestamp: Date(timeIntervalSince1970: 20)
        )

        SessionPersistenceLogic.updatePersistedSession(persisted, from: snapshot)

        XCTAssertEqual(persisted.workingDirectory, "/tmp/updated")
        XCTAssertEqual(persisted.windowWidth, 1200)
        XCTAssertEqual(persisted.windowHeight, 700)
        XCTAssertTrue(persisted.isDockedToNotch)
        XCTAssertTrue(persisted.isAlwaysOnTop)
        XCTAssertTrue(persisted.isCompact)
        XCTAssertTrue(persisted.isMaximized)
        XCTAssertEqual(persisted.displayTitle, "gemini")
        XCTAssertEqual(persisted.projectRootPath, "/tmp/project")
        XCTAssertEqual(persisted.projectName, "project")
        XCTAssertEqual(persisted.lastSubmittedCommand, "swift test")
        XCTAssertEqual(persisted.lastKnownDisplayID, "77")
        XCTAssertEqual(persisted.preMaximizeFrame, CGRect(x: 40, y: 50, width: 800, height: 500))
        XCTAssertEqual(persisted.creationTimestamp, Date(timeIntervalSince1970: 10))
    }
}
