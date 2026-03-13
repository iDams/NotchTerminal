import CoreGraphics
import Foundation
import XCTest
@testable import NotchTerminal

final class TerminalInteractionHelpersTests: XCTestCase {
    func testDropInteractionBuildsQuotedInsertionText() {
        let urls = [
            URL(fileURLWithPath: "/tmp/hello world.txt"),
            URL(fileURLWithPath: "/tmp/it's-me.sh")
        ]

        let insertion = TerminalDropInteractionHelper.insertionText(for: urls)

        XCTAssertEqual(insertion, "'/tmp/hello world.txt' '/tmp/it'\\''s-me.sh' ")
    }

    func testDropInteractionFiltersNonFileURLsAndEmptyPayloads() {
        XCTAssertFalse(TerminalDropInteractionHelper.hasDroppableFileURLs(nil))
        XCTAssertFalse(TerminalDropInteractionHelper.hasDroppableFileURLs([]))
        XCTAssertFalse(TerminalDropInteractionHelper.hasDroppableFileURLs([URL(string: "https://example.com")!]))
        XCTAssertNil(TerminalDropInteractionHelper.insertionText(for: [URL(string: "https://example.com")!]))

        XCTAssertTrue(
            TerminalDropInteractionHelper.hasDroppableFileURLs([
                URL(string: "https://example.com")!,
                URL(fileURLWithPath: "/tmp/file.txt")
            ])
        )
    }

    func testSelectionAutoScrollReturnsExpectedDeltaThresholds() {
        let bounds = CGRect(x: 0, y: 0, width: 200, height: 100)

        XCTAssertEqual(
            TerminalSelectionAutoScrollLogic.delta(for: CGPoint(x: 50, y: 50), in: bounds, rows: 12),
            0
        )
        XCTAssertEqual(
            TerminalSelectionAutoScrollLogic.delta(for: CGPoint(x: 50, y: 102), in: bounds, rows: 12),
            -1
        )
        XCTAssertEqual(
            TerminalSelectionAutoScrollLogic.delta(for: CGPoint(x: 50, y: 112), in: bounds, rows: 12),
            -3
        )
        XCTAssertEqual(
            TerminalSelectionAutoScrollLogic.delta(for: CGPoint(x: 50, y: -24), in: bounds, rows: 12),
            10
        )
        XCTAssertEqual(
            TerminalSelectionAutoScrollLogic.delta(for: CGPoint(x: 50, y: -40), in: bounds, rows: 12),
            20
        )
    }
}
