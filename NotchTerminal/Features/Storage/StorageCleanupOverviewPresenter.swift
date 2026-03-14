import AppKit
import SwiftUI

@MainActor
final class StorageCleanupOverviewPresenter {
    private var windowController: NSWindowController?

    func present(service: StorageCleanupService) {
        let hostingController = NSHostingController(rootView: StorageCleanupOverviewView(service: service))

        if let windowController {
            windowController.contentViewController = hostingController
            windowController.window?.center()
            windowController.showWindow(nil)
            windowController.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1_040, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "storage.menu.title".localized
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unified
        window.center()

        let controller = NSWindowController(window: window)
        windowController = controller
        window.center()
        controller.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
