import AppKit

struct TerminalWindowItem: Identifiable {
    let id: UUID
    let number: Int
    let displayID: CGDirectDisplayID
    let title: String
    let projectName: String?
    let workingDirectory: String
    let lastCommand: String?
    let icon: NSImage?
    let preview: NSImage?
    let isMinimized: Bool
    let isAlwaysOnTop: Bool
    let isActive: Bool
}
