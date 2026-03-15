import Foundation

public enum AICronjobLogLevel: String, Codable, CaseIterable {
    case info
    case success
    case warning
    case error
    case debug
}

public struct AICronjobLogEntry: Codable, Identifiable, Equatable {
    public var id: UUID = UUID()
    public var timestamp: Double = Date().timeIntervalSince1970
    public var level: AICronjobLogLevel = .info
    public var message: String = ""

    public init(id: UUID = UUID(), timestamp: Double = Date().timeIntervalSince1970, level: AICronjobLogLevel = .info, message: String) {
        self.id = id
        self.timestamp = timestamp
        self.level = level
        self.message = message
    }
}

public struct AICronjobLogStore: Codable, RawRepresentable {
    public static let retentionInterval: TimeInterval = 60 * 60 * 24 * 7
    public static let maxEntriesPerJob = 200

    public var entriesByJobID: [String: [AICronjobLogEntry]]

    public init(entriesByJobID: [String: [AICronjobLogEntry]] = [:]) {
        self.entriesByJobID = entriesByJobID
    }

    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let result = try? JSONDecoder().decode([String: [AICronjobLogEntry]].self, from: data) else {
            return nil
        }

        self.entriesByJobID = result
    }

    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(entriesByJobID),
              let result = String(data: data, encoding: .utf8) else {
            return "{}"
        }

        return result
    }

    public func entries(for jobID: UUID) -> [AICronjobLogEntry] {
        entriesByJobID[jobID.uuidString, default: []]
            .sorted { $0.timestamp > $1.timestamp }
    }

    public mutating func append(_ entry: AICronjobLogEntry, for jobID: UUID) {
        let key = jobID.uuidString
        var entries = entriesByJobID[key, default: []]
        entries.append(entry)
        entries = Self.prune(entries)
        entriesByJobID[key] = entries
    }

    public mutating func clear(jobID: UUID) {
        entriesByJobID.removeValue(forKey: jobID.uuidString)
    }

    public mutating func pruneAll() {
        for key in entriesByJobID.keys {
            let pruned = Self.prune(entriesByJobID[key, default: []])
            if pruned.isEmpty {
                entriesByJobID.removeValue(forKey: key)
            } else {
                entriesByJobID[key] = pruned
            }
        }
    }

    private static func prune(_ entries: [AICronjobLogEntry]) -> [AICronjobLogEntry] {
        let cutoff = Date().timeIntervalSince1970 - retentionInterval
        let filtered = entries.filter { $0.timestamp >= cutoff }
        if filtered.count <= maxEntriesPerJob {
            return filtered
        }
        return Array(filtered.suffix(maxEntriesPerJob))
    }
}
