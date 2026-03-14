import Foundation
import Combine

/// Service to query and monitor the Git status of a given directory.
public class GitStatusService: ObservableObject {
    @Published public private(set) var status: ProjectStatus = ProjectStatus()
    
    private var targetDirectory: URL
    private var updateTimer: Timer?
    
    // Global cache to prevent visual flashing when switching terminals
    private static var statusCache: [URL: ProjectStatus] = [:]
    
    public init(targetDirectory: URL) {
        self.targetDirectory = targetDirectory
        if let cached = Self.statusCache[targetDirectory] {
            self.status = cached
        }
        updateStatus()
    }
    
    public func updateDirectory(_ url: URL) {
        self.targetDirectory = url
        if let cached = Self.statusCache[url] {
            self.status = cached
        } else {
            // Clear current status temporarily until the async update finishes
            self.status = ProjectStatus()
        }
        updateStatus()
    }
    
    deinit {
        stopMonitoring()
    }
    
    public func startMonitoring(interval: TimeInterval = 2.0) {
        stopMonitoring()
        updateTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.updateStatus()
        }
    }
    
    public func stopMonitoring() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    public func updateStatus() {
        let currentTarget = self.targetDirectory
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let branch = self.getCurrentBranch(for: currentTarget)
            let hasChanges = self.checkPendingChanges(for: currentTarget)
            
            DispatchQueue.main.async {
                // Ensure we haven't changed directories while the background task was running
                guard self.targetDirectory == currentTarget else { return }
                
                self.status.branchName = branch
                self.status.hasPendingChanges = hasChanges
                Self.statusCache[currentTarget] = self.status
            }
        }
    }
    
    private func getCurrentBranch(for target: URL) -> String? {
        let output = runGitCommand(args: ["rev-parse", "--abbrev-ref", "HEAD"], in: target)
        let branch = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return branch.isEmpty || branch.contains("fatal:") ? nil : branch
    }
    
    private func checkPendingChanges(for target: URL) -> Bool {
        let output = runGitCommand(args: ["status", "--porcelain"], in: target)
        return !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func runGitCommand(args: [String], in target: URL) -> String {
        let task = Process()
        let pipe = Pipe()
        
        task.standardOutput = pipe
        task.standardError = pipe
        task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        task.arguments = args
        task.currentDirectoryURL = targetDirectory
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }
}
