import Foundation
import SwiftData

@Model
final class TerminalSession {
    @Attribute(.unique) var id: UUID
    var workingDirectory: String
    var windowWidth: Double
    var windowHeight: Double
    var isDockedToNotch: Bool
    var lastKnownDisplayID: String
    var creationTimestamp: Date
    
    init(id: UUID = UUID(), 
         workingDirectory: String = NSHomeDirectory(), 
         windowWidth: Double = 640.0, 
         windowHeight: Double = 400.0, 
         isDockedToNotch: Bool = false, 
         lastKnownDisplayID: String = "",
         creationTimestamp: Date = Date()) {
        self.id = id
        self.workingDirectory = workingDirectory
        self.windowWidth = windowWidth
        self.windowHeight = windowHeight
        self.isDockedToNotch = isDockedToNotch
        self.lastKnownDisplayID = lastKnownDisplayID
        self.creationTimestamp = creationTimestamp
    }
}
