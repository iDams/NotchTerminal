import XCTest
@testable import NotchTerminal

final class ProjectContextResolverTests: XCTestCase {
    func testResolveFindsNearestAncestorWithProjectMarkers() throws {
        let root = makeTempDirectory()
        let project = root.appendingPathComponent("SampleProject", isDirectory: true)
        let sources = project.appendingPathComponent("Sources/App", isDirectory: true)

        try FileManager.default.createDirectory(at: sources, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: project.appendingPathComponent("Package.swift").path, contents: Data())

        let context = ProjectContextResolver.resolve(from: sources.path)

        XCTAssertEqual(context, ProjectContext(rootPath: project.path, displayName: "SampleProject"))
    }

    func testResolveSupportsGitRepositoriesWithoutStackManifest() throws {
        let root = makeTempDirectory()
        let repo = root.appendingPathComponent("Repo", isDirectory: true)
        try FileManager.default.createDirectory(at: repo, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: repo.appendingPathComponent(".git"), withIntermediateDirectories: true)

        let context = ProjectContextResolver.resolve(from: repo.path)

        XCTAssertEqual(context, ProjectContext(rootPath: repo.path, displayName: "Repo"))
    }

    func testResolveReturnsNilForNonProjectFolders() throws {
        let root = makeTempDirectory()
        let plain = root.appendingPathComponent("Plain", isDirectory: true)
        try FileManager.default.createDirectory(at: plain, withIntermediateDirectories: true)

        XCTAssertNil(ProjectContextResolver.resolve(from: plain.path))
    }

    func testResolveSupportsXcodeProjectMarkerInAncestor() throws {
        let root = makeTempDirectory()
        let project = root.appendingPathComponent("DesktopApp", isDirectory: true)
        let nested = project.appendingPathComponent("Sources/UI/Components", isDirectory: true)

        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: project.appendingPathComponent("DesktopApp.xcodeproj").path, contents: Data())

        let context = ProjectContextResolver.resolve(from: nested.path)

        XCTAssertEqual(context, ProjectContext(rootPath: project.path, displayName: "DesktopApp"))
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
