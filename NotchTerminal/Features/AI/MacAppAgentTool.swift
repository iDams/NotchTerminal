import AppKit
import Foundation

enum MacAppAgentToolAction: String, Codable, CaseIterable {
    case openApp = "open_app"
    case activateApp = "activate_app"
    case typeText = "type_text"
    case pressKey = "press_key"

    var successMessage: String {
        switch self {
        case .openApp:
            return "Opened the macOS app."
        case .activateApp:
            return "Activated the macOS app."
        case .typeText:
            return "Typed text into the macOS app."
        case .pressKey:
            return "Pressed a key in the macOS app."
        }
    }
}

enum MacAppAgentToolRunner {
    @MainActor
    static func run(action: MacAppAgentToolAction, bundleIdentifier: String, installedApps: [AICronjobInstalledApp], text: String? = nil, key: String? = nil) async -> String {
        guard let app = installedApps.first(where: { $0.bundleIdentifier == bundleIdentifier }) else {
            return "Error: App \(bundleIdentifier) is not connected to this job."
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        switch action {
        case .openApp:
            let url = URL(fileURLWithPath: app.appPath)
            NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
                if let error {
                    print("[MacAppAgentTool] open_app failed for \(bundleIdentifier): \(error.localizedDescription)")
                }
            }
            return "Opened \(app.displayName)."
        case .activateApp:
            if let runningApp = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first {
                let activated = runningApp.activate()
                return activated ? "Activated \(app.displayName)." : "Tried to activate \(app.displayName), but macOS did not confirm focus."
            }

            let url = URL(fileURLWithPath: app.appPath)
            NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
                if let error {
                    print("[MacAppAgentTool] activate_app failed for \(bundleIdentifier): \(error.localizedDescription)")
                }
            }
            return "Opened and activated \(app.displayName)."
        case .typeText:
            guard let text, !text.isEmpty else {
                return "Error: type_text requires a text value."
            }
            return await MacAppAutomationService.typeText(text, into: app)
        case .pressKey:
            guard let key, !key.isEmpty else {
                return "Error: press_key requires a key value."
            }
            return await MacAppAutomationService.pressKey(key, in: app)
        }
    }
}
