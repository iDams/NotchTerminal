import AppKit
import ApplicationServices
import Foundation
import Observation
import UserNotifications

@MainActor
@Observable
final class AppPermissionCoordinator {
    static let shared = AppPermissionCoordinator()

    enum PermissionKind: String, CaseIterable, Identifiable {
        case notifications
        case accessibility
        case screenRecording

        var id: String { rawValue }

        var title: String {
            switch self {
            case .notifications:
                return "Notifications"
            case .accessibility:
                return "Accessibility"
            case .screenRecording:
                return "Screen Recording"
            }
        }

        var subtitle: String {
            switch self {
            case .notifications:
                return "Allow NotchTerminal to deliver AI job results and alerts."
            case .accessibility:
                return "Allow NotchTerminal to automate and type into macOS apps for AI jobs."
            case .screenRecording:
                return "Allow NotchTerminal to capture app windows so AI jobs can inspect the current UI."
            }
        }

        var systemImage: String {
            switch self {
            case .notifications:
                return "bell.badge"
            case .accessibility:
                return "figure.wave"
            case .screenRecording:
                return "rectangle.on.rectangle"
            }
        }
    }

    struct PermissionStatus: Equatable {
        var isGranted: Bool
        var detail: String
    }

    var statuses: [PermissionKind: PermissionStatus] = [:]
    var shouldPresentOnboarding = false

    private init() {}

    func refreshStatuses() async {
        let notificationSettings = await UNUserNotificationCenter.current().notificationSettings()
        statuses[.notifications] = notificationStatus(from: notificationSettings)
        statuses[.accessibility] = accessibilityStatus()
        statuses[.screenRecording] = screenRecordingStatus()
        shouldPresentOnboarding = shouldShowInitialPermissionFlow && statuses.values.contains(where: { !$0.isGranted })
    }

    func request(_ permission: PermissionKind) async {
        switch permission {
        case .notifications:
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        case .accessibility:
            _ = MacAppAutomationService.requestAccessibilityPermissionIfNeeded()
        case .screenRecording:
            _ = ScreenCaptureService.requestScreenRecordingPermission()
        }
        await refreshStatuses()
    }

    func completeInitialFlow() {
        UserDefaults.standard.set(true, forKey: AppPreferences.Keys.initialPermissionFlowCompleted)
        shouldPresentOnboarding = false
    }

    func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    func openNotificationsSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") else { return }
        NSWorkspace.shared.open(url)
    }

    func openScreenRecordingSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else { return }
        NSWorkspace.shared.open(url)
    }

    private var shouldShowInitialPermissionFlow: Bool {
        !UserDefaults.standard.bool(forKey: AppPreferences.Keys.initialPermissionFlowCompleted)
    }

    private func notificationStatus(from settings: UNNotificationSettings) -> PermissionStatus {
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return PermissionStatus(isGranted: true, detail: "Granted")
        case .denied:
            return PermissionStatus(isGranted: false, detail: "Denied in System Settings")
        case .notDetermined:
            return PermissionStatus(isGranted: false, detail: "Not requested yet")
        @unknown default:
            return PermissionStatus(isGranted: false, detail: "Unknown state")
        }
    }

    private func accessibilityStatus() -> PermissionStatus {
        let granted = AXIsProcessTrusted()
        return PermissionStatus(
            isGranted: granted,
            detail: granted ? "Granted" : "Needs manual approval in System Settings"
        )
    }

    private func screenRecordingStatus() -> PermissionStatus {
        let granted = ScreenCaptureService.hasScreenRecordingPermission()
        return PermissionStatus(
            isGranted: granted,
            detail: granted ? "Granted" : "Needed before AI can inspect app windows"
        )
    }
}
