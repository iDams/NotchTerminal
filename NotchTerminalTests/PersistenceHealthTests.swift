import XCTest
@testable import NotchTerminal

@MainActor
final class PersistenceHealthTests: XCTestCase {
    func testMarkUnavailableStoresProvidedDetails() {
        let health = PersistenceHealth()

        health.markUnavailable(details: "Disk is read-only")

        XCTAssertFalse(health.isAvailable)
        XCTAssertEqual(health.failureDetails, "Disk is read-only")
    }

    func testMarkUnavailableFallsBackWhenDetailsAreBlank() {
        let health = PersistenceHealth()

        health.markUnavailable(details: "   ")

        XCTAssertEqual(health.failureDetails, "Unknown SwiftData error.")
    }

    func testMarkAvailableClearsFailureState() {
        let health = PersistenceHealth()
        health.markUnavailable(details: "Broken store")

        health.markAvailable()

        XCTAssertTrue(health.isAvailable)
        XCTAssertNil(health.failureDetails)
    }
}
