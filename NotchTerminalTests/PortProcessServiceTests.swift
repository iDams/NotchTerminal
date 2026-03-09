import XCTest
@testable import NotchTerminal

final class PortProcessServiceTests: XCTestCase {
    func testParseLsofMachineOutputIgnoresDuplicateEntries() {
        let raw = """
        p123
        cnode
        n*:5173
        n*:5173
        n127.0.0.1:5173
        """

        let ports = PortProcessService.parseLsofMachineOutput(raw)

        XCTAssertEqual(ports.count, 2)
        XCTAssertTrue(ports.contains(OpenPortEntry(pid: 123, port: 5173, command: "node", endpoint: "*:5173")))
        XCTAssertTrue(ports.contains(OpenPortEntry(pid: 123, port: 5173, command: "node", endpoint: "127.0.0.1:5173")))
    }

    func testParseLsofMachineOutputSkipsIncompleteRecords() {
        let raw = """
        cnode
        n*:5173
        p456
        ninvalid-endpoint
        p789
        cpython
        n127.0.0.1:8000
        """

        let ports = PortProcessService.parseLsofMachineOutput(raw)

        XCTAssertEqual(ports, [
            OpenPortEntry(pid: 789, port: 8000, command: "python", endpoint: "127.0.0.1:8000")
        ])
    }

    func testParseLsofMachineOutputFallsBackToUnknownCommandUntilCommandFieldArrives() {
        let raw = """
        p900
        n*:6000
        cjava
        n*:6001
        """

        let ports = PortProcessService.parseLsofMachineOutput(raw)

        XCTAssertEqual(ports.count, 2)
        XCTAssertTrue(ports.contains(OpenPortEntry(pid: 900, port: 6000, command: "unknown", endpoint: "*:6000")))
        XCTAssertTrue(ports.contains(OpenPortEntry(pid: 900, port: 6001, command: "java", endpoint: "*:6001")))
    }

    func testParsePortHandlesTypicalEndpoints() {
        XCTAssertEqual(PortProcessService.parsePort(from: "*:5173"), 5173)
        XCTAssertEqual(PortProcessService.parsePort(from: "127.0.0.1:9229"), 9229)
        XCTAssertEqual(PortProcessService.parsePort(from: "127.0.0.1:3000->127.0.0.1:52000"), 3000)
    }

    func testParsePortRejectsInvalidEndpoints() {
        XCTAssertNil(PortProcessService.parsePort(from: "localhost"))
        XCTAssertNil(PortProcessService.parsePort(from: "127.0.0.1:abc"))
        XCTAssertNil(PortProcessService.parsePort(from: ""))
    }

    func testDevHeuristicCoversKnownPortsAndProcessHints() {
        XCTAssertTrue(OpenPortEntry(pid: 1, port: 3000, command: "custom", endpoint: "*:3000").isLikelyDev)
        XCTAssertTrue(OpenPortEntry(pid: 2, port: 65000, command: "redis-server", endpoint: "127.0.0.1:65000").isLikelyDev)
        XCTAssertFalse(OpenPortEntry(pid: 3, port: 80, command: "launchd", endpoint: "*:80").isLikelyDev)
    }
}
