import XCTest
@testable import NotchTerminal

final class NotchCapsuleActionLogicTests: XCTestCase {
    func testResolveCloseAllActionRequestsConfirmationWhenEnabled() {
        let resolution = NotchCapsuleActionLogic.resolveCloseAllAction(
            confirmBeforeCloseAll: true,
            ownDisplayID: 77
        )

        XCTAssertEqual(resolution, .requestConfirmation(77))
    }

    func testResolveCloseAllActionClosesImmediatelyWhenDisabled() {
        let resolution = NotchCapsuleActionLogic.resolveCloseAllAction(
            confirmBeforeCloseAll: false,
            ownDisplayID: 77
        )

        XCTAssertEqual(resolution, .closeImmediately)
    }

    func testShiftedScreenIndexMovesWithinBounds() {
        XCTAssertEqual(
            NotchCapsuleActionLogic.shiftedScreenIndex(currentIndex: 1, delta: 1, availableCount: 4),
            2
        )
        XCTAssertEqual(
            NotchCapsuleActionLogic.shiftedScreenIndex(currentIndex: 2, delta: -1, availableCount: 4),
            1
        )
    }

    func testShiftedScreenIndexReturnsNilWhenOutOfBounds() {
        XCTAssertNil(NotchCapsuleActionLogic.shiftedScreenIndex(currentIndex: 0, delta: -1, availableCount: 4))
        XCTAssertNil(NotchCapsuleActionLogic.shiftedScreenIndex(currentIndex: 3, delta: 1, availableCount: 4))
    }
}
