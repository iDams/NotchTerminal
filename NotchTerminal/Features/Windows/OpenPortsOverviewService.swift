import Foundation
import Observation

@MainActor
@Observable
final class OpenPortsOverviewService {
    static let shared = OpenPortsOverviewService()

    enum Scope: String, CaseIterable, Identifiable {
        case dev
        case all

        var id: Self { self }

        var localizedTitle: String {
            switch self {
            case .dev:
                return "openPorts.scope.dev".localized
            case .all:
                return "openPorts.scope.all".localized
            }
        }
    }

    private let overviewPresenter = OpenPortsOverviewPresenter()
    private var refreshTask: Task<Void, Never>?

    private(set) var ports: [OpenPortEntry] = []
    private(set) var isLoading = false
    private(set) var message: String?
    private(set) var lastScanAt: Date?
    var searchText = ""
    var scope: Scope = .dev

    var devPortCount: Int {
        ports.filter(\.isLikelyDev).count
    }

    var otherPortCount: Int {
        ports.filter { !$0.isLikelyDev }.count
    }

    var visiblePorts: [OpenPortEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let searchedPorts = query.isEmpty ? ports : ports.filter {
            String($0.port).contains(query) ||
            String($0.pid).contains(query) ||
            $0.command.lowercased().contains(query) ||
            $0.endpoint.lowercased().contains(query)
        }

        switch scope {
        case .dev:
            return searchedPorts.filter(\.isLikelyDev)
        case .all:
            return searchedPorts
        }
    }

    func showOverview() {
        overviewPresenter.present(service: self)
    }

    func refreshIfNeeded() {
        if isLoading { return }
        if let lastScanAt, Date().timeIntervalSince(lastScanAt) < 15 { return }
        refresh()
    }

    func refresh() {
        refreshTask?.cancel()
        isLoading = true
        message = nil

        refreshTask = Task { [weak self] in
            guard let self else { return }

            do {
                let ports = try await PortProcessService.fetchListeningPorts()
                guard !Task.isCancelled else { return }
                self.ports = ports
                self.lastScanAt = Date()
                self.isLoading = false
                self.message = ports.isEmpty ? "openPorts.message.noListening".localized : nil
            } catch {
                guard !Task.isCancelled else { return }
                self.isLoading = false
                self.message = "openPorts.message.loadFailed".localized
            }
        }
    }

    func terminate(_ port: OpenPortEntry) {
        Task { [weak self] in
            guard let self else { return }
            let terminated = await PortProcessService.terminate(pid: port.pid)
            guard !Task.isCancelled else { return }

            if terminated {
                self.ports.removeAll { $0.id == port.id }
                self.message = self.ports.isEmpty ? "openPorts.message.noListening".localized : nil
            } else {
                self.message = String(format: "openPorts.message.terminateFailed".localized, String(port.pid))
            }
        }
    }
}
