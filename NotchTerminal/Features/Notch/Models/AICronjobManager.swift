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
        
        let executablePath = Bundle.main.executablePath ?? "/Applications/NotchTerminal.app/Contents/MacOS/NotchTerminal"
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
        broadcastMessage(text, job: nil, isBackground: false)
    }
    
    public func triggerTest(for job: AICronjob) {
        Task {
            await fetchAIResponse(for: job)
        }
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
        
        let (provider, apiKey, customURL, model) = getActiveProviderConfig(from: defaults)
        
        await runAgentLoop(
            job: job,
            provider: provider,
            apiKey: apiKey,
            customURL: customURL,
            model: model,
            isBackground: true
        ) { text, jobRef, isBg in
            Task {
                await sendBackgroundNotification(title: "NotchAgent: \(jobRef?.name ?? "Unknown")", body: text)
            }
        }
    }
    
    private static func getActiveProviderConfig(from defaults: UserDefaults) -> (provider: String, apiKey: String, customURL: String, model: String) {
        if let providersRaw = defaults.string(forKey: AppPreferences.Keys.aiProvidersData),
           let providersData = providersRaw.data(using: .utf8),
           let providersList = try? JSONDecoder().decode(AIProviderList.self, from: providersData),
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
        let (provider, apiKey, customURL, model) = activeProviderConfig
        
        await Self.runAgentLoop(
            job: job,
            provider: provider,
            apiKey: apiKey,
            customURL: customURL,
            model: model,
            isBackground: isBackground
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
    
    // MARK: - Core Multi-Turn Agent Loop
    
    private static func runAgentLoop(
        job: AICronjob,
        provider: String,
        apiKey: String,
        customURL: String,
        model: String,
        isBackground: Bool,
        broadcast: @escaping (String, AICronjob?, Bool) -> Void
    ) async {
        guard !apiKey.isEmpty else {
            broadcast("API Key Missing", job, isBackground)
            return
        }

        let baseURL = customURL
        
        let safeURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(safeURL)/chat/completions") else { 
            broadcast("Invalid URL", job, isBackground)
            return 
        }
        
        var messages: [AIChatMessage] = [
            AIChatMessage(role: "system", content: "You are a helpful assistant integrated into a macOS Notch widget. Keep your answers extremely short, ideally 1 sentence or a few words. If the user asks about the state of their system, dockers, files, or processes, ALWAYS use the 'run_local_command' tool to fetch the real data. NEVER guess or output raw bash code in your response message."),
            AIChatMessage(role: "user", content: job.prompt)
        ]
        
        let providerType = AIProviderType(rawValue: provider) ?? .custom
        let finalModel = provider == "openrouter" ? "openrouter/free" : model
        let responseTokenLimit = providerType.defaultResponseTokenLimit
        let usesOpenAICompletionsTokenField = provider == AIProviderType.openai.rawValue && finalModel.lowercased().hasPrefix("gpt-5")
        let maxTurns = 5
        var currentTurn = 0
        
        while currentTurn < maxTurns {
            currentTurn += 1
            
            var requestObj = AIChatRequest(
                model: finalModel,
                messages: messages,
                tools: [AIToolSchema.runLocalCommandTool],
                toolChoice: "auto",
                maxTokens: usesOpenAICompletionsTokenField ? nil : responseTokenLimit,
                maxCompletionTokens: usesOpenAICompletionsTokenField ? responseTokenLimit : nil
            )
            
            if provider == "openrouter" {
                requestObj.reasoning = AIReasoningSchema(enabled: true)
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if provider == "openrouter" {
                request.setValue("https://notchterminal.imarcodev.com", forHTTPHeaderField: "HTTP-Referer")
                request.setValue("NotchTerminal", forHTTPHeaderField: "X-Title")
            }
            
            let encoder = JSONEncoder()
            guard let httpBody = try? encoder.encode(requestObj) else {
                broadcast("Failed to encode request", job, isBackground)
                return
            }
            request.httpBody = httpBody
            
            do {
                if currentTurn == 1 {
                    print("🚀 [Agent] Sending request for job: '\(job.name)' using model: \(finalModel)")
                }
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                    var errMsg = "HTTP Error \(httpResponse.statusCode)"
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errorObj = json["error"] as? [String: Any],
                       let msg = errorObj["message"] as? String {
                        errMsg = msg
                    }
                    broadcast("API Error: \(errMsg)", job, isBackground)
                    return
                }
                
                let decoder = JSONDecoder()
                let aiResponse = try decoder.decode(AIChatResponse.self, from: data)
                guard let firstChoice = aiResponse.choices.first else {
                    broadcast("Empty choices in response", job, isBackground)
                    return
                }
                
                let message = firstChoice.message
                let finishReason = firstChoice.finishReason?.lowercased()
                
                // If Tool Calls requested
                if let toolCalls = message.toolCalls, !toolCalls.isEmpty {
                    messages.append(message)
                    
                    for toolCall in toolCalls {
                        print("🤖 [Agent] Tool call requested: \(toolCall.function.name)")
                        var toolOutput = ""
                        
                        if toolCall.function.name == "run_local_command" {
                            if let argsData = toolCall.function.arguments.data(using: .utf8),
                               let argsJSON = try? JSONSerialization.jsonObject(with: argsData) as? [String: Any],
                               let command = argsJSON["command"] as? String {
                                
                                print("⚙️ [Agent] Executing local command: \(command)")
                                do {
                                    toolOutput = try await LocalCommandExecutor.runSilentCommand(query: command)
                                    print("✅ [Agent] Command success. Output length: \(toolOutput.count)")
                                } catch {
                                    toolOutput = "Error executing command: \(error.localizedDescription)"
                                    print("❌ [Agent] Command failed: \(error.localizedDescription)")
                                }
                            } else {
                                toolOutput = "Error: Invalid JSON arguments generated by AI"
                            }
                        } else {
                            toolOutput = "Error: Unknown tool \(toolCall.function.name)"
                        }
                        
                        messages.append(AIChatMessage(role: "tool", content: toolOutput, toolCallId: toolCall.id))
                    }
                    continue
                }
                
                // Final answer
                let cleanContent = (message.content ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                print("✅ [Agent] Final Message: \(cleanContent)")

                if !cleanContent.isEmpty {
                    broadcast(cleanContent, job, isBackground)
                    return
                }

                if finishReason == "length" {
                    broadcast("Response hit token limit (\(responseTokenLimit)). Try a shorter prompt or command output.", job, isBackground)
                    return
                }

                if currentTurn < maxTurns {
                    messages.append(message)
                    messages.append(
                        AIChatMessage(
                            role: "user",
                            content: "Reply now with a short final answer only. Do not call tools unless strictly necessary."
                        )
                    )
                    continue
                }

                let reasoningFallback = (message.reasoningContent ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                broadcast(reasoningFallback.isEmpty ? "Provider returned no final text." : reasoningFallback, job, isBackground)
                return
                
            } catch {
                broadcast("Request Failed: \(error.localizedDescription)", job, isBackground)
                print("❌ [Agent] Error: \(error.localizedDescription)")
                return
            }
        }
        
        broadcast("Agent reached max turns without a final answer.", job, isBackground)
    }
    
    private func broadcastMessage(_ text: String, job: AICronjob? = nil, isBackground: Bool = false) {
        if isBackground, let job = job {
            let content = UNMutableNotificationContent()
            content.title = "NotchAgent: \(job.name)"
            content.body = text
            content.sound = .default
            
            let request = UNNotificationRequest(identifier: "notchagent-\(job.id.uuidString)", content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request) { error in
                if let error {
                    print("❌ [Agent] Notification Error: \(error.localizedDescription)")
                }
            }
        } else {
            let prefix = job != nil ? "[\(job!.name)] " : ""
            NotificationCenter.default.post(name: AICronjobManager.newMessageNotification, object: nil, userInfo: ["text": prefix + text])
        }
    }
}
