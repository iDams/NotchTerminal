import XCTest
@testable import NotchTerminal

final class TerminalSubmittedCommandParserTests: XCTestCase {
    func testParsePrefersTypedInputForNormalCommands() {
        let command = TerminalSubmittedCommandParser.parse(
            visibleLine: "marco@NotchTerminal % git status --short",
            rawInputLine: "git status --short"
        )

        XCTAssertEqual(command, "git status --short")
    }

    func testParseExtractsKnownCommandFromMessyPromptOnHistoryRecall() {
        let command = TerminalSubmittedCommandParser.parse(
            visibleLine: "marco@NotchTerminal on main via v18.19.0 npm run dev -- --host",
            rawInputLine: "[A"
        )

        XCTAssertEqual(command, "npm run dev -- --host")
    }

    func testParseFallsBackToLastPromptComponentForHistoryRecall() {
        let command = TerminalSubmittedCommandParser.parse(
            visibleLine: "feature/notch  12:30:41  deploy preview --env prod",
            rawInputLine: "OA"
        )

        XCTAssertEqual(command, "deploy preview --env prod")
    }

    func testParseUsesVisibleCommandWhenRawInputIsEmpty() {
        let command = TerminalSubmittedCommandParser.parse(
            visibleLine: "swift test --filter AppPreferencesTests",
            rawInputLine: ""
        )

        XCTAssertEqual(command, "swift test --filter AppPreferencesTests")
    }

    func testParseReturnsNilWhenNoCommandCanBeResolved() {
        XCTAssertNil(TerminalSubmittedCommandParser.parse(visibleLine: "", rawInputLine: ""))
        XCTAssertNil(TerminalSubmittedCommandParser.parse(visibleLine: "custom prompt", rawInputLine: "   "))
    }
}
