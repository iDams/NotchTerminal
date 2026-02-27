import XCTest
@testable import NotchTerminal

final class OpenPortsLogicTests: XCTestCase {
    func testParseLsofMachineOutputParsesMultipleEntries() {
        let raw = """
        p123
        cnode
        n*:5173
        n127.0.0.1:9229
        p456
        cpostgres
        n127.0.0.1:5432
        """

        let ports = PortProcessService.parseLsofMachineOutput(raw)

        XCTAssertEqual(ports.count, 3)
        XCTAssertTrue(ports.contains(OpenPortEntry(pid: 123, port: 5173, command: "node", endpoint: "*:5173")))
        XCTAssertTrue(ports.contains(OpenPortEntry(pid: 123, port: 9229, command: "node", endpoint: "127.0.0.1:9229")))
        XCTAssertTrue(ports.contains(OpenPortEntry(pid: 456, port: 5432, command: "postgres", endpoint: "127.0.0.1:5432")))
    }

    func testOpenPortEntryLikelyDevHeuristics() {
        let byPort = OpenPortEntry(pid: 1, port: 5173, command: "random", endpoint: "*:5173")
        XCTAssertTrue(byPort.isLikelyDev)

        let byCommand = OpenPortEntry(pid: 2, port: 65000, command: "node", endpoint: "127.0.0.1:65000")
        XCTAssertTrue(byCommand.isLikelyDev)

        let nonDev = OpenPortEntry(pid: 3, port: 80, command: "system_service", endpoint: "*:80")
        XCTAssertFalse(nonDev.isLikelyDev)
    }

    func testAppPreferencesDefaultsSmoke() {
        XCTAssertEqual(AppPreferences.Defaults.notchDockingSensitivity, 80)
        XCTAssertEqual(AppPreferences.Defaults.autoOpenOnHoverDelay, 0.5)
        XCTAssertEqual(AppPreferences.Defaults.terminalDefaultWidth, 640)
        XCTAssertEqual(AppPreferences.Defaults.terminalDefaultHeight, 400)
    }
}
