import XCTest
@testable import NotchTerminal

final class TerminalWindowPresentationLogicTests: XCTestCase {
    func testItemsSortByWindowNumber() {
        let items = TerminalWindowPresentationLogic.items(from: [
            makeSnapshot(number: 3, title: "three"),
            makeSnapshot(number: 1, title: "one"),
            makeSnapshot(number: 2, title: "two")
        ])

        XCTAssertEqual(items.map(\.number), [1, 2, 3])
        XCTAssertEqual(items.map(\.title), ["one", "two", "three"])
    }

    func testItemPreservesPresentationFields() {
        let snapshot = makeSnapshot(
            number: 4,
            title: "codex",
            projectName: "NotchTerminal",
            workingDirectory: "/tmp/project",
            lastCommand: "swift test",
            isMinimized: true,
            isAlwaysOnTop: true,
            isActive: true
        )

        let item = TerminalWindowPresentationLogic.item(from: snapshot)

        XCTAssertEqual(item.number, 4)
        XCTAssertEqual(item.title, "codex")
        XCTAssertEqual(item.projectName, "NotchTerminal")
        XCTAssertEqual(item.workingDirectory, "/tmp/project")
        XCTAssertEqual(item.lastCommand, "swift test")
        XCTAssertTrue(item.isMinimized)
        XCTAssertTrue(item.isAlwaysOnTop)
        XCTAssertTrue(item.isActive)
    }

    private func makeSnapshot(
        number: Int,
        title: String,
        projectName: String? = nil,
        workingDirectory: String = "/tmp",
        lastCommand: String? = nil,
        isMinimized: Bool = false,
        isAlwaysOnTop: Bool = false,
        isActive: Bool = false
    ) -> TerminalWindowPresentationSnapshot {
        TerminalWindowPresentationSnapshot(
            id: UUID(),
            number: number,
            displayID: 1,
            title: title,
            projectName: projectName,
            workingDirectory: workingDirectory,
            lastCommand: lastCommand,
            icon: nil,
            preview: nil,
            isMinimized: isMinimized,
            isAlwaysOnTop: isAlwaysOnTop,
            isActive: isActive
        )
    }
}
