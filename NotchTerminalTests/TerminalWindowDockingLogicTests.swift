import XCTest
@testable import NotchTerminal

final class TerminalWindowDockingLogicTests: XCTestCase {
    func testDockThumbnailFrameUsesNotchFrameWhenPresent() {
        let sourceFrame = CGRect(x: 100, y: 120, width: 400, height: 300)
        let notchFrame = CGRect(x: 220, y: 700, width: 160, height: 32)

        let frame = TerminalWindowDockingLogic.dockThumbnailFrame(from: sourceFrame, notchFrame: notchFrame)

        XCTAssertEqual(frame, CGRect(x: 273, y: 678, width: 54, height: 54))
    }

    func testPreviewFrameShrinksWindowAroundTopCenter() {
        let original = CGRect(x: 100, y: 200, width: 500, height: 400)

        let frame = TerminalWindowDockingLogic.previewFrame(for: original)

        XCTAssertEqual(frame, CGRect(x: 165, y: 304, width: 370, height: 296))
    }

    func testClosestTargetPrefersNearestCandidateContainingTopCenter() {
        let left = TerminalWindowDockTarget(displayID: 1, frame: CGRect(x: 0, y: 700, width: 160, height: 32))
        let right = TerminalWindowDockTarget(displayID: 2, frame: CGRect(x: 300, y: 700, width: 160, height: 32))
        let windowFrame = CGRect(x: 320, y: 480, width: 200, height: 240)

        let target = TerminalWindowDockingLogic.closestTarget(
            to: windowFrame,
            sensitivity: 80,
            candidates: [
                .init(target: left, effectiveFrame: left.frame),
                .init(target: right, effectiveFrame: right.frame)
            ]
        )

        XCTAssertEqual(target?.displayID, 2)
    }

    func testClosestTargetReturnsNilWhenNoCandidateContainsTopCenter() {
        let target = TerminalWindowDockingLogic.closestTarget(
            to: CGRect(x: 10, y: 10, width: 120, height: 120),
            sensitivity: 20,
            candidates: [
                .init(
                    target: TerminalWindowDockTarget(displayID: 1, frame: CGRect(x: 400, y: 700, width: 160, height: 32)),
                    effectiveFrame: CGRect(x: 400, y: 700, width: 160, height: 32)
                )
            ]
        )

        XCTAssertNil(target)
    }

    func testIsPillShapeDistinguishesWideAndTallFrames() {
        XCTAssertTrue(TerminalWindowDockingLogic.isPillShape(frame: CGRect(x: 0, y: 0, width: 160, height: 32)))
        XCTAssertFalse(TerminalWindowDockingLogic.isPillShape(frame: CGRect(x: 0, y: 0, width: 120, height: 100)))
    }
}
