import XCTest
@testable import NotchTerminal

final class TerminalCommandOrbClassifierTests: XCTestCase {
    private let displayID: CGDirectDisplayID = 77
    private let terminalNumber = 3

    func testTrivialCommandsDoNotGenerateEvents() {
        XCTAssertNil(makeEvent("ls"))
        XCTAssertNil(makeEvent("pwd"))
        XCTAssertNil(makeEvent("cd /tmp"))
        XCTAssertNil(makeEvent("open README.md"))
    }

    func testGitCommandClassifiesAsGit() throws {
        let event = try XCTUnwrap(makeEvent("git status"))

        XCTAssertEqual(event.kind, .git)
        XCTAssertEqual(event.status, .running)
        XCTAssertEqual(event.command, "git status")
        XCTAssertFalse(event.isPersistent)
    }

    func testDownloadCommandsClassifyAsDownload() throws {
        XCTAssertEqual(try XCTUnwrap(makeEvent("npm install")).kind, .download)
        XCTAssertEqual(try XCTUnwrap(makeEvent("curl https://example.com")).kind, .download)
        XCTAssertEqual(try XCTUnwrap(makeEvent("wget https://example.com/archive.zip")).kind, .download)
    }

    func testSwiftTestClassifiesAsTest() throws {
        XCTAssertEqual(try XCTUnwrap(makeEvent("swift test")).kind, .test)
    }

    func testPytestClassifiesAsTest() throws {
        XCTAssertEqual(try XCTUnwrap(makeEvent("pytest -q")).kind, .test)
    }

    func testJestClassifiesAsTest() throws {
        XCTAssertEqual(try XCTUnwrap(makeEvent("jest --runInBand")).kind, .test)
    }

    func testVitestClassifiesAsTestInsteadOfPackage() throws {
        XCTAssertEqual(try XCTUnwrap(makeEvent("vitest run")).kind, .test)
    }

    func testBuildCommandsClassifyAsBuild() throws {
        XCTAssertEqual(try XCTUnwrap(makeEvent("xcodebuild -scheme NotchTerminal")).kind, .build)
        XCTAssertEqual(try XCTUnwrap(makeEvent("cargo build")).kind, .build)
        XCTAssertEqual(try XCTUnwrap(makeEvent("cmake --build .")).kind, .build)
    }

    func testPackageCommandsClassifyAsPackage() throws {
        XCTAssertEqual(try XCTUnwrap(makeEvent("npm run dev")).kind, .package)
        XCTAssertEqual(try XCTUnwrap(makeEvent("pnpm add react")).kind, .package)
        XCTAssertEqual(try XCTUnwrap(makeEvent("vite")).kind, .package)
        XCTAssertEqual(try XCTUnwrap(makeEvent("vite preview")).kind, .package)
    }

    func testPersistentCommandsAreMarkedPersistent() throws {
        XCTAssertTrue(try XCTUnwrap(makeEvent("npm run dev")).isPersistent)
        XCTAssertTrue(try XCTUnwrap(makeEvent("next dev")).isPersistent)
        XCTAssertTrue(try XCTUnwrap(makeEvent("vite")).isPersistent)
        XCTAssertFalse(try XCTUnwrap(makeEvent("npm test")).isPersistent)
    }

    func testNormalizationIgnoresKnownPrefixesAndAssignments() throws {
        let event = try XCTUnwrap(makeEvent("FOO=1 BAR=2 sudo env nohup time command /usr/local/bin/npm run dev"))

        XCTAssertEqual(event.kind, .package)
        XCTAssertEqual(event.command, "FOO=1 BAR=2 sudo env nohup time command /usr/local/bin/npm run dev")
        XCTAssertTrue(event.isPersistent)
    }

    func testAbsolutePathAndToolAliasesStillClassifyCorrectly() throws {
        XCTAssertEqual(try XCTUnwrap(makeEvent("/usr/bin/git status --short")).kind, .git)
        XCTAssertEqual(try XCTUnwrap(makeEvent("/opt/homebrew/bin/pytest tests")).kind, .test)
        XCTAssertEqual(try XCTUnwrap(makeEvent("next dev --turbo")).kind, .package)
    }

    func testTrivialCommandsWithPrefixesRemainIgnored() {
        XCTAssertNil(makeEvent("sudo ls"))
        XCTAssertNil(makeEvent("FOO=1 env pwd"))
        XCTAssertNil(makeEvent("command echo hello"))
    }

    func testUnknownCommandFallsBackToGeneric() throws {
        let event = try XCTUnwrap(makeEvent("/opt/tools/custom-cli do-work"))

        XCTAssertEqual(event.kind, .generic)
        XCTAssertFalse(event.isPersistent)
    }

    func testCompletionEventPreservesIdentityFieldsAndClearsPersistence() throws {
        let running = try XCTUnwrap(makeEvent("npm run dev"))

        let completed = TerminalCommandOrbClassifier.makeCompletionEvent(from: running, status: .success)

        XCTAssertEqual(completed.displayID, running.displayID)
        XCTAssertEqual(completed.terminalNumber, running.terminalNumber)
        XCTAssertEqual(completed.kind, running.kind)
        XCTAssertEqual(completed.command, running.command)
        XCTAssertEqual(completed.status, .success)
        XCTAssertFalse(completed.isPersistent)
    }

    private func makeEvent(_ command: String) -> TerminalCommandOrbEvent? {
        TerminalCommandOrbClassifier.makeEvent(
            command: command,
            displayID: displayID,
            terminalNumber: terminalNumber
        )
    }
}
