import Foundation

public enum AICronjobExecutionMode: String, Codable, Equatable {
    case app
    case machine
}

public enum AICronjobConnectedApp: String, Codable, Equatable, CaseIterable, Identifiable {
    case notchTerminal

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .notchTerminal:
            return "Notch Terminal"
        }
    }

    public var systemImage: String {
        switch self {
        case .notchTerminal:
            return "terminal"
        }
    }

    public var promptToken: String {
        switch self {
        case .notchTerminal:
            return "@notch-terminal"
        }
    }

    public var shortDescription: String {
        switch self {
        case .notchTerminal:
            return "Open or control a terminal window inside NotchTerminal."
        }
    }
}

public struct AICronjobInstalledApp: Codable, Equatable, Identifiable, Hashable {
    public var bundleIdentifier: String
    public var displayName: String
    public var appPath: String

    public var id: String { bundleIdentifier }

    public var promptToken: String {
        "@app:\(bundleIdentifier)"
    }
}

public struct AICronjob: Codable, Identifiable, Equatable {
    public var id: UUID = UUID()
    public var name: String = "My AI Cronjob"
    public var detail: String = ""
    public var prompt: String = "Hello World"
    public var providerID: UUID? = nil
    public var connectedApps: [AICronjobConnectedApp] = []
    public var installedApps: [AICronjobInstalledApp] = []
    public var usesDefaultAllowedCommands: Bool = true
    public var allowedCommands: [String] = []

    public var mode: AICronjobExecutionMode = .app
    public var interval: Double = 60.0
    public var cronExpression: String = "0 * * * *"

    public var isEnabled: Bool = false
    public var autoDisable: Bool = true
    public var debugLoggingEnabled: Bool = false
    public var activationDate: Double = Date().timeIntervalSince1970

    public var hasExpired: Bool {
        guard autoDisable else { return false }
        let daysSinceActivation = (Date().timeIntervalSince1970 - activationDate) / (60 * 60 * 24)
        return daysSinceActivation > 3.0
    }

    public var normalizedConnectedApps: [AICronjobConnectedApp] {
        var seen = Set<String>()
        return connectedApps.filter { app in
            seen.insert(app.rawValue).inserted
        }
    }

    public var normalizedInstalledApps: [AICronjobInstalledApp] {
        var seen = Set<String>()
        return installedApps.filter { app in
            seen.insert(app.bundleIdentifier).inserted
        }
    }

    public init() {}

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case detail
        case prompt
        case providerID
        case connectedApps
        case installedApps
        case usesDefaultAllowedCommands
        case allowedCommands
        case mode
        case interval
        case cronExpression
        case isEnabled
        case autoDisable
        case debugLoggingEnabled
        case activationDate
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "My AI Cronjob"
        detail = try container.decodeIfPresent(String.self, forKey: .detail) ?? ""
        prompt = try container.decodeIfPresent(String.self, forKey: .prompt) ?? "Hello World"
        providerID = try container.decodeIfPresent(UUID.self, forKey: .providerID)
        connectedApps = try container.decodeIfPresent([AICronjobConnectedApp].self, forKey: .connectedApps) ?? []
        installedApps = try container.decodeIfPresent([AICronjobInstalledApp].self, forKey: .installedApps) ?? []
        usesDefaultAllowedCommands = try container.decodeIfPresent(Bool.self, forKey: .usesDefaultAllowedCommands) ?? true
        allowedCommands = try container.decodeIfPresent([String].self, forKey: .allowedCommands) ?? []
        mode = try container.decodeIfPresent(AICronjobExecutionMode.self, forKey: .mode) ?? .app
        interval = try container.decodeIfPresent(Double.self, forKey: .interval) ?? 60.0
        cronExpression = try container.decodeIfPresent(String.self, forKey: .cronExpression) ?? "0 * * * *"
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? false
        autoDisable = try container.decodeIfPresent(Bool.self, forKey: .autoDisable) ?? true
        debugLoggingEnabled = try container.decodeIfPresent(Bool.self, forKey: .debugLoggingEnabled) ?? false
        activationDate = try container.decodeIfPresent(Double.self, forKey: .activationDate) ?? Date().timeIntervalSince1970
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(detail, forKey: .detail)
        try container.encode(prompt, forKey: .prompt)
        try container.encodeIfPresent(providerID, forKey: .providerID)
        try container.encode(normalizedConnectedApps, forKey: .connectedApps)
        try container.encode(normalizedInstalledApps, forKey: .installedApps)
        try container.encode(usesDefaultAllowedCommands, forKey: .usesDefaultAllowedCommands)
        try container.encode(allowedCommands, forKey: .allowedCommands)
        try container.encode(mode, forKey: .mode)
        try container.encode(interval, forKey: .interval)
        try container.encode(cronExpression, forKey: .cronExpression)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(autoDisable, forKey: .autoDisable)
        try container.encode(debugLoggingEnabled, forKey: .debugLoggingEnabled)
        try container.encode(activationDate, forKey: .activationDate)
    }

    public static func == (lhs: AICronjob, rhs: AICronjob) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.detail == rhs.detail &&
        lhs.prompt == rhs.prompt &&
        lhs.providerID == rhs.providerID &&
        lhs.connectedApps == rhs.connectedApps &&
        lhs.installedApps == rhs.installedApps &&
        lhs.usesDefaultAllowedCommands == rhs.usesDefaultAllowedCommands &&
        lhs.allowedCommands == rhs.allowedCommands &&
        lhs.mode == rhs.mode &&
        lhs.interval == rhs.interval &&
        lhs.cronExpression == rhs.cronExpression &&
        lhs.isEnabled == rhs.isEnabled &&
        lhs.autoDisable == rhs.autoDisable &&
        lhs.debugLoggingEnabled == rhs.debugLoggingEnabled
    }
}

extension Array: @retroactive RawRepresentable where Element == AICronjob {
    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let result = try? JSONDecoder().decode([AICronjob].self, from: data) else {
            return nil
        }
        self = result
    }

    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(self),
              let result = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return result
    }
}
