import Foundation

enum NotchCommandOrbLogic {
    struct QueueUpdate {
        let shouldIgnore: Bool
        let activeEvent: TerminalCommandOrbEvent?
        let displayedEvent: TerminalCommandOrbEvent?
        let queuedEvents: [TerminalCommandOrbEvent]
    }

    static func enqueue(
        event: TerminalCommandOrbEvent,
        isStartupOrbEnabled: Bool,
        isNotchEnabled: Bool,
        existingQueue: [TerminalCommandOrbEvent],
        activeEvent: TerminalCommandOrbEvent?,
        displayedEvent: TerminalCommandOrbEvent?
    ) -> QueueUpdate {
        guard isStartupOrbEnabled, isNotchEnabled else {
            return QueueUpdate(
                shouldIgnore: true,
                activeEvent: activeEvent,
                displayedEvent: displayedEvent,
                queuedEvents: existingQueue
            )
        }

        var nextActive = activeEvent
        if event.status != .running, activeEvent?.terminalNumber == event.terminalNumber {
            nextActive = nil
        }

        if event.isPersistent && event.status == .running {
            return QueueUpdate(
                shouldIgnore: false,
                activeEvent: event,
                displayedEvent: displayedEvent,
                queuedEvents: existingQueue
            )
        }

        var nextQueue = existingQueue
        nextQueue.append(event)

        if displayedEvent == nil {
            return QueueUpdate(
                shouldIgnore: false,
                activeEvent: nextActive,
                displayedEvent: nextQueue.first,
                queuedEvents: Array(nextQueue.dropFirst())
            )
        }

        return QueueUpdate(
            shouldIgnore: false,
            activeEvent: nextActive,
            displayedEvent: displayedEvent,
            queuedEvents: nextQueue
        )
    }

    static func dismiss(displayedEvent: TerminalCommandOrbEvent?, queue: [TerminalCommandOrbEvent]) -> QueueUpdate {
        guard displayedEvent != nil else {
            return QueueUpdate(
                shouldIgnore: true,
                activeEvent: nil,
                displayedEvent: nil,
                queuedEvents: queue
            )
        }

        if let next = queue.first {
            return QueueUpdate(
                shouldIgnore: false,
                activeEvent: nil,
                displayedEvent: next,
                queuedEvents: Array(queue.dropFirst())
            )
        }

        return QueueUpdate(
            shouldIgnore: false,
            activeEvent: nil,
            displayedEvent: nil,
            queuedEvents: []
        )
    }
}
