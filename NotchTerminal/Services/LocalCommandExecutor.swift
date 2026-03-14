import Foundation

public enum CommandExecutionError: LocalizedError {
    case blockedCommand(String)
    case invalidCharacters(String)
    case timeout
    case executionFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .blockedCommand(let base): return "Command '\(base)' is not allowed by the security whitelist."
        case .invalidCharacters(let char): return "Command contains potentially unsafe character: '\(char)'"
        case .timeout: return "Command execution timed out."
        case .executionFailed(let msg): return "Command failed: \(msg)"
        }
    }
}

public struct LocalCommandExecutor {
    
    /// The whitelist of safe base commands that NotchAgent is allowed to execute silently.
    /// Loaded dynamically from UserDefaults so the user can configure it in Settings.
    public static var allowedCommands: Set<String> {
        let rawList = UserDefaults.standard.string(forKey: "experimentalAIAgentWhitelist") ?? 
            "ls, cat, pwd, whoami, date, uptime, sysctl, system_profiler, docker, pmset, df, du, git, top, ps, netstat, lsof, ifconfig, ping, curl, vm_stat, memory_pressure"
        
        let commands = rawList.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        return Set(commands)
    }
    
    /// Characters highly associated with shell injection and chaining that are expressly forbidden
    /// even if the base command is in the whitelist.
    public static let forbiddenCharacters: [Character] = [
        "|", ">", "<", "&", ";", "`", "$", "\\"
    ]
    
    public static func validate(command: String) throws {
        // 1. Check for injection characters
        for char in forbiddenCharacters {
            if command.contains(char) {
                throw CommandExecutionError.invalidCharacters(String(char))
            }
        }
        
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw CommandExecutionError.blockedCommand("empty")
        }
        
        // 2. Extract base command
        let parts = trimmed.components(separatedBy: .whitespaces)
        guard let base = parts.first else {
            throw CommandExecutionError.blockedCommand("unknown")
        }
        
        // 3. Verify it's in the whitelist
        if !allowedCommands.contains(base) {
            throw CommandExecutionError.blockedCommand(base)
        }
        
        // 4. Special cases & safety limits
        // 'top' must be constrained to run once, otherwise it blocks forever
        if base == "top" && !command.contains("-l 1") {
            throw CommandExecutionError.blockedCommand("top without -l 1")
        }
        
        // Block 'docker rm' or 'docker rmi' or 'docker stop' to enforce read-only
        if base == "docker" {
            let destructiveKeywords = ["rm", "rmi", "stop", "kill", "restart", "prune", "system"]
            for kw in destructiveKeywords {
                if command.contains(kw) {
                    throw CommandExecutionError.blockedCommand("docker \(kw)")
                }
            }
        }
        
        if base == "git" {
            let destructiveMods = ["clean", "reset", "checkout", "push", "commit", "rm"]
            for mod in destructiveMods {
                let pattern = "\\b\(mod)\\b"
                if command.range(of: pattern, options: .regularExpression) != nil {
                    throw CommandExecutionError.blockedCommand("git \(mod)")
                }
            }
        }
    }
    
    /// Executes a shell command synchronously and captures its standard output and errors.
    /// Traverses the user's defined paths to find the executable.
    public static func runSilentCommand(query: String) async throws -> String {
        try validate(command: query)
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { // run off main thread
                let task = Process()
                let pipe = Pipe()
                
                // We run via zsh -c to allow the user's PATH vars to pick up `docker` or `git`
                // But since we validated `query` against injections, it's safer.
                task.executableURL = URL(fileURLWithPath: "/bin/zsh")
                // Use limited PATH to find standard binaries
                var env = ProcessInfo.processInfo.environment
                env["PATH"] = "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin"
                task.environment = env
                
                task.arguments = ["-c", query]
                task.standardOutput = pipe
                task.standardError = pipe
                
                let outputHandle = pipe.fileHandleForReading
                
                do {
                    try task.run()
                    
                    // Start reading output asynchronously to prevent pipe buffer deadlock
                    var outputData = Data()
                    let readGroup = DispatchGroup()
                    readGroup.enter()
                    
                    outputHandle.readabilityHandler = { handle in
                        let handleData = handle.availableData
                        if handleData.isEmpty {
                            outputHandle.readabilityHandler = nil
                            readGroup.leave()
                        } else {
                            outputData.append(handleData)
                        }
                    }
                    
                    var didTimeout = false
                    let timeoutWorkItem = DispatchWorkItem {
                        if task.isRunning {
                            didTimeout = true
                            task.terminate()
                        }
                    }
                    DispatchQueue.global().asyncAfter(deadline: .now() + 10.0, execute: timeoutWorkItem)
                    
                    task.waitUntilExit()
                    timeoutWorkItem.cancel()
                    
                    // Wait briefly for the pipe reading to finish flushing
                    _ = readGroup.wait(timeout: .now() + 2.0)
                    
                    if didTimeout {
                        continuation.resume(throwing: CommandExecutionError.timeout)
                        return
                    }
                    
                    let output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    
                    if task.terminationStatus != 0 {
                        let msg = output.isEmpty ? "Status code \(task.terminationStatus)" : output
                        continuation.resume(throwing: CommandExecutionError.executionFailed(msg))
                    } else {
                        // Truncate output to prevent hitting token limits on massive outputs
                        let truncated = output.count > 4000 ? String(output.prefix(4000)) + "\n...[Output truncated]..." : output
                        continuation.resume(returning: truncated)
                    }
                    
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
