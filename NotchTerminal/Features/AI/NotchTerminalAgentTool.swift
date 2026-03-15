import Foundation

enum NotchTerminalAgentToolAction: String, Codable, CaseIterable {
    case openTerminal = "open_terminal"
    case restoreAllWindows = "restore_all_windows"
    case writeText = "write_text"

    var successMessage: String {
        switch self {
        case .openTerminal:
            return "Opened a new NotchTerminal terminal window."
        case .restoreAllWindows:
            return "Restored NotchTerminal terminal windows."
        case .writeText:
            return "Wrote text into NotchTerminal."
        }
    }
}

extension Notification.Name {
    static let notchTerminalAgentToolRequested = Notification.Name("NotchTerminal.notchTerminalAgentToolRequested")
}

enum NotchTerminalAgentToolUserInfoKey {
    static let action = "action"
    static let text = "text"
    static let submit = "submit"
}
