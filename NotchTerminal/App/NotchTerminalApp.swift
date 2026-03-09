import SwiftUI
import AppKit
import QuartzCore
import MetalKit
import Combine
import SwiftData

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
    private var modelContainer: ModelContainer?
    private var uiTestWindow: NSWindow?
    private let persistenceHealth = PersistenceHealth.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupEditMenu()
        if UITestSupport.isEnabled {
            _ = NSApp.setActivationPolicy(.regular)
        } else {
            applyDockIconPreference()
        }
        userDefaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyDockIconPreference()
        }
        
        do {
            modelContainer = try ModelContainer(for: TerminalSession.self)
            persistenceHealth.markAvailable()
        } catch {
            let details = PersistenceHealth.userFacingDetails(for: error)
            persistenceHealth.markUnavailable(details: details)
            NSLog("Failed to initialize SwiftData container: %@", details)
            if !UITestSupport.isEnabled {
                DispatchQueue.main.async { [weak self] in
                    self?.presentPersistenceUnavailableAlert(details: details)
                }
            }
        }
        
        if !UITestSupport.isEnabled {
            notchController = NotchOverlayController(modelContext: modelContainer?.mainContext)
            notchController?.start()
        }

        if UITestSupport.isEnabled {
            NSApp.activate(ignoringOtherApps: true)
            DispatchQueue.main.async {
                self.presentUITestWindow()
            }
        }
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
        let showDockIcon = UserDefaults.standard.bool(forKey: AppPreferences.Keys.showDockIcon)
        _ = NSApp.setActivationPolicy(showDockIcon ? .regular : .accessory)
        if showDockIcon {
            NSApp.activate(ignoringOtherApps: false)
        }
    }

    @MainActor
    private func presentUITestWindow() {
        if let uiTestWindow {
            uiTestWindow.makeKeyAndOrderFront(nil)
            return
        }

        let hostingController = NSHostingController(rootView: SettingsView())
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "NotchTerminal UITest"
        window.contentViewController = hostingController
        window.center()
        window.makeKeyAndOrderFront(nil)
        uiTestWindow = window
    }

    @MainActor
    private func presentPersistenceUnavailableAlert(details: String) {
        let alert = NSAlert()
        alert.messageText = "persistence.alert.title".localized
        alert.informativeText = String(format: "persistence.alert.message".localized, details)
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
