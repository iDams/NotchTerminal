import SwiftUI
import AppKit
import QuartzCore
import MetalKit
import Combine
import SwiftData
import UserNotifications
import Observation

@main
struct NotchTerminalApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        // Machine Daemon Mode (launched by launchd)
        if let idx = CommandLine.arguments.firstIndex(of: "--run-cronjob"), idx + 1 < CommandLine.arguments.count {
            let jobId = CommandLine.arguments[idx + 1]
            Task {
                guard AIFeatureAvailability.isEnabled() else {
                    exit(0)
                }
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
        .commands {
            NotchTerminalAppCommands(appDelegate: appDelegate)
        }
    }
}

private func providerIDsForKeychainMigration(defaults: UserDefaults = .standard) -> [UUID] {
    if let rawProviders = defaults.string(forKey: AppPreferences.Keys.aiProvidersData),
       let providers = AIProviderList(rawValue: rawProviders)?.providers {
        return providers.map(\.id)
    }

    return AppPreferences.Defaults.aiProvidersData.providers.map(\.id)
}

private struct NotchTerminalAppCommands: Commands {
    let appDelegate: AppDelegate

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About \(AppMetadata.displayName)") {
                appDelegate.openAboutInSettings()
            }
        }

        CommandGroup(after: .appInfo) {
            Button("action.newTerminal".localized) {
                appDelegate.createTerminalFromAppMenu(nil)
            }
            .keyboardShortcut("n", modifiers: .command)
        }

        CommandGroup(replacing: .appSettings) {
            Button("action.settings".localized + "...") {
                appDelegate.openSettingsWindow()
            }
            .keyboardShortcut(",", modifiers: .command)
        }
    }
}

