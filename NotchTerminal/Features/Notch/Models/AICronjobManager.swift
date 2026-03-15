import Foundation
import SwiftUI
import Combine
import UserNotifications

@MainActor
public final class AICronjobManager: ObservableObject {
    public static let shared = AICronjobManager()
    
    @AppStorage(AppPreferences.Keys.experimentalFloatingMsgEnabled) private var experimentalFloatingMsgEnabled = AppPreferences.Defaults.experimentalFloatingMsgEnabled
    @AppStorage(AppPreferences.Keys.experimentalAICronjobsData) private var experimentalAICronjobsData = AppPreferences.Defaults.experimentalAICronjobsData
    @AppStorage(AppPreferences.Keys.aiProvidersData) private var aiProvidersList = AppPreferences.Defaults.aiProvidersData
    @AppStorage(AppPreferences.Keys.activeAIProviderID) private var activeAIProviderIDString: String = ""
    @AppStorage(AppPreferences.Keys.aiCronjobLogsData) private var aiCronjobLogsData = AppPreferences.Defaults.aiCronjobLogsData
    
    private var activeAIProviderID: UUID? {
        get { UUID(uuidString: activeAIProviderIDString) }
        set { activeAIProviderIDString = newValue?.uuidString ?? "" }
    }
    
    private var cronjobTasks: [UUID: Task<Void, Never>] = [:]
    private var runningCronjobs: [UUID: AICronjob] = [:]
    private var cancellables = Set<AnyCancellable>()
    
    public static let newMessageNotification = Notification.Name("AICronjobManagerNewMessage")
    private static let distributedNotificationName = "com.notchterminal.agent.message"
    
    private init() {
        // Observe UserDefaults changes to sync cronjobs dynamically
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.syncCronjobs()
            }
            .store(in: &cancellables)
        
