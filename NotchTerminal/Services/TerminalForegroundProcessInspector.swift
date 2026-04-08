import Foundation
import Darwin

@_silgen_name("proc_listpids")
private func proc_listpids(_ type: UInt32, _ typeinfo: UInt32, _ buffer: UnsafeMutableRawPointer?, _ buffersize: Int32) -> Int32

@_silgen_name("proc_name")
private func proc_name(_ pid: Int32, _ buffer: UnsafeMutableRawPointer?, _ buffersize: UInt32) -> Int32

private let procPgrpOnly: UInt32 = 2

enum TerminalForegroundProcessInspector {
    static func branding(childFileDescriptor: Int32, shellPid: pid_t) -> CLICommandBranding? {
        guard childFileDescriptor >= 0, shellPid > 0 else { return nil }

        let foregroundGroup = tcgetpgrp(childFileDescriptor)
        guard foregroundGroup > 0 else { return nil }

        let pids = processIDs(inProcessGroup: foregroundGroup)
        guard !pids.isEmpty else { return nil }

        let shellExecutable = executableName(for: shellPid)
        let preferredPID = preferredProcessID(in: pids, shellPid: shellPid, shellExecutable: shellExecutable)
        guard let preferredPID else {
            return nil
        }

        let command = commandLine(for: preferredPID) ?? executableName(for: preferredPID)
        guard let command else { return nil }

        let branding = CLICommandBrandingResolver.branding(for: command)
        return branding.title == nil ? nil : branding
    }

    private static func preferredProcessID(
        in pids: [pid_t],
        shellPid: pid_t,
        shellExecutable: String?
    ) -> pid_t? {
        for pid in pids where pid != shellPid {
            guard let executable = executableName(for: pid) else { continue }
            if executable != shellExecutable {
                return pid
            }
        }

        return pids.first(where: { $0 != shellPid }) ?? pids.first
    }

    private static func processIDs(inProcessGroup processGroup: pid_t) -> [pid_t] {
        let byteCount = proc_listpids(procPgrpOnly, UInt32(processGroup), nil, 0)
        guard byteCount > 0 else { return [] }

        let count = Int(byteCount) / MemoryLayout<pid_t>.stride
        var buffer = Array(repeating: pid_t(0), count: count)
        let filledBytes = proc_listpids(
            procPgrpOnly,
            UInt32(processGroup),
            &buffer,
            Int32(buffer.count * MemoryLayout<pid_t>.stride)
        )
        guard filledBytes > 0 else { return [] }

        return buffer.filter { $0 > 0 }
    }

    private static func executableName(for pid: pid_t) -> String? {
        var buffer = Array(repeating: CChar(0), count: Int(MAXPATHLEN))
        let length = proc_name(Int32(pid), &buffer, UInt32(buffer.count))
        guard length > 0 else { return nil }
        return URL(fileURLWithPath: String(cString: buffer)).lastPathComponent.lowercased()
    }

    private static func commandLine(for pid: pid_t) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-p", String(pid), "-o", "command="]

        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return nil
        }

        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }

        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let output, !output.isEmpty else { return nil }
        return output.lowercased()
    }
}
