import Foundation

struct StorageCleanupUsageProcess: Hashable, Identifiable {
    let pid: Int
    let command: String
    let path: String?

    var id: String { "\(pid)-\(command)" }
}

struct StorageCleanupUsageFinding: Hashable, Identifiable {
    let item: StorageCleanupItem
    let processes: [StorageCleanupUsageProcess]
    let didTimeOut: Bool

    var id: String { item.id }
}

enum StorageCleanupUsageDiagnostics {
    private static let lsofURL = URL(fileURLWithPath: "/usr/sbin/lsof")

    static func inspect(items: [StorageCleanupItem], maxItems: Int = 6) -> [StorageCleanupUsageFinding] {
        items.prefix(maxItems).compactMap { item in
            inspect(item: item)
        }
    }

    private static func inspect(item: StorageCleanupItem) -> StorageCleanupUsageFinding? {
        let exactUsage = runLsof(arguments: ["-nP", "-w", "-Fpcfn", "--", item.path], timeout: 1.2)
        let cwdUsage = runLsof(arguments: ["-nP", "-w", "-a", "-d", "cwd", "-Fpcfn", "--", item.path], timeout: 1.0)

        var recursiveUsage: CommandResult?
        if item.url.hasDirectoryPath {
            recursiveUsage = runLsof(arguments: ["-nP", "-w", "+D", item.path, "-Fpcfn"], timeout: 2.0)
        }

        let processes = mergedProcesses(from: [exactUsage, cwdUsage, recursiveUsage])
        let timedOut = [exactUsage, cwdUsage, recursiveUsage].contains(where: { $0?.timedOut == true })

        guard !processes.isEmpty || timedOut else { return nil }
        return StorageCleanupUsageFinding(item: item, processes: Array(processes.prefix(6)), didTimeOut: timedOut)
    }

    private static func mergedProcesses(from results: [CommandResult?]) -> [StorageCleanupUsageProcess] {
        var deduplicated: [StorageCleanupUsageProcess] = []
        var seen = Set<String>()

        for result in results {
            guard let result else { continue }
            for process in parseLsofMachineOutput(result.output) {
                guard seen.insert(process.id).inserted else { continue }
                deduplicated.append(process)
            }
        }

        return deduplicated.sorted { lhs, rhs in
            lhs.command == rhs.command ? lhs.pid < rhs.pid : lhs.command.localizedStandardCompare(rhs.command) == .orderedAscending
        }
    }

    private static func parseLsofMachineOutput(_ output: String) -> [StorageCleanupUsageProcess] {
        var entries: [StorageCleanupUsageProcess] = []
        var currentPID: Int?
        var currentCommand = "unknown"
        var currentPath: String?
        var seen = Set<String>()

        for line in output.split(separator: "\n").map(String.init) {
            guard let field = line.first else { continue }
            let value = String(line.dropFirst())

            switch field {
            case "p":
                currentPID = Int(value)
                currentPath = nil
            case "c":
                currentCommand = value
            case "n":
                currentPath = value
                if let pid = currentPID {
                    let process = StorageCleanupUsageProcess(pid: pid, command: currentCommand, path: currentPath)
                    guard seen.insert(process.id).inserted else { continue }
                    entries.append(process)
                }
            default:
                continue
            }
        }

        return entries
    }

    private static func runLsof(arguments: [String], timeout: TimeInterval) -> CommandResult? {
        let process = Process()
        process.executableURL = lsofURL
        process.arguments = arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        let semaphore = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in
            semaphore.signal()
        }

        do {
            try process.run()
        } catch {
            return nil
        }

        let didFinish = semaphore.wait(timeout: .now() + timeout) == .success
        if !didFinish {
            process.terminate()
            _ = semaphore.wait(timeout: .now() + 0.2)
        }

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let combinedData = outputData.isEmpty ? errorData : outputData

        return CommandResult(
            output: String(decoding: combinedData, as: UTF8.self),
            timedOut: !didFinish
        )
    }
}

private struct CommandResult {
    let output: String
    let timedOut: Bool
}