        // Listen for messages from background launchd processes
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(didReceiveBackgroundMessage(_:)),
            name: NSNotification.Name(AICronjobManager.distributedNotificationName),
            object: nil
        )
            
        // Initial setup
        aiCronjobLogsData.pruneAll()
        syncCronjobs()
    }
    
    @objc private func didReceiveBackgroundMessage(_ notification: NSNotification) {
        if let text = notification.userInfo?["text"] as? String {
            NotificationCenter.default.post(name: AICronjobManager.newMessageNotification, object: nil, userInfo: ["text": text])
        }
    }
    
    private func syncCronjobs() {
        if !experimentalFloatingMsgEnabled {
            for task in cronjobTasks.values {
                task.cancel()
            }
            cronjobTasks.removeAll()
            runningCronjobs.removeAll()
            return
        }

        let activeJobs = experimentalAICronjobsData.filter { $0.isEnabled }
        
        // Remove timers and launch agents for jobs that are no longer active, deleted, or modified
        for (id, task) in cronjobTasks {
            if let active = activeJobs.first(where: { $0.id == id }) {
                let running = runningCronjobs[id]
                if running?.interval != active.interval || running?.prompt != active.prompt || running?.name != active.name || running?.mode != active.mode || running?.cronExpression != active.cronExpression {
                    task.cancel()
                    cronjobTasks.removeValue(forKey: id)
                    runningCronjobs.removeValue(forKey: id)
                    removeLaunchAgent(for: id)
                }
            } else {
                task.cancel()
                cronjobTasks.removeValue(forKey: id)
                runningCronjobs.removeValue(forKey: id)
                removeLaunchAgent(for: id)
            }
        }
        
        // Ensure any new disabled/deleted jobs not caught above have their LaunchAgents removed
        let deletedJobs = experimentalAICronjobsData.filter { !$0.isEnabled }
        for job in deletedJobs {
            removeLaunchAgent(for: job.id)
            runningCronjobs.removeValue(forKey: job.id)
            if let task = cronjobTasks.removeValue(forKey: job.id) {
                task.cancel()
            }
        }
        
        // Start timers or LaunchAgents for active jobs
        for job in activeJobs {
            if job.mode == .machine {
                // If the job is machine mode and it's not already running as one via our tracker
                if runningCronjobs[job.id] == nil {
                    updateLaunchAgent(for: job)
                    runningCronjobs[job.id] = job
                }
            } else {
                if cronjobTasks[job.id] == nil {
                    let task = Task { [weak self] in
                        // Fire immediately upon creation/enabling
                        await self?.fetchAIResponse(for: job)
                        
                        while !Task.isCancelled {
                            // Wait for the interval
                            do {
                                // Swift Concurrency sleep (in nanoseconds)
                                try await Task.sleep(nanoseconds: UInt64(job.interval * 1_000_000_000))
                            } catch {
                                break // task was cancelled during sleep
                            }
                            
                            if Task.isCancelled { break }
                            guard let self = self else { break }
                            
                            // Re-validate the job from our source of truth to ensure it hasn't expired
                            guard let currentJob = self.experimentalAICronjobsData.first(where: { $0.id == job.id }) else { break }
                            
                            if currentJob.hasExpired {
                                await MainActor.run {
                                    var updatedJob = currentJob
                                    updatedJob.isEnabled = false
                                    if let idx = self.experimentalAICronjobsData.firstIndex(where: { $0.id == currentJob.id }) {
                                        self.experimentalAICronjobsData[idx] = updatedJob
                                    }
                                    self.broadcastMessage("Cronjob Auto-Disabled: \(currentJob.name)")
                                }
                                break // exit task
                            }
                            
                            await self.fetchAIResponse(for: currentJob)
                        }
                    }
                    cronjobTasks[job.id] = task
                    runningCronjobs[job.id] = job
                }
            }
        }
    }
    
    // MARK: - Launchd Management
    
    private func launchAgentURL(for id: UUID) -> URL {
        let home = NSHomeDirectory()
        let agentsPath = "\(home)/Library/LaunchAgents"
        let agentsURL = URL(fileURLWithPath: agentsPath)
        try? FileManager.default.createDirectory(at: agentsURL, withIntermediateDirectories: true)
        return agentsURL.appendingPathComponent("com.notchterminal.cronjob.\(id.uuidString).plist")
    }
    
    private func updateLaunchAgent(for job: AICronjob) {
        guard let intervals = parseCronToLaunchdIntervals(job.cronExpression) else {
            print("❌ Invalid cron expression: \(job.cronExpression)")
            return
        }
        
        let executablePath = resolvedBackgroundExecutablePath()
        let plistURL = launchAgentURL(for: job.id)
        let label = "com.notchterminal.cronjob.\(job.id.uuidString)"
        let uid = getuid()
        
        let plistDict: [String: Any] = [
            "Label": label,
            "ProgramArguments": [executablePath, "--run-cronjob", job.id.uuidString],
            "StartCalendarInterval": intervals,
            "RunAtLoad": false
        ]
        
        do {
            let data = try PropertyListSerialization.data(fromPropertyList: plistDict, format: .xml, options: 0)
            try data.write(to: plistURL)
            
            // Bootout existing (ignore errors if not loaded)
            let bootout = Process()
            bootout.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            bootout.arguments = ["bootout", "gui/\(uid)/\(label)"]
            bootout.standardOutput = FileHandle.nullDevice
            bootout.standardError = FileHandle.nullDevice
            try? bootout.run()
            bootout.waitUntilExit()
            
            // Bootstrap new
            let bootstrap = Process()
            bootstrap.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            bootstrap.arguments = ["bootstrap", "gui/\(uid)", plistURL.path]
            let errPipe = Pipe()
            bootstrap.standardError = errPipe
            try bootstrap.run()
            bootstrap.waitUntilExit()
            
            if bootstrap.terminationStatus == 0 {
                print("✅ Loaded machine cronjob: \(job.name)")
            } else {
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                let errStr = String(data: errData, encoding: .utf8) ?? "unknown error"
                print("❌ launchctl bootstrap failed: \(errStr)")
            }
        } catch {
            print("❌ Failed to create or load LaunchAgent: \(error)")
        }
    }

    private func resolvedBackgroundExecutablePath() -> String {
        let bundledPath = Bundle.main.executablePath ?? ""
        let installedPath = "/Applications/NotchTerminal.app/Contents/MacOS/NotchTerminal"

        if FileManager.default.isExecutableFile(atPath: installedPath) {
            return installedPath
        }

        return bundledPath.isEmpty ? installedPath : bundledPath
    }
    
    private func removeLaunchAgent(for id: UUID) {
        let plistURL = launchAgentURL(for: id)
        let label = "com.notchterminal.cronjob.\(id.uuidString)"
        let uid = getuid()
        
        // Bootout (ignore errors if not loaded)
        let bootout = Process()
        bootout.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        bootout.arguments = ["bootout", "gui/\(uid)/\(label)"]
        bootout.standardOutput = FileHandle.nullDevice
        bootout.standardError = FileHandle.nullDevice
        try? bootout.run()
        bootout.waitUntilExit()
        
        if FileManager.default.fileExists(atPath: plistURL.path) {
            try? FileManager.default.removeItem(at: plistURL)
            print("✅ Removed machine cronjob: \(id)")
        }
    }
    
    private func parseCronToLaunchdIntervals(_ cron: String) -> [[String: Int]]? {
        let parts = cron.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard parts.count >= 5 else { return nil }
        
        let minPart = parts[0]
        let hourPart = parts[1]
        
        var dicts: [[String: Int]] = []
        
        let minValues: [Int]
        if minPart == "*" {
            minValues = [-1]
        } else if minPart.hasPrefix("*/"), let step = Int(minPart.dropFirst(2)), step > 0 {
            minValues = Array(stride(from: 0, to: 60, by: step))
        } else if let exact = Int(minPart) {
            minValues = [exact]
        } else {
            return nil
        }
        
        let hourValues: [Int]
        if hourPart == "*" {
            hourValues = [-1]
        } else if hourPart.hasPrefix("*/"), let step = Int(hourPart.dropFirst(2)), step > 0 {
            hourValues = Array(stride(from: 0, to: 24, by: step))
        } else if let exact = Int(hourPart) {
            hourValues = [exact]
        } else {
            return nil
        }
        
        for h in hourValues {
            for m in minValues {
                var d: [String: Int] = [:]
                if h != -1 { d["Hour"] = h }
                if m != -1 { d["Minute"] = m }
                dicts.append(d)
            }
        }
        return dicts
    }
    
    private func broadcastMessage(_ text: String) {
        NotificationCenter.default.post(name: AICronjobManager.newMessageNotification, object: nil, userInfo: ["text": text])
    }
    
    public func triggerTest(for job: AICronjob) {
        Task {
            await fetchAIResponse(for: job)
        }
    }

    public func improvePrompt(_ prompt: String, jobName: String? = nil) async throws -> String {
        let (provider, apiKey, customURL, model) = activeProviderConfig
        guard !apiKey.isEmpty else {
            throw CommandExecutionError.executionFailed("Active provider is missing an API key.")
        }

        let systemPrompt = "You improve prompts for a macOS automation agent. Rewrite the prompt to be clearer, more precise, and more actionable while preserving the original goal. Return only the improved prompt text."
        let trimmedName = jobName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let userPrompt = trimmedName.isEmpty ? prompt : "Job name: \(trimmedName)\n\nOriginal prompt:\n\(prompt)"

        return try await Self.requestTextCompletion(
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            provider: provider,
            apiKey: apiKey,
            customURL: customURL,
            model: model
        )
    }

    public func analyzeLogs(
        for job: AICronjob,
        entries: [AICronjobLogEntry],
        question: String? = nil,
        conversationHistory: [String] = []
    ) async throws -> String {
        let (provider, apiKey, customURL, model) = activeProviderConfig
        guard !apiKey.isEmpty else {
            throw CommandExecutionError.executionFailed("Active provider is missing an API key.")
        }

        let recentEntries = entries
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(80)
            .map { entry in
                let level = entry.level.rawValue.uppercased()
                let timestamp = ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: entry.timestamp))
                return "[\(level)] \(timestamp)\n\(entry.message)"
            }
            .joined(separator: "\n\n")

        let permissions = job.usesDefaultAllowedCommands
            ? "Uses default permissions"
            : job.allowedCommands.joined(separator: ", ")

        let systemPrompt = "You are an expert macOS automation diagnostics assistant for the NotchTerminal app. Review one job run log, identify the most likely problem, explain the root cause briefly, and suggest concrete fixes. Keep the answer concise, structured, and practical. Prefer a short diagnosis followed by a short list of possible solutions. Mention security whitelist issues, provider/API failures, bad prompts, or scheduling mistakes when relevant."

        let requestedQuestion = question?.trimmingCharacters(in: .whitespacesAndNewlines)
        let historyText = conversationHistory.joined(separator: "\n\n")

        let userPrompt = """
        App: NotchTerminal
        Job name: \(job.name)
        Job detail: \(job.detail.isEmpty ? "None" : job.detail)
        Mode: \(job.mode.rawValue)
        Prompt:
        \(job.prompt)

        Permissions:
        \(permissions)

        User question:
        \(requestedQuestion?.isEmpty == false ? requestedQuestion! : "What is the problem in these logs and what are the best fixes?")

        Conversation history:
        \(historyText.isEmpty ? "None" : historyText)

        Recent logs:
        \(recentEntries.isEmpty ? "No logs available." : recentEntries)
        """

        return try await Self.requestTextCompletion(
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            provider: provider,
            apiKey: apiKey,
            customURL: customURL,
            model: model
        )
    }

    public static func testProviderConnection(
        providerType: AIProviderType,
        apiKey: String,
        baseURL: String,
        model: String
    ) async throws -> String {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)

        if providerType.requiresAPIKey && trimmedKey.isEmpty {
            throw CommandExecutionError.executionFailed("This provider requires an API key.")
        }

        if trimmedURL.isEmpty {
            throw CommandExecutionError.executionFailed("Base URL is empty.")
        }

        if trimmedModel.isEmpty {
            throw CommandExecutionError.executionFailed("Model is empty.")
        }

        _ = try await requestTextCompletion(
            systemPrompt: "You are a connectivity probe for NotchTerminal. Reply with exactly: Connection OK",
            userPrompt: "Test the configured provider and return Connection OK if the request works.",
            provider: providerType.rawValue,
            apiKey: trimmedKey,
            customURL: trimmedURL,
            model: trimmedModel
        )

        return "Connection OK"
    }

    public func clearLogs(for jobID: UUID) {
        var store = aiCronjobLogsData
        store.clear(jobID: jobID)
        aiCronjobLogsData = store
    }

    // MARK: - Standalone Background Execution (called by launchd, no singleton init)
    
    public static func executeBackgroundJob(id: String) async {
        print("🚀 [BackgroundJob] Starting for id: \(id)")
        guard let uuid = UUID(uuidString: id) else {
            print("❌ [BackgroundJob] Invalid UUID")
            return
        }
        
        let defaults = UserDefaults.standard
        
        guard let rawData = defaults.string(forKey: AppPreferences.Keys.experimentalAICronjobsData),
              let jsonData = rawData.data(using: .utf8),
              let jobs = try? JSONDecoder().decode([AICronjob].self, from: jsonData),
              let job = jobs.first(where: { $0.id == uuid && $0.isEnabled && $0.mode == .machine }) else {
            print("❌ [BackgroundJob] Job not found or disabled")
            return
        }
        
        let (provider, apiKey, customURL, model, providerInstructions) = resolvedProviderConfig(for: job, from: defaults)
        let allowedCommands = allowedCommands(for: job, defaults: defaults)
        
        await runAgentLoop(
            job: job,
            provider: provider,
            apiKey: apiKey,
            customURL: customURL,
            model: model,
            providerInstructions: providerInstructions,
            allowedCommands: allowedCommands,
            isBackground: true,
            log: { level, message, debugOnly in
                appendLog(level: level, message: message, for: job, defaults: defaults, debugOnly: debugOnly)
            }
        ) { text, jobRef, isBg in
            Task {
                await sendBackgroundNotification(title: "NotchAgent: \(jobRef?.name ?? "Unknown")", body: text)
            }
        }
    }
    
    private static func getActiveProviderConfig(from defaults: UserDefaults) -> (provider: String, apiKey: String, customURL: String, model: String) {
        if let providersRaw = defaults.string(forKey: AppPreferences.Keys.aiProvidersData),
           let providersList = AIProviderList(rawValue: providersRaw),
           let activeIDString = defaults.string(forKey: AppPreferences.Keys.activeAIProviderID),
           let activeID = UUID(uuidString: activeIDString),
           let activeProvider = providersList.providers.first(where: { $0.id == activeID && $0.isEnabled }) {
            
            let apiKey = KeychainService.getAPIKey(for: activeProvider.id) ?? ""
            return (
                activeProvider.type.rawValue,
                apiKey,
                activeProvider.effectiveBaseURL,
                activeProvider.effectiveModel
            )
        }
        
        return ("openai", "", "https://api.openai.com/v1", "gpt-4o-mini")
    }

    private static func resolvedProviderConfig(
        for job: AICronjob,
        from defaults: UserDefaults
    ) -> (provider: String, apiKey: String, customURL: String, model: String, providerInstructions: String) {
        guard let providersRaw = defaults.string(forKey: AppPreferences.Keys.aiProvidersData),
              let providersList = AIProviderList(rawValue: providersRaw) else {
            let fallback = getActiveProviderConfig(from: defaults)
            return (fallback.provider, fallback.apiKey, fallback.customURL, fallback.model, "")
        }

        if let providerID = job.providerID,
           let provider = providersList.providers.first(where: { $0.id == providerID && $0.isEnabled }) {
            let apiKey = KeychainService.getAPIKey(for: provider.id) ?? ""
            return (
                provider.type.rawValue,
                apiKey,
                provider.effectiveBaseURL,
                provider.effectiveModel,
                provider.instructions
            )
        }

        if let activeIDString = defaults.string(forKey: AppPreferences.Keys.activeAIProviderID),
           let activeID = UUID(uuidString: activeIDString),
           let activeProvider = providersList.providers.first(where: { $0.id == activeID && $0.isEnabled }) {
            let apiKey = KeychainService.getAPIKey(for: activeProvider.id) ?? ""
            return (
                activeProvider.type.rawValue,
                apiKey,
                activeProvider.effectiveBaseURL,
                activeProvider.effectiveModel,
                activeProvider.instructions
            )
        }

        let fallback = getActiveProviderConfig(from: defaults)
        return (fallback.provider, fallback.apiKey, fallback.customURL, fallback.model, "")
    }
    
    private static func sendBackgroundNotification(title: String, body: String) async {
        // 1. Send macOS native notification (always, for Notification Center)
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        do {
            try await center.add(request)
            print("✅ [BackgroundJob] Notification sent: \(title) - \(body)")
        } catch {
            print("❌ [BackgroundJob] Failed to send notification: \(error)")
        }
        
        // 2. Post distributed notification (for the Notch, if app is open)
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name(distributedNotificationName),
            object: nil,
            userInfo: ["text": "\(title): \(body)"],
            deliverImmediately: true
        )
    }

    private func fetchAIResponse(for job: AICronjob, isBackground: Bool = false) async {
        let resolvedProvider = resolvedProviderConfig(for: job)
        let allowedCommands = effectiveAllowedCommands(for: job)
        
        await Self.runAgentLoop(
            job: job,
            provider: resolvedProvider.provider,
            apiKey: resolvedProvider.apiKey,
            customURL: resolvedProvider.customURL,
            model: resolvedProvider.model,
            providerInstructions: resolvedProvider.providerInstructions,
            allowedCommands: allowedCommands,
            isBackground: isBackground,
            log: { [weak self] level, message, debugOnly in
                self?.recordLog(level: level, message: message, for: job, debugOnly: debugOnly)
            }
        ) { [weak self] text, jobRef, isBg in
            self?.broadcastMessage(text, job: jobRef, isBackground: isBg)
        }
    }
    
    private var activeProviderConfig: (provider: String, apiKey: String, customURL: String, model: String) {
        guard let activeID = activeAIProviderID,
              let provider = aiProvidersList.providers.first(where: { $0.id == activeID && $0.isEnabled }) else {
            return ("openai", "", "https://api.openai.com/v1", "gpt-4o-mini")
        }
        
        let apiKey = KeychainService.getAPIKey(for: provider.id) ?? ""
        return (
            provider.type.rawValue,
            apiKey,
            provider.effectiveBaseURL,
            provider.effectiveModel
        )
    }

    private var activeProviderInstructions: String {
        guard let activeID = activeAIProviderID,
              let provider = aiProvidersList.providers.first(where: { $0.id == activeID && $0.isEnabled }) else {
            return ""
        }

        return provider.instructions
    }

    private static func activeProviderInstructions(from defaults: UserDefaults) -> String {
        guard let providersRaw = defaults.string(forKey: AppPreferences.Keys.aiProvidersData),
              let providersList = AIProviderList(rawValue: providersRaw),
              let activeIDString = defaults.string(forKey: AppPreferences.Keys.activeAIProviderID),
              let activeID = UUID(uuidString: activeIDString),
              let activeProvider = providersList.providers.first(where: { $0.id == activeID && $0.isEnabled }) else {
            return ""
        }

        return activeProvider.instructions
    }

    private func resolvedProviderConfig(for job: AICronjob) -> (provider: String, apiKey: String, customURL: String, model: String, providerInstructions: String) {
        if let providerID = job.providerID,
           let provider = aiProvidersList.providers.first(where: { $0.id == providerID && $0.isEnabled }) {
            let apiKey = KeychainService.getAPIKey(for: provider.id) ?? ""
            return (
                provider.type.rawValue,
                apiKey,
                provider.effectiveBaseURL,
                provider.effectiveModel,
                provider.instructions
            )
        }

        let active = activeProviderConfig
        return (active.provider, active.apiKey, active.customURL, active.model, activeProviderInstructions)
    }
    
    // MARK: - Core Multi-Turn Agent Loop
    
    private static func runAgentLoop(
        job: AICronjob,
        provider: String,
        apiKey: String,
        customURL: String,
        model: String,
        providerInstructions: String,
        allowedCommands: Set<String>,
        isBackground: Bool,
        log: @escaping (AICronjobLogLevel, String, Bool) -> Void,
        broadcast: @escaping (String, AICronjob?, Bool) -> Void
    ) async {
        guard !apiKey.isEmpty else {
            log(.error, "API key missing for active provider.", false)
            broadcast("API Key Missing", job, isBackground)
            return
        }

        let toolSchemas = availableToolSchemas(for: job)

        let baseURL = customURL
        
        let safeURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(safeURL)/chat/completions") else { 
            log(.error, "Invalid provider URL: \(safeURL)", false)
            broadcast("Invalid URL", job, isBackground)
            return 
        }
        
        let providerType = AIProviderType(rawValue: provider) ?? .custom
        let finalModel = provider == "openrouter" ? "openrouter/free" : model
        let responseTokenLimit = providerType.defaultResponseTokenLimit
        let usesOpenAICompletionsTokenField = provider == AIProviderType.openai.rawValue && finalModel.lowercased().hasPrefix("gpt-5")
        let requestTimeout: TimeInterval = providerType == .minimax ? 90 : 45
        let systemPrompt = mergedSystemPrompt(for: providerType, providerInstructions: providerInstructions)

        var messages: [AIChatMessage] = [
            AIChatMessage(role: "system", text: systemPrompt),
            AIChatMessage(role: "user", text: job.prompt)
        ]
        let maxTurns = 4
        var currentTurn = 0
        var sawToolFailure = false
        var attemptedCommands = Set<String>()
        let promptRequiresVisualVerification = requiresVisualVerification(for: job.prompt)
        var lastVisualActionTurn: Int? = nil
        var lastCaptureTurn: Int? = nil
        var pendingVisualVerificationApp: AICronjobInstalledApp? = nil
        log(.info, "Starting run with model \(finalModel).", false)
        
        while currentTurn < maxTurns {
            currentTurn += 1
            
            var requestObj = AIChatRequest(
                model: finalModel,
                messages: messages,
                tools: toolSchemas,
                toolChoice: "auto",
                maxTokens: usesOpenAICompletionsTokenField ? nil : responseTokenLimit,
                maxCompletionTokens: usesOpenAICompletionsTokenField ? responseTokenLimit : nil
            )
            
            if provider == "openrouter" {
                requestObj.reasoning = AIReasoningSchema(enabled: true)
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = requestTimeout
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if provider == "openrouter" {
                request.setValue("https://notchterminal.imarcodev.com", forHTTPHeaderField: "HTTP-Referer")
                request.setValue("NotchTerminal", forHTTPHeaderField: "X-Title")
            }
            
            let encoder = JSONEncoder()
            guard let httpBody = try? encoder.encode(requestObj) else {
                log(.error, "Failed to encode request body.", false)
                broadcast("Failed to encode request", job, isBackground)
                return
            }
            request.httpBody = httpBody
            
            do {
                if currentTurn == 1 {
                    print("🚀 [Agent] Sending request for job: '\(job.name)' using model: \(finalModel)")
                }
                log(.debug, "Sending request turn \(currentTurn).", true)
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                    var errMsg = "HTTP Error \(httpResponse.statusCode)"
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errorObj = json["error"] as? [String: Any],
                       let msg = errorObj["message"] as? String {
                        errMsg = msg
                    }
                    log(.error, "API error: \(errMsg)", false)
                    broadcast("API Error: \(errMsg)", job, isBackground)
                    return
                }
                
                let decoder = JSONDecoder()
                let aiResponse = try decoder.decode(AIChatResponse.self, from: data)
                guard let firstChoice = aiResponse.choices.first else {
                    log(.error, "Provider returned no choices.", false)
                    broadcast("Empty choices in response", job, isBackground)
                    return
                }
                
                let message = firstChoice.message
                let finishReason = firstChoice.finishReason?.lowercased()
                
                // If Tool Calls requested
                if let toolCalls = message.toolCalls, !toolCalls.isEmpty {
                    messages.append(message)
                    log(.debug, "Provider requested \(toolCalls.count) tool call(s).", true)
                    
                    for toolCall in toolCalls {
                        print("🤖 [Agent] Tool call requested: \(toolCall.function.name)")
                        var toolOutput = ""
                        
                        if toolCall.function.name == "run_local_command" {
                            if let argsData = toolCall.function.arguments.data(using: .utf8),
                               let argsJSON = try? JSONSerialization.jsonObject(with: argsData) as? [String: Any],
                               let command = argsJSON["command"] as? String {
                                
                                if attemptedCommands.contains(command) {
                                    toolOutput = "Error executing command: Duplicate command attempt blocked to avoid loops. Previous attempt already used '\(command)'. Provide a final answer based on the available evidence."
                                    sawToolFailure = true
                                    log(.warning, "Blocked repeated command attempt: \(command)", false)
                                } else {
                                    attemptedCommands.insert(command)
                                    print("⚙️ [Agent] Executing local command: \(command)")
                                    log(.debug, "Running command: \(command)", true)
                                    do {
                                        toolOutput = try await LocalCommandExecutor.runSilentCommand(query: command, allowedCommands: allowedCommands)
                                        print("✅ [Agent] Command success. Output length: \(toolOutput.count)")
                                        log(.debug, "Command completed successfully.", true)
                                    } catch {
                                        sawToolFailure = true
                                        toolOutput = "Error executing command: \(error.localizedDescription). Stop using more tools unless a clearly different command is necessary. Give the user a short final answer that explains the failure and the best fix."
                                        print("❌ [Agent] Command failed: \(error.localizedDescription)")
                                        log(.error, "Command failed: \(error.localizedDescription)", false)
                                    }
                                }
                            } else {
                                toolOutput = "Error: Invalid JSON arguments generated by AI"
                                sawToolFailure = true
                                log(.error, "Provider returned invalid tool arguments.", false)
                            }
                        } else if toolCall.function.name == "notch_terminal" {
                            if let argsData = toolCall.function.arguments.data(using: .utf8),
                               let argsJSON = try? JSONSerialization.jsonObject(with: argsData) as? [String: Any],
                               let actionString = argsJSON["action"] as? String,
                               let action = NotchTerminalAgentToolAction(rawValue: actionString) {
                                let text = argsJSON["text"] as? String
                                let submit = argsJSON["submit"] as? Bool ?? false
                                await MainActor.run {
                                    var userInfo: [String: Any] = [NotchTerminalAgentToolUserInfoKey.action: action.rawValue]
                                    if let text {
                                        userInfo[NotchTerminalAgentToolUserInfoKey.text] = text
                                    }
                                    userInfo[NotchTerminalAgentToolUserInfoKey.submit] = submit
                                    NotificationCenter.default.post(
                                        name: .notchTerminalAgentToolRequested,
                                        object: nil,
                                        userInfo: userInfo
                                    )
                                }
                                if action == .writeText, let text, !text.isEmpty {
                                    toolOutput = submit
                                        ? "Wrote text and pressed Enter in NotchTerminal: \(text)"
                                        : "Wrote text in NotchTerminal without pressing Enter: \(text)"
                                } else {
                                    toolOutput = action.successMessage
                                }
                                log(.info, "Ran NotchTerminal app action: \(action.rawValue)", false)
                            } else {
                                toolOutput = "Error: Invalid notch_terminal action. Use open_terminal, restore_all_windows, or write_text."
                                sawToolFailure = true
                                log(.error, "Invalid notch_terminal tool arguments.", false)
                            }
                        } else if toolCall.function.name == "mac_app" {
                            if let argsData = toolCall.function.arguments.data(using: .utf8),
                               let argsJSON = try? JSONSerialization.jsonObject(with: argsData) as? [String: Any],
                               let actionString = argsJSON["action"] as? String,
                               let action = MacAppAgentToolAction(rawValue: actionString),
                               let bundleIdentifier = argsJSON["bundle_identifier"] as? String,
                               !bundleIdentifier.isEmpty {
                                let text = argsJSON["text"] as? String
                                let key = argsJSON["key"] as? String
                                toolOutput = await MainActor.run {
                                    MacAppAgentToolRunner.run(
                                        action: action,
                                        bundleIdentifier: bundleIdentifier,
                                        installedApps: job.installedApps,
                                        text: text,
                                        key: key
                                    )
                                }
                                if toolOutput.hasPrefix("Error:") {
                                    sawToolFailure = true
                                    log(.error, toolOutput, false)
                                } else {
                                    if action == .typeText || action == .pressKey {
                                        lastVisualActionTurn = currentTurn
                                        pendingVisualVerificationApp = job.installedApps.first(where: { $0.bundleIdentifier == bundleIdentifier })
                                    }
                                    log(.info, "Ran macOS app action: \(action.rawValue) for \(bundleIdentifier)", false)
                                }
                            } else {
                                toolOutput = "Error: Invalid mac_app action. Use open_app, activate_app, type_text, or press_key with a connected bundle_identifier."
                                sawToolFailure = true
                                log(.error, "Invalid mac_app tool arguments.", false)
                            }
                        } else if toolCall.function.name == "capture_app_window" {
                            if let argsData = toolCall.function.arguments.data(using: .utf8),
                               let argsJSON = try? JSONSerialization.jsonObject(with: argsData) as? [String: Any],
                               let bundleIdentifier = argsJSON["bundle_identifier"] as? String,
                               let app = job.installedApps.first(where: { $0.bundleIdentifier == bundleIdentifier }) {
                                let screenshotResult = await MainActor.run {
                                    ScreenCaptureService.capturePNGBase64(for: app)
                                }

                                switch screenshotResult {
                                case .success(let base64PNG):
                                    toolOutput = "Captured screenshot for \(app.displayName)."
                                    let screenshotFollowup = AIChatMessage(
                                        role: "user",
                                        content: .parts([
                                            AIChatContentPart(type: "text", text: "Here is the latest screenshot for @app:\(bundleIdentifier). Inspect the UI and continue the job."),
                                            AIChatContentPart(type: "image_url", imageURL: AIImageURLContent(url: "data:image/png;base64,\(base64PNG)"))
                                        ])
                                    )
                                    messages.append(AIChatMessage(role: "tool", text: toolOutput, toolCallId: toolCall.id))
                                    messages.append(screenshotFollowup)
                                    lastCaptureTurn = currentTurn
                                    pendingVisualVerificationApp = nil
                                    log(.info, "Captured app window for \(bundleIdentifier)", false)
                                case .failure(let error):
                                    toolOutput = "Error: \(error.localizedDescription)"
                                    sawToolFailure = true
                                    log(.error, toolOutput, false)
                                }
                            } else {
                                toolOutput = "Error: Invalid capture_app_window arguments. Use a connected bundle_identifier."
                                sawToolFailure = true
                                log(.error, "Invalid capture_app_window arguments.", false)
                            }
                        } else {
                            toolOutput = "Error: Unknown tool \(toolCall.function.name)"
                            sawToolFailure = true
                            log(.error, "Unknown tool requested: \(toolCall.function.name)", false)
                        }
                        
                        if toolCall.function.name != "capture_app_window" {
                            messages.append(AIChatMessage(role: "tool", text: toolOutput, toolCallId: toolCall.id))
                        }
                    }

                    if promptRequiresVisualVerification,
                       let app = pendingVisualVerificationApp,
                       let visualTurn = lastVisualActionTurn,
                       (lastCaptureTurn == nil || lastCaptureTurn! < visualTurn) {
                        let screenshotResult = await MainActor.run {
                            ScreenCaptureService.capturePNGBase64(for: app)
                        }

                        switch screenshotResult {
                        case .success(let base64PNG):
                            let toolMessage = "Captured final verification screenshot for \(app.displayName)."
                            messages.append(
                                AIChatMessage(
                                    role: "user",
                                    content: .parts([
                                        AIChatContentPart(type: "text", text: "Automatic final verification screenshot for @app:\(app.bundleIdentifier). Use this screenshot to verify the visible result before answering."),
                                        AIChatContentPart(type: "image_url", imageURL: AIImageURLContent(url: "data:image/png;base64,\(base64PNG)"))
                                    ])
                                )
                            )
                            lastCaptureTurn = currentTurn
                            pendingVisualVerificationApp = nil
                            log(.info, toolMessage, false)
                        case .failure(let error):
                            let failure = "FAILED: Final screenshot verification is required after the latest app interaction, but automatic capture failed. \(error.localizedDescription)"
                            log(.error, failure, false)
                            broadcast(failure, job, isBackground)
                            return
                        }
                    }

                    if currentTurn >= maxTurns {
                        if promptRequiresVisualVerification,
                           let visualTurn = lastVisualActionTurn,
                           lastCaptureTurn == nil || lastCaptureTurn! < visualTurn {
                            let failure = "FAILED: Final screenshot verification is required after the latest app interaction, but no final capture was completed."
                            log(.error, failure, false)
                            broadcast(failure, job, isBackground)
                            return
                        }
                        do {
                            let forcedAnswer = try await requestForcedFinalAnswer(
                                url: url,
                                provider: provider,
                                apiKey: apiKey,
                                finalModel: finalModel,
                                responseTokenLimit: responseTokenLimit,
                                requestTimeout: requestTimeout,
                                messages: messages,
                                sawToolFailure: sawToolFailure
                            )
                            if !forcedAnswer.isEmpty {
                                log(.success, "Run finished with a forced final answer.", false)
                                broadcast(forcedAnswer, job, isBackground)
                                return
                            }
                        } catch {
                            log(.warning, "Forced final answer failed: \(error.localizedDescription)", false)
                        }
                    }

                    continue
                }
                
                // Final answer
                let cleanContent = sanitizedFinalResponse(
                    content: message.content?.plainTextValue ?? "",
                    reasoningContent: message.reasoningContent
                )
                print("✅ [Agent] Final Message: \(cleanContent)")

                if promptRequiresVisualVerification,
                   let visualTurn = lastVisualActionTurn,
                   lastCaptureTurn == nil || lastCaptureTurn! < visualTurn {
                    let failure = "FAILED: Final screenshot verification is required after the latest app interaction, but no final capture was completed."
                    log(.error, failure, false)
                    broadcast(failure, job, isBackground)
                    return
                }

                if !cleanContent.isEmpty {
                    log(.success, "Run finished with a final answer.", false)
                    broadcast(cleanContent, job, isBackground)
                    return
                }

                if finishReason == "length" {
                    log(.warning, "Response hit token limit \(responseTokenLimit).", false)
                    broadcast("Response hit token limit (\(responseTokenLimit)). Try a shorter prompt or command output.", job, isBackground)
                    return
                }

                if currentTurn < maxTurns {
                    messages.append(message)
                    messages.append(
                        AIChatMessage(
                            role: "user",
                    text: sawToolFailure
                        ? "Reply now with a short final answer only. Do not call more tools unless a completely different command is essential. Explain the failure and the best next step."
                        : "Reply now with a short final answer only. Do not call tools unless strictly necessary."
                )
            )
                    continue
                }

                let reasoningFallback = sanitizedFinalResponse(content: "", reasoningContent: message.reasoningContent)
                log(.warning, reasoningFallback.isEmpty ? "Provider returned no final text." : "Using reasoning fallback as final answer.", false)
                broadcast(reasoningFallback.isEmpty ? "Provider returned no final text." : reasoningFallback, job, isBackground)
                return
                
            } catch {
                log(.error, "Request failed: \(error.localizedDescription)", false)
                broadcast("Request Failed: \(error.localizedDescription)", job, isBackground)
                print("❌ [Agent] Error: \(error.localizedDescription)")
                return
            }
        }
        
        log(.warning, "Agent reached max turns without a final answer.", false)
        broadcast("Agent reached max turns without a final answer.", job, isBackground)
    }

    private static func requestForcedFinalAnswer(
        url: URL,
        provider: String,
        apiKey: String,
        finalModel: String,
        responseTokenLimit: Int,
        requestTimeout: TimeInterval,
        messages: [AIChatMessage],
        sawToolFailure: Bool
    ) async throws -> String {
        let providerType = AIProviderType(rawValue: provider) ?? .custom
        let usesOpenAICompletionsTokenField = provider == AIProviderType.openai.rawValue && finalModel.lowercased().hasPrefix("gpt-5")

        var forcedMessages = messages
        forcedMessages.append(
            AIChatMessage(
                role: "user",
                text: sawToolFailure
                    ? "Stop calling tools. Write the final answer now using the command results and failures already collected. Mention blocked commands or offline services clearly."
                    : "Stop calling tools. Write the final answer now using the command results already collected."
            )
        )

        var requestObject = AIChatRequest(
            model: finalModel,
            messages: forcedMessages,
            tools: nil,
            toolChoice: "none",
            maxTokens: usesOpenAICompletionsTokenField ? nil : responseTokenLimit,
            maxCompletionTokens: usesOpenAICompletionsTokenField ? responseTokenLimit : nil
        )

        if provider == AIProviderType.openrouter.rawValue {
            requestObject.reasoning = AIReasoningSchema(enabled: true)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = requestTimeout
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if provider == AIProviderType.openrouter.rawValue {
            request.setValue("https://notchterminal.imarcodev.com", forHTTPHeaderField: "HTTP-Referer")
            request.setValue("NotchTerminal", forHTTPHeaderField: "X-Title")
        }
        request.httpBody = try JSONEncoder().encode(requestObject)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw CommandExecutionError.executionFailed("HTTP Error \(httpResponse.statusCode)")
        }

        let aiResponse = try JSONDecoder().decode(AIChatResponse.self, from: data)
        let message = aiResponse.choices.first?.message
        return sanitizedFinalResponse(content: message?.content?.plainTextValue ?? "", reasoningContent: message?.reasoningContent)
    }

    private func effectiveAllowedCommands(for job: AICronjob) -> Set<String> {
        Self.allowedCommands(for: job, defaults: .standard)
    }

    private static func availableToolSchemas(for job: AICronjob) -> [AIToolSchema] {
        var tools: [AIToolSchema] = [AIToolSchema.runLocalCommandTool]
        if job.connectedApps.contains(.notchTerminal) || job.prompt.contains(AICronjobConnectedApp.notchTerminal.promptToken) {
            tools.append(.notchTerminalTool)
        }
        if !job.installedApps.isEmpty || job.prompt.contains("@app:") {
            tools.append(.macAppTool)
            tools.append(.captureAppWindowTool)
        }
        return tools
    }

    private static func requiresVisualVerification(for prompt: String) -> Bool {
        let lowercased = prompt.localizedLowercase
        return lowercased.contains("capture_app_window")
            || lowercased.contains("screenshot")
            || lowercased.contains("inspect the screenshot")
            || lowercased.contains("visible result")
            || lowercased.contains("do not infer")
            || lowercased.contains("do not guess")
            || lowercased.contains("only answer using the final screenshot")
    }

    private static func allowedCommands(for job: AICronjob, defaults: UserDefaults) -> Set<String> {
        if job.usesDefaultAllowedCommands {
            return defaultAllowedCommands(from: defaults)
        }

        let commands = job.allowedCommands
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return Set(commands)
    }

    private static func defaultAllowedCommands(from defaults: UserDefaults) -> Set<String> {
        let rawList = defaults.string(forKey: AppPreferences.Keys.experimentalAIAgentWhitelist) ?? AppPreferences.Defaults.experimentalAIAgentWhitelist
        let commands = rawList.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return Set(commands)
    }

    private func recordLog(level: AICronjobLogLevel, message: String, for job: AICronjob, debugOnly: Bool) {
        guard !debugOnly || job.debugLoggingEnabled else { return }

        var store = aiCronjobLogsData
        store.append(AICronjobLogEntry(level: level, message: message), for: job.id)
        aiCronjobLogsData = store
    }

    private static func appendLog(level: AICronjobLogLevel, message: String, for job: AICronjob, defaults: UserDefaults, debugOnly: Bool) {
        guard !debugOnly || job.debugLoggingEnabled else { return }

        let key = AppPreferences.Keys.aiCronjobLogsData
        var store = defaults.string(forKey: key).flatMap(AICronjobLogStore.init(rawValue:)) ?? AICronjobLogStore()
        store.append(AICronjobLogEntry(level: level, message: message), for: job.id)
        defaults.set(store.rawValue, forKey: key)
    }

    private static func requestTextCompletion(
        systemPrompt: String,
        userPrompt: String,
        provider: String,
        apiKey: String,
        customURL: String,
        model: String
    ) async throws -> String {
        let safeURL = customURL.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(safeURL)/chat/completions") else {
            throw CommandExecutionError.executionFailed("Invalid provider URL.")
        }

        let providerType = AIProviderType(rawValue: provider) ?? .custom
        let finalModel = provider == AIProviderType.openrouter.rawValue ? "openrouter/free" : model
        let usesOpenAICompletionsTokenField = provider == AIProviderType.openai.rawValue && finalModel.lowercased().hasPrefix("gpt-5")
        let requestTimeout: TimeInterval = providerType == .minimax ? 90 : 45

        var requestObject = AIChatRequest(
            model: finalModel,
            messages: [
                AIChatMessage(role: "system", text: systemPrompt),
                AIChatMessage(role: "user", text: userPrompt)
            ],
            toolChoice: "none",
            maxTokens: usesOpenAICompletionsTokenField ? nil : providerType.defaultResponseTokenLimit,
            maxCompletionTokens: usesOpenAICompletionsTokenField ? providerType.defaultResponseTokenLimit : nil
        )

        if provider == AIProviderType.openrouter.rawValue {
            requestObject.reasoning = AIReasoningSchema(enabled: true)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = requestTimeout
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if provider == AIProviderType.openrouter.rawValue {
            request.setValue("https://notchterminal.imarcodev.com", forHTTPHeaderField: "HTTP-Referer")
            request.setValue("NotchTerminal", forHTTPHeaderField: "X-Title")
        }
        request.httpBody = try JSONEncoder().encode(requestObject)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            var errorMessage = "HTTP Error \(httpResponse.statusCode)"
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorObject = json["error"] as? [String: Any],
               let message = errorObject["message"] as? String {
                errorMessage = message
            }
            throw CommandExecutionError.executionFailed(errorMessage)
        }

        let completion = try JSONDecoder().decode(AIChatResponse.self, from: data)
        let text = completion.choices.first?.message.content?.plainTextValue.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else {
            throw CommandExecutionError.executionFailed("Provider returned an empty prompt suggestion.")
        }

        return text
    }
    
    private func broadcastMessage(_ text: String, job: AICronjob? = nil, isBackground: Bool = false) {
        let safeText = Self.stripThinkingArtifacts(from: text)
        let finalText = safeText.isEmpty ? text : safeText

        if isBackground, let job = job {
            let content = UNMutableNotificationContent()
            content.title = "NotchAgent: \(job.name)"
            content.body = finalText
            content.sound = .default
            
            let request = UNNotificationRequest(identifier: "notchagent-\(job.id.uuidString)", content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request) { error in
                if let error {
                    print("❌ [Agent] Notification Error: \(error.localizedDescription)")
                }
            }
        } else {
            if let job {
                let content = UNMutableNotificationContent()
                content.title = "NotchAgent: \(job.name)"
                content.body = finalText
                content.sound = .default

                let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                UNUserNotificationCenter.current().add(request) { error in
                    if let error {
                        print("❌ [Agent] Foreground Notification Error: \(error.localizedDescription)")
                    }
                }
            }

            let prefix = job != nil ? "[\(job!.name)] " : ""
            NotificationCenter.default.post(name: AICronjobManager.newMessageNotification, object: nil, userInfo: ["text": prefix + finalText])
        }
    }

    private static func mergedSystemPrompt(for providerType: AIProviderType, providerInstructions: String) -> String {
        var parts: [String] = [
            "You are a helpful assistant integrated into NotchTerminal on macOS. Keep answers short and practical. If tools fail, stop retrying the same failing strategy and instead explain the issue clearly. After any tool result, provide a final answer without requesting more tool calls unless a different command is truly required. If a command is blocked by the whitelist or a service is offline, say so directly and suggest the next useful fix. Never expose hidden chain-of-thought or reasoning tags such as <think>. Do not include internal reasoning in the final answer."
        ]

        parts.append("When the prompt mentions @notch-terminal, you may use the notch_terminal tool. Prefer action write_text with a text value when the user wants the terminal to type something, and set submit to true only when the text should actually be executed.")
        parts.append("When the prompt mentions @app:bundle.identifier, use the mac_app tool instead of the terminal. Prefer open_app to launch a connected macOS app, activate_app to bring it to the front, type_text to send text into the focused app, and press_key for keys like enter or tab.")
        parts.append("If you need to inspect the current UI of a connected macOS app, use capture_app_window and reason over the returned screenshot before deciding the next action.")

        let providerHint = providerCompatibilityHint(for: providerType)
        if !providerHint.isEmpty {
            parts.append(providerHint)
        }

        let trimmedInstructions = providerInstructions.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedInstructions.isEmpty {
            parts.append("Provider-specific instructions: \(trimmedInstructions)")
        }

        return parts.joined(separator: "\n\n")
    }

    private static func providerCompatibilityHint(for providerType: AIProviderType) -> String {
        switch providerType {
        case .minimax:
            return "MiniMax compatibility: use the OpenAI-compatible endpoint with concise outputs. Avoid exposing reasoning text. Prefer one direct command at a time, avoid shell pipes, and if a tool fails, stop quickly and provide a final diagnosis."
        case .custom:
            return "Custom provider compatibility: assume OpenAI-compatible chat completions unless told otherwise. Keep outputs concise and never expose hidden reasoning."
        default:
            return ""
        }
    }

    private static func sanitizedFinalResponse(content: String, reasoningContent: String?) -> String {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedContent = stripThinkingArtifacts(from: trimmedContent)
        if !cleanedContent.isEmpty {
            return cleanedContent
        }

        let fallback = (reasoningContent ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return stripThinkingArtifacts(from: fallback)
    }

    private static func stripThinkingArtifacts(from text: String) -> String {
        guard !text.isEmpty else { return "" }

        var cleaned = text.replacingOccurrences(
            of: "(?is)<think>.*?</think>",
            with: "",
            options: .regularExpression
        )

        let lowercased = cleaned.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if lowercased.hasPrefix("<think>") {
            return ""
        }

        cleaned = cleaned.replacingOccurrences(of: "<think>", with: "")
        cleaned = cleaned.replacingOccurrences(of: "</think>", with: "")
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
