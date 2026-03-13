import Foundation

public enum AICronjobExecutionMode: String, Codable, Equatable {
    case app
    case machine
}

public struct AICronjob: Codable, Identifiable, Equatable {
    public var id: UUID = UUID()
    public var name: String = "My AI Cronjob"
    public var prompt: String = "Hello World"
    
    // Execution configuration
    public var mode: AICronjobExecutionMode = .app
    public var interval: Double = 60.0 // Used when mode == .app
    public var cronExpression: String = "0 * * * *" // Used when mode == .machine
    
    public var isEnabled: Bool = false
    public var autoDisable: Bool = true
    public var activationDate: Double = Date().timeIntervalSince1970
    
    // Derived property for the 3-day safety check
    public var hasExpired: Bool {
        guard autoDisable else { return false }
        let daysSinceActivation = (Date().timeIntervalSince1970 - activationDate) / (60 * 60 * 24)
        return daysSinceActivation > 3.0
    }
    
    public init() {}
    
    public static func == (lhs: AICronjob, rhs: AICronjob) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.prompt == rhs.prompt &&
               lhs.mode == rhs.mode &&
               lhs.interval == rhs.interval &&
               lhs.cronExpression == rhs.cronExpression &&
               lhs.isEnabled == rhs.isEnabled &&
               lhs.autoDisable == rhs.autoDisable
    }
}

extension Array: @retroactive RawRepresentable where Element == AICronjob {
    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let result = try? JSONDecoder().decode([AICronjob].self, from: data)
        else {
            return nil
        }
        self = result
    }

    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(self),
              let result = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }
        return result
    }
}


