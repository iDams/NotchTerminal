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

    static func typeText(_ text: String, into app: AICronjobInstalledApp) async -> String {
        guard ensureAccessibilityPermission() else {
            return "Error: NotchTerminal needs Accessibility permission in System Settings > Privacy & Security > Accessibility before it can type into macOS apps."
        }

        guard let runningApp = await ensureRunningApp(for: app) else {
            return "Error: Could not launch or find \(app.displayName)."
        }

        _ = await MainActor.run {
            runningApp.activate()
        }
        try? await Task.sleep(nanoseconds: 250_000_000)

        guard await postText(text, to: runningApp.processIdentifier) else {
            return "Error: Failed to type into \(app.displayName)."
        }

        return "Typed text into \(app.displayName): \(text)"
    }

    static func pressKey(_ key: String, in app: AICronjobInstalledApp) async -> String {
        guard ensureAccessibilityPermission() else {
            return "Error: NotchTerminal needs Accessibility permission in System Settings > Privacy & Security > Accessibility before it can send keys to macOS apps."
        }

        guard let runningApp = await ensureRunningApp(for: app) else {
            return "Error: Could not launch or find \(app.displayName)."
        }

        _ = await MainActor.run {
            runningApp.activate()
        }
        try? await Task.sleep(nanoseconds: 200_000_000)

        guard let keyCode = keyCode(for: key) else {
            return "Error: Unsupported key \(key). Try enter, return, escape, tab, delete, up, down, left, or right."
        }

        guard postKey(keyCode, to: runningApp.processIdentifier) else {
            return "Error: Failed to send key \(key) to \(app.displayName)."
        }

        return "Pressed \(key) in \(app.displayName)."
    }

    private static func ensureRunningApp(for app: AICronjobInstalledApp) async -> NSRunningApplication? {
        if let runningApp = NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleIdentifier).first {
            return runningApp
        }

        let launchedApp = await withCheckedContinuation { continuation in
            Task { @MainActor in
                let configuration = NSWorkspace.OpenConfiguration()
                configuration.activates = true
                NSWorkspace.shared.openApplication(
                    at: URL(fileURLWithPath: app.appPath),
                    configuration: configuration
                ) { launchedApp, _ in
                    continuation.resume(returning: launchedApp)
                }
            }
        }
        return launchedApp ?? NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleIdentifier).first
    }

    private static func postText(_ text: String, to pid: pid_t) async -> Bool {
        guard !text.isEmpty else { return true }
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return false }

        for scalar in text.unicodeScalars {
            guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                  let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else {
                return false
            }

            var utf16Units = Array(String(scalar).utf16)
            keyDown.keyboardSetUnicodeString(stringLength: utf16Units.count, unicodeString: &utf16Units)
            keyUp.keyboardSetUnicodeString(stringLength: utf16Units.count, unicodeString: &utf16Units)
            keyDown.postToPid(pid)
            keyUp.postToPid(pid)
            try? await Task.sleep(nanoseconds: 60_000_000)
        }

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
