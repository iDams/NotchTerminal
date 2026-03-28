import Combine
import Foundation
import ServiceManagement

@MainActor
protocol LaunchAtLoginControlling: AnyObject {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
}

@MainActor
final class LaunchAtLoginManager: ObservableObject {
    static let shared = LaunchAtLoginManager()

    @Published private(set) var isEnabled = false
    @Published private(set) var requiresApproval = false
    @Published private(set) var errorMessage: String?

    private let controller: any LaunchAtLoginControlling

    init() {
        self.controller = SMMainAppLaunchAtLoginController()
        refreshStatus()
    }

    init(controller: any LaunchAtLoginControlling) {
        self.controller = controller
        refreshStatus()
    }

    func refreshStatus() {
        let status = controller.status
        switch status {
        case .enabled:
            isEnabled = true
            requiresApproval = false
        case .requiresApproval:
            isEnabled = true
            requiresApproval = true
        case .notRegistered, .notFound:
            isEnabled = false
            requiresApproval = false
        @unknown default:
            isEnabled = false
            requiresApproval = false
        }
    }

    func setEnabled(_ enabled: Bool) {
        errorMessage = nil

        do {
            if enabled {
                try controller.register()
            } else {
                try controller.unregister()
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        refreshStatus()
    }

    func openSystemSettingsLoginItems() {
        SMAppService.openSystemSettingsLoginItems()
    }
}

private final class SMMainAppLaunchAtLoginController: LaunchAtLoginControlling {
    private let service = SMAppService.mainApp

    var status: SMAppService.Status {
        service.status
    }

    func register() throws {
        try service.register()
    }

    func unregister() throws {
        try service.unregister()
    }
}
