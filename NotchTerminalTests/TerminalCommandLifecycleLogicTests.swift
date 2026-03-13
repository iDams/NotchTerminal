import AppKit
import XCTest
@testable import NotchTerminal

final class TerminalCommandLifecycleLogicTests: XCTestCase {
    func testSubmittedCommandRecognizesBrandingAndCreatesOrbEvent() {
        let update = TerminalCommandLifecycleLogic.submittedCommandUpdate(
            command: "opencode",
            currentDisplayTitle: "NotchTerminal",
            currentDisplayIcon: nil,
            defaultDisplayIcon: nil,
            displayID: 1,
            terminalNumber: 2
        )

        XCTAssertEqual(update.lastSubmittedCommand, "opencode")
        XCTAssertEqual(update.brandingState?.displayTitle, "opencode")
        XCTAssertTrue(update.brandingState?.preferMouseReporting == true)
        XCTAssertEqual(update.pendingOrbCommand?.event.kind, .generic)
        XCTAssertEqual(update.emittedOrbEvent?.status, .running)
    }

    func testSubmittedCommandKeepsSlashCommandBrandingStateNil() {
        let brandedIcon = NSImage(size: NSSize(width: 10, height: 10))
        let update = TerminalCommandLifecycleLogic.submittedCommandUpdate(
            command: "/help",
            currentDisplayTitle: "opencode",
            currentDisplayIcon: brandedIcon,
            defaultDisplayIcon: nil,
            displayID: 1,
            terminalNumber: 2
        )

        XCTAssertNil(update.brandingState)
        XCTAssertEqual(update.pendingOrbCommand?.event.command, "/help")
        XCTAssertEqual(update.emittedOrbEvent?.status, .running)
    }

    func testSubmittedCommandResetsBrandingOnExit() {
        let defaultIcon = NSImage(size: NSSize(width: 20, height: 20))
        let brandedIcon = NSImage(size: NSSize(width: 10, height: 10))
        let update = TerminalCommandLifecycleLogic.submittedCommandUpdate(
            command: "exit",
            currentDisplayTitle: "codex",
            currentDisplayIcon: brandedIcon,
            defaultDisplayIcon: defaultIcon,
            displayID: 1,
            terminalNumber: 2
        )

        XCTAssertEqual(update.brandingState?.displayTitle, "NotchTerminal")
        XCTAssertTrue(update.brandingState?.displayIcon === defaultIcon)
        XCTAssertFalse(update.brandingState?.preferMouseReporting == true)
    }

    func testFailedOrbStateEmitsErrorOnlyOnceForFailureOutput() {
        let pending = PendingOrbCommandState(
            event: TerminalCommandOrbEvent(
                displayID: 1,
                terminalNumber: 2,
                kind: .build,
                status: .running,
                command: "swift build",
                duration: 2,
                isPersistent: false
            )
        )

        let first = TerminalCommandLifecycleLogic.failedOrbState(for: "fatal: build failed", pending: pending)
        XCTAssertEqual(first?.0.hasFailed, true)
        XCTAssertEqual(first?.1.status, .error)

        let second = TerminalCommandLifecycleLogic.failedOrbState(for: "fatal: build failed", pending: first!.0)
        XCTAssertNil(second)
    }

    func testFailureOutputDetectionMatchesKnownPatterns() {
        XCTAssertTrue(TerminalCommandLifecycleLogic.outputLooksLikeFailure("npm ERR! missing script"))
        XCTAssertTrue(TerminalCommandLifecycleLogic.outputLooksLikeFailure("Traceback (most recent call last):"))
        XCTAssertFalse(TerminalCommandLifecycleLogic.outputLooksLikeFailure("Build completed successfully"))
    }
}
