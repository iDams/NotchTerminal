import SwiftUI
import AppKit
import QuartzCore
import MetalKit
import Combine
import SwiftData
import UserNotifications

@main
struct NotchTerminalApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        // Machine Daemon Mode (launched by launchd)
        if let idx = CommandLine.arguments.firstIndex(of: "--run-cronjob"), idx + 1 < CommandLine.arguments.count {
            let jobId = CommandLine.arguments[idx + 1]
            Task {
                await AICronjobManager.executeBackgroundJob(id: jobId)
                // Give UNUserNotificationCenter XPC messages time to flush before killing process
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                exit(0)
            }
            RunLoop.main.run()
        }
    }

    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var notchController: NotchOverlayController?
    private var userDefaultsObserver: NSObjectProtocol?
    private var modelContainer: ModelContainer?
    private var uiTestWindow: NSWindow?
    private let persistenceHealth = PersistenceHealth.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupEditMenu()
        requestNotificationPermissions()
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
            Task { @MainActor [weak self] in
                self?.applyDockIconPreference()
            }
        }
        
        do {
            modelContainer = try ModelContainer(for: TerminalSession.self)
            persistenceHealth.markAvailable()
            _ = AICronjobManager.shared // Start AI loop
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
        // we must manually provide these for Cmd+C/V/Z/A to be routed to the focused View.
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
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
        let policy: NSApplication.ActivationPolicy = showDockIcon ? .regular : .accessory
        if NSApp.activationPolicy() != policy {
            NSApp.setActivationPolicy(policy)
            if showDockIcon {
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
    
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                print("✅ [AppDelegate] Notification permissions granted.")
            } else if let error = error {
                print("❌ [AppDelegate] Notification permissions error: \(error.localizedDescription)")
            }
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
        alert.addButton(withTitle: "Reset Data Store")
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            resetDataStore()
        }
    }
    
    private func resetDataStore() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let storeFiles = ["default.store", "default.store-shm", "default.store-wal"]
        
        for file in storeFiles {
            let url = appSupport.appendingPathComponent(file)
            try? FileManager.default.removeItem(at: url)
        }
        
        // Relaunch the app
        let bundlePath = Bundle.main.bundlePath
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-n", bundlePath]
        try? task.run()
        
        NSApp.terminate(nil)
    }
}
