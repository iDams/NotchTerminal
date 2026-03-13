import XCTest
@testable import NotchTerminal

final class TerminalWindowContextResolverTests: XCTestCase {
    func testRestoredBrandingIgnoresDefaultAndUnknownTitles() {
        XCTAssertNil(TerminalWindowContextResolver.restoredBranding(for: nil).title)
        XCTAssertNil(TerminalWindowContextResolver.restoredBranding(for: makeSession(displayTitle: "NotchTerminal")).title)
        XCTAssertNil(TerminalWindowContextResolver.restoredBranding(for: makeSession(displayTitle: "swift build")).title)
    }

    func testRestoredBrandingResolvesKnownCLIWindowTitle() {
        let branding = TerminalWindowContextResolver.restoredBranding(for: makeSession(displayTitle: " codex "))

        XCTAssertEqual(branding.title, "codex")
    }

    func testNormalizedWorkingDirectoryFallsBackForInvalidInputs() {
        let fallback = "/tmp/fallback-home"

        XCTAssertEqual(TerminalWindowContextResolver.normalizedWorkingDirectory(nil, fallback: fallback), fallback)
        XCTAssertEqual(TerminalWindowContextResolver.normalizedWorkingDirectory("   ", fallback: fallback), fallback)
        XCTAssertEqual(TerminalWindowContextResolver.normalizedWorkingDirectory("/", fallback: fallback), fallback)
        XCTAssertEqual(
            TerminalWindowContextResolver.normalizedWorkingDirectory("/definitely/not/real", fallback: fallback),
            fallback
        )
    }

    func testNormalizedWorkingDirectoryPreservesRealDirectory() {
        let directory = FileManager.default.temporaryDirectory.path

        XCTAssertEqual(TerminalWindowContextResolver.normalizedWorkingDirectory(directory), directory)
    }

    func testResolvedProjectContextPrefersFilesystemResolution() throws {
        let root = makeTempDirectory()
        let project = root.appendingPathComponent("SampleProject", isDirectory: true)
        let nested = project.appendingPathComponent("Sources/App", isDirectory: true)

        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: project.appendingPathComponent("Package.swift").path, contents: Data())

        let session = makeSession(
            displayTitle: "NotchTerminal",
            projectRootPath: "/tmp/fallback-root",
            projectName: "FallbackName"
        )

        let context = TerminalWindowContextResolver.resolvedProjectContext(for: nested.path, session: session)

        XCTAssertEqual(context, ProjectContext(rootPath: project.path, displayName: "SampleProject"))
    }

    func testResolvedProjectContextFallsBackToSessionMetadata() {
        let session = makeSession(
            displayTitle: "NotchTerminal",
            projectRootPath: "/tmp/restored-root",
            projectName: "Restored Project"
        )

        let context = TerminalWindowContextResolver.resolvedProjectContext(
            for: "/definitely/not/real",
            session: session
        )

        XCTAssertEqual(context, ProjectContext(rootPath: "/tmp/restored-root", displayName: "Restored Project"))
    }

    private func makeSession(
        displayTitle: String,
        projectRootPath: String? = nil,
        projectName: String? = nil
    ) -> TerminalSession {
        TerminalSession(
            workingDirectory: NSHomeDirectory(),
            displayTitle: displayTitle,
            projectRootPath: projectRootPath,
            projectName: projectName
        )
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
