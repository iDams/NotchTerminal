import AppKit
import ApplicationServices
import Foundation

enum MacAppAutomationService {
    private static var hasPromptedForAccessibilityPermission = false

    static func ensureAccessibilityPermission() -> Bool {
        if AXIsProcessTrusted() {
            return true
        }

        if !hasPromptedForAccessibilityPermission {
            hasPromptedForAccessibilityPermission = true
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            return AXIsProcessTrustedWithOptions(options)
        }

        return false
    }

    static func requestAccessibilityPermissionIfNeeded() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        hasPromptedForAccessibilityPermission = true
        return AXIsProcessTrustedWithOptions(options)
    }

    @MainActor
    static func typeText(_ text: String, into app: AICronjobInstalledApp) -> String {
        guard ensureAccessibilityPermission() else {
            return "Error: NotchTerminal needs Accessibility permission in System Settings > Privacy & Security > Accessibility before it can type into macOS apps."
        }

        guard let runningApp = ensureRunningApp(for: app) else {
            return "Error: Could not launch or find \(app.displayName)."
        }

        runningApp.activate()
        Thread.sleep(forTimeInterval: 0.25)

        guard postText(text, to: runningApp.processIdentifier) else {
            return "Error: Failed to type into \(app.displayName)."
        }

        return "Typed text into \(app.displayName): \(text)"
    }

    @MainActor
    static func pressKey(_ key: String, in app: AICronjobInstalledApp) -> String {
        guard ensureAccessibilityPermission() else {
            return "Error: NotchTerminal needs Accessibility permission in System Settings > Privacy & Security > Accessibility before it can send keys to macOS apps."
        }

        guard let runningApp = ensureRunningApp(for: app) else {
            return "Error: Could not launch or find \(app.displayName)."
        }

        runningApp.activate()
        Thread.sleep(forTimeInterval: 0.2)

        guard let keyCode = keyCode(for: key) else {
            return "Error: Unsupported key \(key). Try enter, return, escape, tab, delete, up, down, left, or right."
        }

        guard postKey(keyCode, to: runningApp.processIdentifier) else {
            return "Error: Failed to send key \(key) to \(app.displayName)."
        }

        return "Pressed \(key) in \(app.displayName)."
    }

    @MainActor
    private static func ensureRunningApp(for app: AICronjobInstalledApp) -> NSRunningApplication? {
        if let runningApp = NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleIdentifier).first {
            return runningApp
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        var launchedApp: NSRunningApplication?
        let semaphore = DispatchSemaphore(value: 0)
        NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: app.appPath), configuration: configuration) { app, _ in
            launchedApp = app
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 3)
        return launchedApp ?? NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleIdentifier).first
    }

    private static func postText(_ text: String, to pid: pid_t) -> Bool {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return false }
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else {
            return false
        }

        keyDown.keyboardSetUnicodeString(stringLength: text.utf16.count, unicodeString: Array(text.utf16))
        keyUp.keyboardSetUnicodeString(stringLength: text.utf16.count, unicodeString: Array(text.utf16))
        keyDown.postToPid(pid)
        keyUp.postToPid(pid)
        return true
    }

    private static func postKey(_ keyCode: CGKeyCode, to pid: pid_t) -> Bool {
        guard let source = CGEventSource(stateID: .combinedSessionState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            return false
        }

        keyDown.postToPid(pid)
        keyUp.postToPid(pid)
        return true
    }

    private static func keyCode(for key: String) -> CGKeyCode? {
        switch key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "enter", "return": return 36
        case "tab": return 48
        case "space": return 49
        case "delete", "backspace": return 51
        case "escape", "esc": return 53
        case "left": return 123
        case "right": return 124
        case "down": return 125
        case "up": return 126
        default: return nil
        }
    }
}
