import SwiftUI
import AppKit
import QuartzCore
import MetalKit
import Combine

@main
struct NotchTerminalApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var notchController: NotchOverlayController?
    private var userDefaultsObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupEditMenu()
        applyDockIconPreference()
        userDefaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyDockIconPreference()
        }
        notchController = NotchOverlayController()
        notchController?.start()
    }

    private func setupEditMenu() {
        let mainMenu = NSMenu()
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        
        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu
        
        // Standard macOS Edit actions. Because NotchTerminal is a LSUIElement (Accessory),
        // we must manually provide these for Cmd+C/V/A to be routed to the focused TerminalView.
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        
        NSApp.mainMenu = mainMenu
    }

    func applicationWillTerminate(_ notification: Notification) {
        notchController?.stop()
        if let userDefaultsObserver {
            NotificationCenter.default.removeObserver(userDefaultsObserver)
        }
    }

    private func applyDockIconPreference() {
        let showDockIcon = UserDefaults.standard.bool(forKey: "showDockIcon")
        _ = NSApp.setActivationPolicy(showDockIcon ? .regular : .accessory)
        if showDockIcon {
            if let appLogo = NSImage(named: "AppLogo") {
                NSApp.applicationIconImage = appLogo
            }
            NSApp.activate(ignoringOtherApps: false)
        }
    }
}
