import XCTest
@testable import NotchTerminal

final class NotchCommandOrbLogicTests: XCTestCase {
    func testEnqueueIgnoresEventsWhenStartupOrbOrNotchDisabled() {
        let event = makeEvent(status: .running)

        let disabledStartup = NotchCommandOrbLogic.enqueue(
            event: event,
            isStartupOrbEnabled: false,
            isNotchEnabled: true,
            existingQueue: [],
            activeEvent: nil,
            displayedEvent: nil
        )
        let disabledNotch = NotchCommandOrbLogic.enqueue(
            event: event,
            isStartupOrbEnabled: true,
            isNotchEnabled: false,
            existingQueue: [],
            activeEvent: nil,
            displayedEvent: nil
        )

        XCTAssertTrue(disabledStartup.shouldIgnore)
        XCTAssertTrue(disabledNotch.shouldIgnore)
    }

    func testEnqueuePersistentRunningEventBecomesActive() {
        let event = makeEvent(status: .running, persistent: true)

        let update = NotchCommandOrbLogic.enqueue(
            event: event,
            isStartupOrbEnabled: true,
            isNotchEnabled: true,
            existingQueue: [],
            activeEvent: nil,
            displayedEvent: nil
        )

        XCTAssertFalse(update.shouldIgnore)
        XCTAssertEqual(update.activeEvent?.command, event.command)
        XCTAssertNil(update.displayedEvent)
        XCTAssertTrue(update.queuedEvents.isEmpty)
    }

    func testEnqueueNonPersistentEventDisplaysImmediatelyWhenIdle() {
        let event = makeEvent(status: .running, persistent: false)

        let update = NotchCommandOrbLogic.enqueue(
            event: event,
            isStartupOrbEnabled: true,
            isNotchEnabled: true,
            existingQueue: [],
            activeEvent: nil,
            displayedEvent: nil
        )

        XCTAssertEqual(update.displayedEvent?.command, event.command)
        XCTAssertTrue(update.queuedEvents.isEmpty)
    }

    func testEnqueueAppendsToQueueWhenAnotherEventIsDisplayed() {
        let current = makeEvent(command: "current", status: .running, persistent: false)
        let next = makeEvent(command: "next", status: .success, persistent: false)

        let update = NotchCommandOrbLogic.enqueue(
            event: next,
            isStartupOrbEnabled: true,
            isNotchEnabled: true,
            existingQueue: [],
            activeEvent: nil,
            displayedEvent: current
        )

        XCTAssertEqual(update.displayedEvent?.command, current.command)
        XCTAssertEqual(update.queuedEvents.map(\.command), ["next"])
    }

    func testDismissAdvancesToNextQueuedEvent() {
        let displayed = makeEvent(command: "first", status: .running, persistent: false)
        let queued = makeEvent(command: "second", status: .success, persistent: false)

        let update = NotchCommandOrbLogic.dismiss(displayedEvent: displayed, queue: [queued])

        XCTAssertEqual(update.displayedEvent?.command, "second")
        XCTAssertTrue(update.queuedEvents.isEmpty)
    }

    private func makeEvent(
        command: String = "npm run dev",
        status: TerminalCommandOrbStatus,
        persistent: Bool = false
    ) -> TerminalCommandOrbEvent {
        TerminalCommandOrbEvent(
            displayID: 1,
            terminalNumber: 2,
            kind: .generic,
            status: status,
            command: command,
            duration: 1.5,
            isPersistent: persistent
        )
    }
}
