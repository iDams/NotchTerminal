import Foundation

public struct AIRecipeJob: Codable, Equatable {
    public var schemaVersion: Int = 1
    public var kind: String = "recipeJob"
    public var id: String = "new-recipejob"
    public var name: String = "New RecipeJob"
    public var author: String = ""
    public var description: String = ""
    public var category: String = "general"
    public var tags: [String] = []
    public var source: Source = Source()
    public var prompt: String = ""
    public var execution: Execution = Execution()
    public var permissions: Permissions = Permissions()
    public var provider: Provider = Provider()
    public var integrations: Integrations = Integrations()
    public var defaults: Defaults = Defaults()

    public init() {}

    public struct Execution: Codable, Equatable {
        public var mode: AICronjobExecutionMode = .app
        public var intervalSeconds: Double = 60
        public var cronExpression: String = "0 * * * *"

        public init() {}
    }

    public struct Permissions: Codable, Equatable {
        public var usesDefaultAllowedCommands: Bool = true
        public var allowedCommands: [String] = []

        public init() {}
    }

    public struct Provider: Codable, Equatable {
        public var useActiveProvider: Bool = true
        public var providerID: String? = nil

        public init() {}
    }

    public struct Integrations: Codable, Equatable {
        public var connectedApps: [AICronjobConnectedApp] = []
        public var installedApps: [AICronjobInstalledApp] = []

        public init() {}
    }

    public struct Defaults: Codable, Equatable {
        public var autoDisable: Bool = true
        public var debugLoggingEnabled: Bool = false
        public var isEnabled: Bool = false

        public init() {}
    }

    public struct Source: Codable, Equatable {
        public var sourceID: String = ""
        public var updateURL: String = ""

        public init() {}
    }
}

extension AIRecipeJob {
    public func makeCronjob() -> AICronjob {
        var job = AICronjob()
        job.id = UUID()
        job.name = name
        job.detail = description
        job.prompt = prompt
        job.recipeAuthor = author
        job.recipeIdentifier = id
        job.recipeVersion = schemaVersion
        job.recipeUpdateURL = source.updateURL
        job.recipeSourceID = source.sourceID
        if provider.useActiveProvider {
            job.providerID = nil
        } else {
            job.providerID = provider.providerID.flatMap(UUID.init(uuidString:))
        }
        job.connectedApps = integrations.connectedApps
        let availableApps = InstalledAppsCatalog.load()
        let availableBundleIDs = Set(availableApps.map(\ .bundleIdentifier))
        let missingApps = integrations.installedApps.filter { !availableBundleIDs.contains($0.bundleIdentifier) }
        job.installedApps = integrations.installedApps.filter { availableBundleIDs.contains($0.bundleIdentifier) }
        job.usesDefaultAllowedCommands = permissions.usesDefaultAllowedCommands
        job.allowedCommands = permissions.allowedCommands
        job.mode = execution.mode
        job.interval = execution.intervalSeconds
        job.cronExpression = execution.cronExpression
        job.isEnabled = false
        job.autoDisable = defaults.autoDisable
        job.debugLoggingEnabled = defaults.debugLoggingEnabled
        job.activationDate = Date().timeIntervalSince1970
        if !missingApps.isEmpty {
            let tokens = missingApps.map { "@missing-app:\($0.bundleIdentifier)" }.joined(separator: " ")
            let note = "Missing apps on this Mac: \(tokens)"
            job.detail = [job.detail, note].filter { !$0.isEmpty }.joined(separator: "\n")
            job.prompt = job.prompt + "\n\nUnavailable app tokens on this Mac: \(tokens)"
        }
        return job
    }

    public static func from(job: AICronjob, author: String = "") -> AIRecipeJob {
        var recipe = AIRecipeJob()
        recipe.id = slug(from: job.name)
        recipe.name = job.name
        recipe.author = job.recipeAuthor.isEmpty ? author : job.recipeAuthor
        recipe.description = job.detail
        recipe.source.sourceID = job.recipeSourceID
        recipe.source.updateURL = job.recipeUpdateURL
        recipe.prompt = job.prompt
        recipe.execution.mode = job.mode
        recipe.execution.intervalSeconds = job.interval
        recipe.execution.cronExpression = job.cronExpression
        recipe.permissions.usesDefaultAllowedCommands = job.usesDefaultAllowedCommands
        recipe.permissions.allowedCommands = job.allowedCommands
        recipe.provider.useActiveProvider = job.providerID == nil
        recipe.provider.providerID = job.providerID?.uuidString
        recipe.integrations.connectedApps = job.connectedApps
        recipe.integrations.installedApps = job.installedApps
        recipe.defaults.autoDisable = job.autoDisable
        recipe.defaults.debugLoggingEnabled = job.debugLoggingEnabled
        recipe.defaults.isEnabled = false
        return recipe
    }

    private static func slug(from value: String) -> String {
        let invalid = CharacterSet.alphanumerics.union(.init(charactersIn: "-_" )).inverted
        let cleaned = value.lowercased().components(separatedBy: invalid).filter { !$0.isEmpty }.joined(separator: "-")
        return cleaned.isEmpty ? "recipejob" : cleaned
    }
}
