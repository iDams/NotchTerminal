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

    var body: some Scene {
        Settings {
            SettingsView()
        }
        .commands {
            NotchTerminalAppCommands(appDelegate: appDelegate)
        }
    }
}

private struct NotchTerminalAppCommands: Commands {
    let appDelegate: AppDelegate
    @Environment(\.openSettings) private var openSettings

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About \(AppMetadata.displayName)") {
                SettingsNavigationCoordinator.request(tab: .about)
                openSettings()
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
                openSettings()
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
    private var onboardingWindow: NSWindow?
    private var statusItem: NSStatusItem?
    private let persistenceHealth = PersistenceHealth.shared
    private let storageCleanupService = StorageCleanupService.shared
    private let openPortsOverviewService = OpenPortsOverviewService.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
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
                self?.applyStatusItemPreference()
                self?.applySlapDetectionPreference()
            }
        }
        
        do {
            modelContainer = try ModelContainer(for: TerminalSession.self)
            persistenceHealth.markAvailable()
        } catch {
            let details = PersistenceHealth.userFacingDetails(for: error)
            persistenceHealth.markUnavailable(details: details)
            // Re-enable for low-level startup diagnostics if persistence setup fails again.
            // NSLog("Failed to initialize SwiftData container: %@", details)
            if !UITestSupport.isEnabled {
                DispatchQueue.main.async { [weak self] in
                    self?.presentPersistenceUnavailableAlert(details: details)
                }
            }
        }

        if !UITestSupport.isEnabled {
            notchController = NotchOverlayController(modelContext: modelContainer?.mainContext)
            notchController?.start()
            applyStatusItemPreference()
            applySlapDetectionPreference()
            presentOnboardingIfNeeded()
        }

        if UITestSupport.isEnabled {
            NSApp.activate(ignoringOtherApps: true)
            DispatchQueue.main.async {
                self.presentUITestWindow()
            }
        }

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

    private func applyStatusItemPreference() {
        let showStatusItem = UserDefaults.standard.object(forKey: AppPreferences.Keys.showMenuBarShortcuts) as? Bool
            ?? AppPreferences.Defaults.showMenuBarShortcuts

        if showStatusItem {
            setupStatusItem()
        } else if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
    }

    private func setupStatusItem() {
        if statusItem != nil {
            rebuildStatusItemMenu()
            return
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

        let activePortsItem = NSMenuItem(
            title: "openPorts.title".localized,
            action: #selector(openActivePortsFromStatusItem(_:)),
            keyEquivalent: ""
        )
        activePortsItem.image = NSImage(systemSymbolName: "network", accessibilityDescription: nil)
        activePortsItem.target = self
        menu.addItem(activePortsItem)
        menu.addItem(.separator())

        let onboardingItem = NSMenuItem(
            title: "menu.onboarding".localized,
            action: #selector(openOnboardingFromStatusItem(_:)),
            keyEquivalent: ""
        )
        onboardingItem.image = NSImage(systemSymbolName: "sparkles.rectangle.stack", accessibilityDescription: nil)
        onboardingItem.target = self
        menu.addItem(onboardingItem)

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

    func openOnboardingWindow() {
        presentOnboarding(markShown: true)
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
    private func openActivePortsFromStatusItem(_ sender: Any?) {
        openPortsOverviewService.showOverview()
    }

    @objc
    private func openOnboardingFromStatusItem(_ sender: Any?) {
        openOnboardingWindow()
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

    private func presentOnboardingIfNeeded() {
        guard !AppPreferences.hasShownOnboarding() else { return }
        presentOnboarding(markShown: true)
    }

    @MainActor
    private func presentOnboarding(markShown: Bool) {
        if markShown {
            AppPreferences.setHasShownOnboarding(true)
        }

        if let onboardingWindow {
            centerWindowOnActiveScreen(onboardingWindow)
            onboardingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingController = NSHostingController(
            rootView: OnboardingView { [weak self] in
                self?.dismissOnboardingWindow()
            }
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 610),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = AppMetadata.displayName
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.contentViewController = hostingController
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.delegate = self
        centerWindowOnActiveScreen(window)
        window.makeKeyAndOrderFront(nil)
        DispatchQueue.main.async { [weak self, weak window] in
            guard let self, let window else { return }
            self.centerWindowOnActiveScreen(window)
        }
        onboardingWindow = window
        NSApp.activate(ignoringOtherApps: true)
    }

    @MainActor
    private func centerWindowOnActiveScreen(_ window: NSWindow) {
        let mouseLocation = NSEvent.mouseLocation
        let targetScreen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) })
            ?? NSScreen.main
            ?? NSScreen.screens.first

        guard let targetScreen else {
            window.center()
            return
        }

        let visibleFrame = targetScreen.visibleFrame
        let windowFrame = window.frame
        let origin = CGPoint(
            x: visibleFrame.midX - windowFrame.width / 2,
            y: visibleFrame.midY - windowFrame.height / 2
        )

        let centeredFrame = NSRect(origin: origin, size: windowFrame.size).integral
        window.setFrame(centeredFrame, display: false)
    }

    @MainActor
    private func dismissOnboardingWindow() {
        onboardingWindow?.close()
        onboardingWindow = nil
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

    private func applySlapDetectionPreference() {
        let config = AppPreferences.experimentalFeatureConfiguration()
        let enabled = config.slapDetectionEnabled
        let service = SlapDetectionService.shared
        service.updateSensitivity(config.slapDetectionSensitivity)
        service.updateRequiredSlaps(config.slapDetectionRequiredSlaps)
        if enabled && !service.isMonitoring {
            let action = config.slapDetectionAction
            service.onSlapDetected = { [weak self] in
                self?.handleSlapAction(action)
            }
            service.startMonitoring()
        } else if !enabled && service.isMonitoring {
            service.stopMonitoring()
            service.onSlapDetected = nil
        }
    }

    @MainActor
    private func handleSlapAction(_ action: String) {
        guard let screen = NSScreen.main,
              let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        else { return }
        let displayID = CGDirectDisplayID(screenNumber.uint32Value)

        switch action {
        case "expandNotch":
            notchController?.pinDisplayExpanded(displayID)
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                self?.notchController?.unpinDisplayExpanded(displayID)
            }
        default:
            notchController?.openBlackWindowForCurrentInteractionScreen()
        }
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        if window === onboardingWindow {
            onboardingWindow = nil
        }
    }
}
