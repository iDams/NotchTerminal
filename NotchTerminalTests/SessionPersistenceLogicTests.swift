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
}
