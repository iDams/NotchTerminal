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

    private enum ThemeMode: CaseIterable, Identifiable {
        case system
        case dark
        case light
        var id: Self { self }
        var localizedTitle: String {
            switch self {
            case .system: return "openPorts.theme.system".localized
            case .dark: return "openPorts.theme.dark".localized
            case .light: return "openPorts.theme.light".localized
            }
        }
    }

    let ports: [OpenPortEntry]
    let isLoading: Bool
    let message: String?
    let onRefresh: () -> Void
    let onKill: (OpenPortEntry) -> Void
    @Environment(\.colorScheme) private var systemColorScheme
    @State private var scope: PortScope = .dev
    @State private var themeMode: ThemeMode = .dark
    @State private var searchText = ""

    private var overrideColorScheme: ColorScheme? {
        switch themeMode {
        case .system: nil
        case .dark: .dark
        case .light: .light
        }
    }

    private var resolvedColorScheme: ColorScheme {
        overrideColorScheme ?? systemColorScheme
    }

    private var isDarkMode: Bool { resolvedColorScheme == .dark }
    private var primaryText: SwiftUI.Color { isDarkMode ? .white : .black }
    private var secondaryText: SwiftUI.Color { isDarkMode ? .white.opacity(0.65) : .black.opacity(0.62) }
    private var subtleText: SwiftUI.Color { isDarkMode ? .white.opacity(0.55) : .black.opacity(0.50) }
    private var cardStroke: SwiftUI.Color { isDarkMode ? .white.opacity(0.14) : .black.opacity(0.10) }
    private var glassTint: SwiftUI.Color { isDarkMode ? .black.opacity(0.36) : .white.opacity(0.42) }

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
        Group {
            popoverBody
        }
        .ifLet(overrideColorScheme) { view, scheme in
            view.environment(\.colorScheme, scheme)
        }
    }

    private var popoverBody: some View {
        ZStack {
            popoverBackground

            VStack(alignment: .leading, spacing: 12) {
                headerRow
                scopeRow
                searchRow
                contentStateView
            }
            .padding(12)
        }
        .frame(width: 420, height: 320)
    }

    private var popoverBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(glassTint)
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(cardStroke, lineWidth: 1)
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [primaryText.opacity(0.22), .clear, primaryText.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
    }

    private var headerRow: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "network")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(primaryText.opacity(0.9))
                .frame(width: 24, height: 24)
                .background(primaryText.opacity(0.1), in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text("openPorts.title".localized)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(primaryText)
                Text("openPorts.subtitle".localized)
                    .font(.caption)
                    .foregroundStyle(subtleText)
            }
            Spacer()
            Menu {
                Picker("openPorts.theme".localized, selection: $themeMode) {
                    ForEach(ThemeMode.allCases) { mode in
                        Text(mode.localizedTitle).tag(mode)
                    }
                }
            } label: {
                Image(systemName: "circle.lefthalf.filled")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(primaryText.opacity(0.9))
                    .frame(width: 24, height: 24)
                    .background(primaryText.opacity(0.12), in: Circle())
            }
            .menuStyle(.borderlessButton)
            .buttonStyle(.plain)

            Text("\(visiblePorts.count)")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(secondaryText)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(primaryText.opacity(0.1), in: Capsule())
            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(primaryText.opacity(0.9))
                    .frame(width: 24, height: 24)
                    .background(primaryText.opacity(0.12), in: Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private var scopeRow: some View {
        HStack(spacing: 8) {
            scopeButton(.dev)
            scopeButton(.all)
            Spacer()
            metricPill(label: "openPorts.scope.dev".localized, value: devPorts.count)
            metricPill(label: "openPorts.scope.other".localized, value: otherPorts.count)
        }
    }

    private var searchRow: some View {
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
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(cardStroke, lineWidth: 1)
        )
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
                    if !devPorts.isEmpty {
                        sectionLabel("openPorts.scope.dev".localized)
                        ForEach(devPorts) { port in
                            portRow(port)
                        }
                    }

                    if scope == .all, !otherPorts.isEmpty {
                        sectionLabel("openPorts.scope.other".localized)
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
        }
    }

    @ViewBuilder
    private func scopeButton(_ value: PortScope) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.18)) {
                scope = value
            }
        } label: {
            Text(value.localizedTitle)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(scope == value ? (isDarkMode ? .black : .white) : primaryText.opacity(0.8))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Group {
                        if scope == value {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(.regularMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(primaryText.opacity(isDarkMode ? 0.22 : 0.32))
                                )
                        } else {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(cardStroke, lineWidth: 1)
                                )
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func metricPill(label: String, value: Int) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(subtleText)
            Text("\(value)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(primaryText.opacity(0.85))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .stroke(cardStroke, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 2)
    }

    @ViewBuilder
    private func portRow(_ port: OpenPortEntry) -> some View {
        HStack(spacing: 10) {
            Text(":\(String(port.port))")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(primaryText.opacity(0.95))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background((port.isLikelyDev ? Color.blue.opacity(0.22) : Color.gray.opacity(0.22)), in: Capsule())

            VStack(alignment: .leading, spacing: 1) {
                Text(port.command)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(primaryText)
                Text(String(format: "openPorts.row.pidAndEndpoint".localized, String(port.pid), port.endpoint))
                    .font(.system(size: 11))
                    .foregroundStyle(secondaryText)
            }
            Spacer()
            Button {
                onKill(port)
            } label: {
                Label("openPorts.kill".localized, systemImage: "xmark")
                    .labelStyle(.iconOnly)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(Color.red.opacity(0.88), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(cardStroke, lineWidth: 1)
        )
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
