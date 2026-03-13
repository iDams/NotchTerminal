import Foundation
import XCTest
@testable import NotchTerminal

final class TerminalCommandDirectoryChangeLogicTests: XCTestCase {
    func testDirectoryChangeNormalizesPathAndResolvesProjectContext() throws {
        let root = makeTempDirectory()
        let project = root.appendingPathComponent("SampleProject", isDirectory: true)
        let nested = project.appendingPathComponent("Sources/App", isDirectory: true)

        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: project.appendingPathComponent("Package.swift").path, contents: Data())

        let update = TerminalCommandLifecycleLogic.directoryChangeUpdate(
            rawDirectory: nested.path,
            pending: nil
        )

        XCTAssertEqual(update.normalizedWorkingDirectory, nested.path)
        XCTAssertEqual(update.projectContext, ProjectContext(rootPath: project.path, displayName: "SampleProject"))
        XCTAssertNil(update.emittedCompletionEvent)
    }

    func testDirectoryChangeEmitsSuccessCompletionWhenPendingCommandDidNotFail() {
        let pending = PendingOrbCommandState(
            event: TerminalCommandOrbEvent(
                displayID: 1,
                terminalNumber: 2,
                kind: .package,
                status: .running,
                command: "npm run dev",
                duration: 2,
                isPersistent: true
            )
        )

        let update = TerminalCommandLifecycleLogic.directoryChangeUpdate(
            rawDirectory: FileManager.default.temporaryDirectory.path,
            pending: pending
        )

        XCTAssertNil(update.remainingPendingOrbCommand)
        XCTAssertEqual(update.emittedCompletionEvent?.status, .success)
        XCTAssertEqual(update.emittedCompletionEvent?.command, "npm run dev")
    }

    func testDirectoryChangeDoesNotEmitCompletionForFailedPendingCommand() {
        let pending = PendingOrbCommandState(
            event: TerminalCommandOrbEvent(
                displayID: 1,
                terminalNumber: 2,
                kind: .build,
                status: .running,
                command: "swift build",
                duration: 2,
                isPersistent: false
            ),
            hasFailed: true
        )

        let update = TerminalCommandLifecycleLogic.directoryChangeUpdate(
            rawDirectory: "/definitely/not/real",
            pending: pending
        )

        XCTAssertNil(update.remainingPendingOrbCommand)
        XCTAssertNil(update.emittedCompletionEvent)
        XCTAssertEqual(update.normalizedWorkingDirectory, NSHomeDirectory())
    }

    private func makeTempDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }
}
