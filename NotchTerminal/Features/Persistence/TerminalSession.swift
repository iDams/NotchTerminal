import Foundation
import CoreGraphics
import SwiftData

@Model
final class TerminalSession {
    @Attribute(.unique) var id: UUID
    var workingDirectory: String
    var windowWidth: Double
    var windowHeight: Double
    var isDockedToNotch: Bool
    var isAlwaysOnTop: Bool
    var isCompact: Bool
    var isMaximized: Bool
    var displayTitle: String
    var projectRootPath: String?
    var projectName: String?
    var lastSubmittedCommand: String?
    var lastKnownDisplayID: String
    var preMaximizeFrameMinX: Double?
    var preMaximizeFrameMinY: Double?
    var preMaximizeFrameWidth: Double?
    var preMaximizeFrameHeight: Double?
    var creationTimestamp: Date

    
    init(id: UUID = UUID(),
         workingDirectory: String = NSHomeDirectory(),
         windowWidth: Double = 640.0,
         windowHeight: Double = 400.0,
         isDockedToNotch: Bool = false,
         isAlwaysOnTop: Bool = false,
         isCompact: Bool = false,
         isMaximized: Bool = false,
         displayTitle: String = "NotchTerminal",
         projectRootPath: String? = nil,
         projectName: String? = nil,
         lastSubmittedCommand: String? = nil,
         lastKnownDisplayID: String = "",
         preMaximizeFrame: CGRect? = nil,
         creationTimestamp: Date = Date()) {
        self.id = id
        self.workingDirectory = workingDirectory
        self.windowWidth = windowWidth
        self.windowHeight = windowHeight
        self.isDockedToNotch = isDockedToNotch
        self.isAlwaysOnTop = isAlwaysOnTop
        self.isCompact = isCompact
        self.isMaximized = isMaximized
        self.displayTitle = displayTitle
        self.projectRootPath = projectRootPath
        self.projectName = projectName
        self.lastSubmittedCommand = lastSubmittedCommand
        self.lastKnownDisplayID = lastKnownDisplayID
        self.preMaximizeFrameMinX = preMaximizeFrame.map { Double($0.minX) }
        self.preMaximizeFrameMinY = preMaximizeFrame.map { Double($0.minY) }
        self.preMaximizeFrameWidth = preMaximizeFrame.map { Double($0.width) }
        self.preMaximizeFrameHeight = preMaximizeFrame.map { Double($0.height) }
        self.creationTimestamp = creationTimestamp
    }
}

extension TerminalSession {
    var preMaximizeFrame: CGRect? {
        get {
            guard let minX = preMaximizeFrameMinX,
                  let minY = preMaximizeFrameMinY,
                  let width = preMaximizeFrameWidth,
                  let height = preMaximizeFrameHeight else {
                return nil
            }

            return CGRect(x: minX, y: minY, width: width, height: height)
        }
        set {
            preMaximizeFrameMinX = newValue.map { Double($0.minX) }
            preMaximizeFrameMinY = newValue.map { Double($0.minY) }
            preMaximizeFrameWidth = newValue.map { Double($0.width) }
            preMaximizeFrameHeight = newValue.map { Double($0.height) }
        }
    }
}
