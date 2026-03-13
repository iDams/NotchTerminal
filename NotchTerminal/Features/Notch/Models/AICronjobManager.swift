import Foundation
import SwiftUI
import Combine
import UserNotifications

@MainActor
public final class AICronjobManager: ObservableObject {
    public static let shared = AICronjobManager()
    
    @AppStorage(AppPreferences.Keys.experimentalFloatingMsgEnabled) private var experimentalFloatingMsgEnabled = AppPreferences.Defaults.experimentalFloatingMsgEnabled
    @AppStorage(AppPreferences.Keys.experimentalAIProvider) private var experimentalAIProvider = AppPreferences.Defaults.experimentalAIProvider
    @AppStorage(AppPreferences.Keys.experimentalAICustomURL) private var experimentalAICustomURL = AppPreferences.Defaults.experimentalAICustomURL
    @AppStorage(AppPreferences.Keys.experimentalAIApiKey) private var experimentalAIApiKey = AppPreferences.Defaults.experimentalAIApiKey
    @AppStorage(AppPreferences.Keys.experimentalAIModel) private var experimentalAIModel = AppPreferences.Defaults.experimentalAIModel
    @AppStorage(AppPreferences.Keys.experimentalAICronjobsData) private var experimentalAICronjobsData = AppPreferences.Defaults.experimentalAICronjobsData
    
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
        
        // Read cronjobs from UserDefaults directly
        guard let rawData = defaults.string(forKey: AppPreferences.Keys.experimentalAICronjobsData),
              let jsonData = rawData.data(using: .utf8),
              let jobs = try? JSONDecoder().decode([AICronjob].self, from: jsonData),
              let job = jobs.first(where: { $0.id == uuid && $0.isEnabled && $0.mode == .machine }) else {
            print("❌ [BackgroundJob] Job not found or disabled")
            return
        }
        
        let provider = defaults.string(forKey: AppPreferences.Keys.experimentalAIProvider) ?? "openai"
        let apiKey = defaults.string(forKey: AppPreferences.Keys.experimentalAIApiKey) ?? ""
        let customURL = defaults.string(forKey: AppPreferences.Keys.experimentalAICustomURL) ?? "https://api.openai.com/v1"
        let model = defaults.string(forKey: AppPreferences.Keys.experimentalAIModel) ?? "gpt-3.5-turbo"
        
        guard !apiKey.isEmpty else {
            print("❌ [BackgroundJob] API Key is empty")
            await sendBackgroundNotification(title: "NotchAgent: \(job.name)", body: "API Key Missing")
            return
        }
        
        let baseURL: String
        switch provider {
        case "openrouter": baseURL = "https://openrouter.ai/api/v1"
        case "custom": baseURL = customURL
        default: baseURL = "https://api.openai.com/v1"
        }
        
        let safeURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(safeURL)/chat/completions") else {
            await sendBackgroundNotification(title: "NotchAgent: \(job.name)", body: "Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if provider == "openrouter" {
            request.setValue("https://notchterminal.app", forHTTPHeaderField: "HTTP-Referer")
            request.setValue("NotchTerminal", forHTTPHeaderField: "X-Title")
        }
        
        let finalModel = provider == "openrouter" ? "openrouter/free" : model
        var body: [String: Any] = [
            "model": finalModel,
            "messages": [
                ["role": "system", "content": "You are a helpful assistant integrated into a macOS Notch widget. Keep your answers extremely short, ideally 1 sentence or a few words."],
                ["role": "user", "content": job.prompt]
            ],
            "max_tokens": 250
        ]
        if provider == "openrouter" {
            body["reasoning"] = ["enabled": true]
        }
        
        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else { return }
        request.httpBody = httpBody
        
