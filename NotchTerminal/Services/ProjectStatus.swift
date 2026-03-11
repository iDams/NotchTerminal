import Foundation

/// Represents the current status of a project directory, mainly focused on Git.
public struct ProjectStatus: Equatable {
    public var branchName: String?
    public var hasPendingChanges: Bool
    public var lastCommand: String? // Reserved for later integration
    public var activePort: Int?     // Reserved for later integration
    
    public init(branchName: String? = nil, hasPendingChanges: Bool = false, lastCommand: String? = nil, activePort: Int? = nil) {
        self.branchName = branchName
        self.hasPendingChanges = hasPendingChanges
        self.lastCommand = lastCommand
        self.activePort = activePort
    }
}