private struct StatusMenuSettingsLinkView: View {
    var body: some View {
        SettingsLink {
            HStack {
                Text("action.settings".localized)
                Spacer()
                Text("\u{2318},")
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(width: 180, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}

private extension View {
    func hostingView() -> NSView {
        let host = NSHostingView(rootView: self)
        host.frame.size = host.fittingSize
        return host
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var notchController: NotchOverlayController?
    private var userDefaultsObserver: NSObjectProtocol?
    private var modelContainer: ModelContainer?
    private var uiTestWindow: NSWindow?
    private var statusItem: NSStatusItem?
    private let persistenceHealth = PersistenceHealth.shared
    private let storageCleanupService = StorageCleanupService.shared
    private let permissionCoordinator = AppPermissionCoordinator.shared
    private var aiRuntimeStarted = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        let providerIDs = providerIDsForKeychainMigration()
        KeychainService.migrateAPIKeysForBackgroundAccess(providerIDs: providerIDs)

        DispatchQueue.main.async { [weak self] in
            self?.setupEditMenu()
        }
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
                self?.rebuildStatusItemMenu()
                self?.syncAIFeatureRuntime()
            }
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

        syncAIFeatureRuntime()
        
        if !UITestSupport.isEnabled {
            notchController = NotchOverlayController(modelContext: modelContainer?.mainContext)
            notchController?.start()
            setupStatusItem()
        }

        if UITestSupport.isEnabled {
            NSApp.activate(ignoringOtherApps: true)
            DispatchQueue.main.async {
                self.presentUITestWindow()
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            Task { @MainActor [weak self] in
                await self?.presentInitialPermissionsIfNeeded()
            }
        }
    }

    private func syncAIFeatureRuntime() {
        guard AIFeatureAvailability.isEnabled() else { return }
        guard !aiRuntimeStarted else { return }
        AICronjobManager.shared.startIfNeeded()
        aiRuntimeStarted = true
    }

    private func setupEditMenu() {
        let mainMenu = NSApp.mainMenu ?? NSMenu()
        let editMenuItem: NSMenuItem

        if let existingEditMenuItem = mainMenu.items.first(where: { $0.submenu?.title == "Edit" }) {
            editMenuItem = existingEditMenuItem
        } else {
            let item = NSMenuItem()
            mainMenu.addItem(item)
            editMenuItem = item
        }

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

        if NSApp.mainMenu !== mainMenu {
            NSApp.mainMenu = mainMenu
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        notchController?.stop()
        if let userDefaultsObserver {
            NotificationCenter.default.removeObserver(userDefaultsObserver)
        }
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
    }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        let newTerminalItem = NSMenuItem(
            title: "action.newTerminal".localized,
            action: #selector(createTerminalFromDockMenu(_:)),
            keyEquivalent: ""
        )
        newTerminalItem.target = self
        menu.addItem(newTerminalItem)
        return menu
    }

    private func setupStatusItem() {
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            let image = NSImage(named: "AppLogo")
            image?.size = NSSize(width: 18, height: 18)
            image?.isTemplate = false
            button.image = image
            button.imagePosition = .imageOnly
            button.toolTip = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "NotchTerminal"
        }

        statusItem = item
        rebuildStatusItemMenu()
    }

    private func rebuildStatusItemMenu() {
        guard let statusItem else { return }

        let menu = NSMenu()

        let newTerminalItem = NSMenuItem(
            title: "action.newTerminal".localized,
            action: #selector(createTerminalFromStatusItem(_:)),
            keyEquivalent: ""
        )
        newTerminalItem.image = NSImage(systemSymbolName: "plus.terminal", accessibilityDescription: nil)
        newTerminalItem.target = self
        menu.addItem(newTerminalItem)
        menu.addItem(.separator())

        let optionsItem = NSMenuItem(title: "menu.options".localized, action: nil, keyEquivalent: "")
        optionsItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        let optionsMenu = NSMenu(title: "menu.options".localized)
        let settingsItem = NSMenuItem()
        settingsItem.view = StatusMenuSettingsLinkView().hostingView()
        optionsMenu.addItem(settingsItem)
        menu.setSubmenu(optionsMenu, for: optionsItem)
        menu.addItem(optionsItem)
        menu.addItem(.separator())

        let storageItem = NSMenuItem(
            title: "storage.menu.title".localized,
            action: #selector(openStorageOverviewFromStatusItem(_:)),
            keyEquivalent: ""
        )
        storageItem.image = NSImage(systemSymbolName: "internaldrive", accessibilityDescription: nil)
        storageItem.target = self
        menu.addItem(storageItem)
        menu.addItem(.separator())

        let showAllWindowsItem = NSMenuItem(
            title: "action.showAllWindows".localized,
            action: #selector(showAllWindowsFromStatusItem(_:)),
            keyEquivalent: ""
        )
        showAllWindowsItem.image = NSImage(systemSymbolName: "macwindow.on.rectangle", accessibilityDescription: nil)
        showAllWindowsItem.target = self
        menu.addItem(showAllWindowsItem)

        let hideItem = NSMenuItem(
            title: "action.hide".localized,
            action: #selector(hideFromStatusItem(_:)),
            keyEquivalent: "h"
        )
        hideItem.image = NSImage(systemSymbolName: "eye.slash", accessibilityDescription: nil)
        hideItem.target = self
        menu.addItem(hideItem)

        let quitItem = NSMenuItem(
            title: "action.quit".localized,
            action: #selector(quitFromStatusItem(_:)),
            keyEquivalent: "q"
        )
        quitItem.image = NSImage(systemSymbolName: "power", accessibilityDescription: nil)
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
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

    @objc
    func createTerminalFromDockMenu(_ sender: Any?) {
        notchController?.openBlackWindowForCurrentInteractionScreen()
    }

    @objc
    func createTerminalFromAppMenu(_ sender: Any?) {
        notchController?.openBlackWindowForCurrentInteractionScreen()
    }

    func openAboutInSettings() {
        openSettings(selectedTab: .about)
    }

    func openSettingsWindow() {
        openSettings(selectedTab: nil)
    }

    private func openSettings(selectedTab: SettingsTab?) {
        if let selectedTab {
            SettingsNavigationCoordinator.request(tab: selectedTab)
        }

        if #available(macOS 13.0, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc
    private func createTerminalFromStatusItem(_ sender: Any?) {
        notchController?.openBlackWindow(on: statusItem?.button?.window?.screen)
    }

    @objc
    private func showAllWindowsFromStatusItem(_ sender: Any?) {
        notchController?.restoreAllWindows()
    }

    @objc
    private func openStorageOverviewFromStatusItem(_ sender: Any?) {
        storageCleanupService.showOverview()
    }

    @objc
    private func hideFromStatusItem(_ sender: Any?) {
        NSApp.hide(nil)
    }

    @objc
    private func quitFromStatusItem(_ sender: Any?) {
        NSApp.terminate(nil)
    }
    
    @MainActor
    private func presentInitialPermissionsIfNeeded() async {
        guard AIFeatureAvailability.isEnabled() else { return }

        await permissionCoordinator.refreshStatuses()
        guard permissionCoordinator.shouldPresentOnboarding else { return }

        await permissionCoordinator.requestMissingAIFeaturePermissions()
        await permissionCoordinator.refreshStatuses()

        if permissionCoordinator.statuses.values.contains(where: { !$0.isGranted }) {
            openSettingsWindow()
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