        do {
            print("🚀 [BackgroundJob] Sending request to \(safeURL)/chat/completions")
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let rawString = String(data: data, encoding: .utf8) {
                print("📦 [BackgroundJob] Raw Response:\n\(rawString)")
            }
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                var errMsg = "HTTP Error \(httpResponse.statusCode)"
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorObj = json["error"] as? [String: Any],
                   let msg = errorObj["message"] as? String {
                    errMsg = msg
                }
                await sendBackgroundNotification(title: "NotchAgent: \(job.name)", body: errMsg)
                return
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let firstChoice = choices.first,
               let message = firstChoice["message"] as? [String: Any],
               let content = message["content"] as? String {
                let clean = content.trimmingCharacters(in: .whitespacesAndNewlines)
                print("✅ [BackgroundJob] AI Response: \(clean)")
                await sendBackgroundNotification(title: "NotchAgent: \(job.name)", body: clean.isEmpty ? "Empty response" : clean)
            } else {
                await sendBackgroundNotification(title: "NotchAgent: \(job.name)", body: "Unexpected API response format")
            }
        } catch {
            print("❌ [BackgroundJob] Error: \(error.localizedDescription)")
            await sendBackgroundNotification(title: "NotchAgent: \(job.name)", body: "Request Failed: \(error.localizedDescription)")
        }
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
        guard (experimentalAIProvider == "openai" || experimentalAIProvider == "custom" || experimentalAIProvider == "openrouter"), !experimentalAIApiKey.isEmpty else {
            broadcastMessage("[\(job.name)] API Key Missing", job: job, isBackground: isBackground)
            return
        }

        let baseURL: String
        switch experimentalAIProvider {
        case "openrouter": baseURL = "https://openrouter.ai/api/v1"
        case "custom": baseURL = experimentalAICustomURL
        default: baseURL = "https://api.openai.com/v1"
        }
        
        let safeURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        
        guard let url = URL(string: "\(safeURL)/chat/completions") else { 
            broadcastMessage("[\(job.name)] Invalid URL", job: job, isBackground: isBackground)
            return 
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(experimentalAIApiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Specific handling for OpenRouter
        if experimentalAIProvider == "openrouter" {
            request.setValue("https://notchterminal.app", forHTTPHeaderField: "HTTP-Referer")
            request.setValue("NotchTerminal", forHTTPHeaderField: "X-Title")
        }

        let finalModel = experimentalAIProvider == "openrouter" ? "openrouter/free" : experimentalAIModel

        var body: [String: Any] = [
            "model": finalModel,
            "messages": [
                ["role": "system", "content": "You are a helpful assistant integrated into a macOS Notch widget. Keep your answers extremely short, ideally 1 sentence or a few words."],
                ["role": "user", "content": job.prompt]
            ],
            "max_tokens": 250
        ]
        
        if experimentalAIProvider == "openrouter" {
            body["reasoning"] = ["enabled": true]
        }

        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else { return }
        request.httpBody = httpBody

        do {
            print("🚀 [AI Cronjob] Sending request for job: '\(job.name)' to \(safeURL)/chat/completions using model: \(experimentalAIModel)")
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let rawString = String(data: data, encoding: .utf8) {
                print("📦 [AI Cronjob] Raw Response from '\(job.name)':\n\(rawString)")
            }
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorObj = json["error"] as? [String: Any],
                   let errMsg = errorObj["message"] as? String {
                    broadcastMessage("[\(job.name)] API Error: \(errMsg)", job: job, isBackground: isBackground)
                } else {
                    broadcastMessage("[\(job.name)] HTTP Error \(httpResponse.statusCode)", job: job, isBackground: isBackground)
                }
                return
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let firstChoice = choices.first,
               let message = firstChoice["message"] as? [String: Any] {
                
                let content = message["content"] as? String ?? ""
                let cleanContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
                print("✅ [AI Cronjob] Parsed AI Message: \(cleanContent)")
                broadcastMessage(cleanContent.isEmpty ? "Empty Response (Hit token limit while thinking?)" : cleanContent, job: job, isBackground: isBackground)
            } else {
                print("❌ [AI Cronjob] Error: Could not parse expected JSON format from choices.message.content")
                broadcastMessage("Unexpected API Response format", job: job, isBackground: isBackground)
            }
        } catch {
            broadcastMessage("Request Failed: \(error.localizedDescription)", job: job, isBackground: isBackground)
            print("AI Cronjob Error [\(job.name)]: \(error.localizedDescription)")
        }
    }
    
    private func broadcastMessage(_ text: String, job: AICronjob? = nil, isBackground: Bool = false) {
        if isBackground, let job = job {
            let content = UNMutableNotificationContent()
            content.title = "NotchAgent: \(job.name)"
            content.body = text
            content.sound = .default
            
            let request = UNNotificationRequest(identifier: "notchagent-\(job.id.uuidString)", content: content, trigger: nil)
            try? UNUserNotificationCenter.current().add(request)
        } else {
            let prefix = job != nil ? "[\(job!.name)] " : ""
            NotificationCenter.default.post(name: AICronjobManager.newMessageNotification, object: nil, userInfo: ["text": prefix + text])
        }
    }
}
