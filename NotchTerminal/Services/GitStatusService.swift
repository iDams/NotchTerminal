import Foundation
import Combine

/// Service to query and monitor the Git status of a given directory.
public class GitStatusService: ObservableObject {
    @Published public private(set) var status: ProjectStatus = ProjectStatus()
    
    private var targetDirectory: URL
    private var updateTimer: Timer?
    
    public init(targetDirectory: URL) {
        self.targetDirectory = targetDirectory
        updateStatus()
    }
    
    public func updateDirectory(_ url: URL) {
        self.targetDirectory = url
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
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let branch = self.getCurrentBranch()
            let hasChanges = self.checkPendingChanges()
            
            DispatchQueue.main.async {
                self.status.branchName = branch
                self.status.hasPendingChanges = hasChanges
            }
        }
    }
    
    private func getCurrentBranch() -> String? {
        let output = runGitCommand(args: ["rev-parse", "--abbrev-ref", "HEAD"])
        let branch = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return branch.isEmpty || branch.contains("fatal:") ? nil : branch
    }
    
    private func checkPendingChanges() -> Bool {
        let output = runGitCommand(args: ["status", "--porcelain"])
        return !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func runGitCommand(args: [String]) -> String {
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
