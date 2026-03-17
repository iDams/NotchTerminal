import AppKit
import SwiftUI

@MainActor
final class AIControlCenterWindowController: NSObject, NSWindowDelegate {
    private static let autosaveName = "AIControlCenterWindow"

    private let baseMinimumWindowSize = NSSize(width: 820, height: 460)
    private var window: NSWindow?

    func show(on screen: NSScreen?) {
        guard AIFeatureAvailability.isEnabled() else { return }

        let targetScreen = screen ?? NSScreen.main ?? NSScreen.screens.first
        guard let targetScreen else { return }

        if let window {
            constrainWindow(window: window, to: targetScreen, recenterIfNeeded: false)
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingController = NSHostingController(rootView: AIControlCenterView())
        let initialSize = idealWindowSize(for: targetScreen)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: initialSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "NotchTerminalAgent"
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unified
        window.isMovableByWindowBackground = true
        window.delegate = self
        window.setFrameAutosaveName(Self.autosaveName)

        if !window.setFrameUsingName(Self.autosaveName) {
            constrainWindow(window: window, to: targetScreen, recenterIfNeeded: true)
        } else {
            constrainWindow(window: window, to: targetScreen, recenterIfNeeded: false)
        }

        self.window = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }

    private func constrainWindow(window: NSWindow, to screen: NSScreen, recenterIfNeeded: Bool) {
        let availableFrame = screen.visibleFrame.insetBy(dx: 24, dy: 24)
        let minimumWindowSize = NSSize(
            width: min(baseMinimumWindowSize.width, availableFrame.width),
            height: min(baseMinimumWindowSize.height, availableFrame.height)
        )

        window.minSize = minimumWindowSize

        let fittedSize = NSSize(
            width: min(max(window.frame.width, minimumWindowSize.width), availableFrame.width),
            height: min(max(window.frame.height, minimumWindowSize.height), availableFrame.height)
        )

        var origin = window.frame.origin

        if recenterIfNeeded {
            origin = CGPoint(
                x: availableFrame.midX - fittedSize.width / 2,
                y: availableFrame.midY - fittedSize.height / 2
            )
        } else {
            origin.x = min(max(origin.x, availableFrame.minX), availableFrame.maxX - fittedSize.width)
            origin.y = min(max(origin.y, availableFrame.minY), availableFrame.maxY - fittedSize.height)
        }

        let frame = NSRect(origin: origin, size: fittedSize)

        window.setFrame(frame, display: true)
    }

    private func idealWindowSize(for screen: NSScreen) -> NSSize {
        let availableFrame = screen.visibleFrame.insetBy(dx: 24, dy: 24)
        return NSSize(
            width: min(max(availableFrame.width * 0.68, 940), 1_180),
            height: min(max(availableFrame.height * 0.66, 560), 760)
        )
    }
}
