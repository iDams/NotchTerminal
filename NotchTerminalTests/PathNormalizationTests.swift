import XCTest
@testable import NotchTerminal

@MainActor
final class PathNormalizationTests: XCTestCase {
    func testValidatedWorkingDirectoryPathFallsBackForEmptySlashAndMissingPaths() {
        let home = NSHomeDirectory()

        XCTAssertEqual(SwiftTermContainerView.validatedWorkingDirectoryPath(""), home)
        XCTAssertEqual(SwiftTermContainerView.validatedWorkingDirectoryPath("   "), home)
        XCTAssertEqual(SwiftTermContainerView.validatedWorkingDirectoryPath("/"), home)
        XCTAssertEqual(SwiftTermContainerView.validatedWorkingDirectoryPath("/definitely/not/a/real/path"), home)
    }

    func testValidatedWorkingDirectoryPathAcceptsRealDirectory() {
        let tempDirectory = FileManager.default.temporaryDirectory.path

        XCTAssertEqual(SwiftTermContainerView.validatedWorkingDirectoryPath(tempDirectory), tempDirectory)
    }

    func testParseDirectoryPathConvertsFileURLsAndDecodesPercentEscapes() {
        XCTAssertEqual(
            MetalBlackWindowsManager.parseDirectoryPath("file:///Users/testuser/Project%20Files"),
            "/Users/testuser/Project Files"
        )
        XCTAssertEqual(
            MetalBlackWindowsManager.parseDirectoryPath("file://localhost/Users/test/Desktop"),
            "/Users/test/Desktop"
        )
    }

    func testParseDirectoryPathLeavesPlainPathsUntouched() {
        XCTAssertEqual(
            MetalBlackWindowsManager.parseDirectoryPath("/Users/testuser/Documents/project/NotchTerminal"),
            "/Users/testuser/Documents/project/NotchTerminal"
        )
    }

    func testParseDirectoryPathHandlesMalformedFileURLsWithoutCrashing() {
        XCTAssertEqual(
            MetalBlackWindowsManager.parseDirectoryPath("file://bad host/Users/test/Space%20Dir"),
            "/Users/test/Space Dir"
        )
    }
}
