import AppKit
import SwiftUI

@MainActor
final class OpenPortsOverviewPresenter {
    private var windowController: NSWindowController?

    func present(service: OpenPortsOverviewService) {
        let hostingController = NSHostingController(rootView: OpenPortsOverviewView(service: service))

        if let windowController {
            windowController.contentViewController = hostingController
            windowController.window?.center()
            windowController.showWindow(nil)
            windowController.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 960, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "openPorts.title".localized
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unified
        window.center()

        let controller = NSWindowController(window: window)
        windowController = controller
        controller.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
