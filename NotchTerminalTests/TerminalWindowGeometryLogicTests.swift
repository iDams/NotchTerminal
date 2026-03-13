import XCTest
@testable import NotchTerminal

final class TerminalWindowGeometryLogicTests: XCTestCase {
    func testInitialFrameCentersNearTopOfScreen() {
        let frame = TerminalWindowGeometryLogic.initialFrame(
            screenFrame: CGRect(x: 0, y: 0, width: 1600, height: 1000),
            windowSize: CGSize(width: 400, height: 300)
        )

        XCTAssertEqual(frame, CGRect(x: 600, y: 480, width: 400, height: 300))
    }

    func testCompactToggleFrameKeepsTopCenterAnchored() {
        let frame = TerminalWindowGeometryLogic.compactToggleFrame(
            currentFrame: CGRect(x: 100, y: 200, width: 500, height: 400),
            targetSize: CGSize(width: 220, height: 220)
        )

        XCTAssertEqual(frame, CGRect(x: 240, y: 380, width: 220, height: 220))
    }

    func testResetFramePreservesTopLeftAnchor() {
        let frame = TerminalWindowGeometryLogic.resetFrame(
            currentFrame: CGRect(x: 100, y: 260, width: 220, height: 220),
            expandedSize: CGSize(width: 500, height: 400)
        )

        XCTAssertEqual(frame, CGRect(x: 100, y: 80, width: 500, height: 400))
    }

    func testRestoredFrameUsesPreMaximizeWhenAvailable() {
        let expected = CGRect(x: 10, y: 20, width: 700, height: 500)

        let frame = TerminalWindowGeometryLogic.restoredFrameFromMaximize(
            currentFrame: CGRect(x: 0, y: 0, width: 1000, height: 800),
            expandedSize: CGSize(width: 500, height: 400),
            preMaximizeFrame: expected
        )

        XCTAssertEqual(frame, expected)
    }

    func testRestoredFrameFallsBackToCenteredExpandedSize() {
        let frame = TerminalWindowGeometryLogic.restoredFrameFromMaximize(
            currentFrame: CGRect(x: 100, y: 100, width: 1000, height: 800),
            expandedSize: CGSize(width: 500, height: 400),
            preMaximizeFrame: nil
        )

        XCTAssertEqual(frame, CGRect(x: 350, y: 300, width: 500, height: 400))
    }
}
