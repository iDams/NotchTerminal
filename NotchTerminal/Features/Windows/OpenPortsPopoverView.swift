import SwiftUI
import AppKit

struct OpenPortsPopoverView: View {
    private enum PortScope: CaseIterable, Identifiable {
        case dev
        case all
        var id: Self { self }
        var localizedTitle: String {
            switch self {
            case .dev: return "openPorts.scope.dev".localized
            case .all: return "openPorts.scope.all".localized
            }
        }
    }

    let ports: [OpenPortEntry]
    let isLoading: Bool
    let message: String?
    let onRefresh: () -> Void
    let onKill: (OpenPortEntry) -> Void
    @State private var scope: PortScope = .dev
    @State private var searchText = ""

    private var primaryText: SwiftUI.Color { .primary }
    private var secondaryText: SwiftUI.Color { .secondary }
    private var subtleText: SwiftUI.Color { .secondary.opacity(0.8) }
    private var cardStroke: SwiftUI.Color { .primary.opacity(0.1) }

    private var searchedPorts: [OpenPortEntry] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ports
        }
        let query = searchText.lowercased()
        return ports.filter {
            String($0.port).contains(query) ||
            String($0.pid).contains(query) ||
            $0.command.lowercased().contains(query) ||
            $0.endpoint.lowercased().contains(query)
        }
    }

    private var visiblePorts: [OpenPortEntry] {
        scope == .all ? searchedPorts : searchedPorts.filter(\.isLikelyDev)
    }

    private var devPorts: [OpenPortEntry] {
        visiblePorts.filter(\.isLikelyDev)
    }

    private var otherPorts: [OpenPortEntry] {
        visiblePorts.filter { !$0.isLikelyDev }
    }

    var body: some View {
        popoverBody
    }

    private var popoverBody: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerRow
            scopeRow
            searchRow
            contentStateView
        }
        .padding(16)
        .frame(width: 340, height: 420, alignment: .top)
        // Removed `.glassEffectWithFallback(.container, ...)` because macOS .popover creates its own VisualEffect window.
        // Doing this removes the "double background" and gray arrow mismatch.
    }

    private var headerRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 8) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
                Text("openPorts.title".localized)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(primaryText)
                
                Spacer()
                
                Button(action: onRefresh) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 16))
                        .foregroundStyle(primaryText.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
            Text("\(devPorts.count) dev • \(otherPorts.count) other")
                .font(.caption)
                .foregroundStyle(secondaryText)
        }
    }

    private var scopeRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("SCOPE")
            
            HStack(spacing: 4) {
                scopeButton(.dev)
                scopeButton(.all)
            }
            .padding(4)
            .glassEffectWithFallback(.input, in: .capsule)
        }
    }

    private var searchRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("FILTER")
            
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(subtleText)
                TextField("openPorts.search.placeholder".localized, text: $searchText)
                    .textFieldStyle(.plain)
                    .foregroundStyle(primaryText)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(subtleText)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .glassEffectWithFallback(.input, in: .capsule)
        }
    }

    @ViewBuilder
    private var contentStateView: some View {
        if isLoading {
            ProgressView("openPorts.scanning".localized)
                .controlSize(.small)
                .tint(primaryText)
        } else if let message {
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else {
            ScrollView {
                VStack(spacing: 8) {
                    sectionLabel("PORTS")
                    if !devPorts.isEmpty {
                        ForEach(devPorts) { port in
                            portRow(port)
                        }
                    }

                    if scope == .all, !otherPorts.isEmpty {
                        ForEach(otherPorts) { port in
                            portRow(port)
                        }
                    }

                    if visiblePorts.isEmpty {
                        Text(scope == .all ? "openPorts.empty.all".localized : "openPorts.empty.dev".localized)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 10)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    @ViewBuilder
    private func scopeButton(_ value: PortScope) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.25)) {
                scope = value
            }
        } label: {
            Text(value.localizedTitle)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(scope == value ? primaryText : secondaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(
                    Group {
                        if scope == value {
                            Capsule().fill(Color.primary.opacity(0.12))
                                .overlay(Capsule().stroke(Color.primary.opacity(0.1), lineWidth: 0.5))
                        } else {
                            Color.clear
                        }
                    }
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .kerning(0.5)
            .foregroundStyle(secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
    }

    @ViewBuilder
    private func portRow(_ port: OpenPortEntry) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(port.isLikelyDev ? Color.green : Color.gray)
                .frame(width: 8, height: 8)

            Text(":\(String(port.port)) \(port.command)")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(primaryText)

            Spacer()
            
            Button {
                onKill(port)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.primary)
                    .padding(6)
                    .background(Color.primary.opacity(0.1), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .glassEffectWithFallback(port.isLikelyDev ? .prominent : .regular, in: .capsule)
    }
}

private extension View {
    @ViewBuilder
    func ifLet<T, Content: View>(_ optional: T?, transform: (Self, T) -> Content) -> some View {
        if let optional {
            transform(self, optional)
        } else {
            self
        }
    }
}

enum GlassEffectStyleForFallback {
    case container
    case regular
    case prominent
    case input
}

extension View {
    @ViewBuilder
    func glassEffectWithFallback(
        _ style: GlassEffectStyleForFallback = .regular,
        in shape: some Shape = .rect
    ) -> some View {
        switch style {
        case .container:
            self.background(shape.fill(.ultraThinMaterial))
        case .regular:
            self.background(
                ZStack {
                    shape.fill(.regularMaterial)
                    shape.stroke(Color.primary.opacity(0.08), lineWidth: 1)
                }
            )
        case .prominent:
            self.background(
                ZStack {
                    shape.fill(.thickMaterial)
                    shape.stroke(Color.primary.opacity(0.12), lineWidth: 1)
                }
            )
        case .input:
            self.background(
                ZStack {
                    shape.fill(.thinMaterial)
                    shape.fill(Color.primary.opacity(0.05))
                    shape.stroke(Color.primary.opacity(0.10), lineWidth: 1)
                }
            )
        }
    }
}

struct OpenPortEntry: Identifiable, Hashable {
    let pid: Int
    let port: Int
    let command: String
    let endpoint: String

    var id: String { "\(pid)-\(port)-\(endpoint)" }

    var isLikelyDev: Bool {
        if OpenPortEntry.devPorts.contains(port) { return true }
        let normalized = command.lowercased()
        return OpenPortEntry.devProcessHints.contains { normalized.contains($0) }
    }

    private static let devPorts: Set<Int> = [
        3000, 3001, 4000, 4200, 5000, 5173, 5432, 6379, 8000, 8080, 8081, 9000, 9229
    ]

    private static let devProcessHints: [String] = [
        "node", "bun", "deno", "python", "ruby", "java", "go", "docker", "postgres", "redis", "nginx", "vite", "next"
    ]
}

enum PortProcessService {
    static func fetchListeningPorts() async throws -> [OpenPortEntry] {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let raw = try runCommand("/usr/sbin/lsof", arguments: ["-nP", "-iTCP", "-sTCP:LISTEN", "-Fpcn"])
                    let parsed = parseLsofMachineOutput(raw.output)
                    continuation.resume(returning: parsed.sorted { lhs, rhs in
                        lhs.port == rhs.port ? lhs.pid < rhs.pid : lhs.port < rhs.port
                    })
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    static func terminate(pid: Int) async -> Bool {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                if (try? runCommand("/bin/kill", arguments: ["-TERM", String(pid)]).status) == 0 {
                    continuation.resume(returning: true)
                    return
                }
                if (try? runCommand("/bin/kill", arguments: ["-KILL", String(pid)]).status) == 0 {
                    continuation.resume(returning: true)
                    return
                }
                continuation.resume(returning: false)
            }
        }
    }

    static func parseLsofMachineOutput(_ output: String) -> [OpenPortEntry] {
        var entries: [OpenPortEntry] = []
        var seen = Set<String>()
        var currentPID: Int?
        var currentCommand = "unknown"

        for line in output.split(separator: "\n").map(String.init) {
            guard let field = line.first else { continue }
            let value = String(line.dropFirst())

            switch field {
            case "p":
                currentPID = Int(value)
            case "c":
                currentCommand = value
            case "n":
                guard let pid = currentPID, let port = parsePort(from: value) else { continue }
                let key = "\(pid)-\(port)-\(value)"
                guard seen.insert(key).inserted else { continue }
                entries.append(OpenPortEntry(pid: pid, port: port, command: currentCommand, endpoint: value))
            default:
                continue
            }
        }

        return entries
    }

    static func parsePort(from endpoint: String) -> Int? {
        let normalized = endpoint.replacingOccurrences(of: "->", with: " ")
        guard let first = normalized.split(separator: " ").first,
              let colon = first.lastIndex(of: ":") else { return nil }
        return Int(first[first.index(after: colon)...])
    }

    private static func runCommand(_ executable: String, arguments: [String]) throws -> (output: String, status: Int32) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        let output = String(decoding: stdout.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        let errors = String(decoding: stderr.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        return (output + errors, process.terminationStatus)
    }
}
