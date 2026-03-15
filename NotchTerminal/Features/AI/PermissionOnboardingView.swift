import SwiftUI

struct PermissionOnboardingView: View {
    @State private var coordinator = AppPermissionCoordinator.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Allow Key Permissions")
                .font(.title2.weight(.semibold))

            Text("NotchTerminal works best when notifications and automation permissions are ready before you start using AI jobs.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                ForEach(AppPermissionCoordinator.PermissionKind.allCases) { permission in
                    permissionRow(permission)
                }
            }

            HStack {
                Button("Not now") {
                    coordinator.completeInitialFlow()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Continue") {
                    coordinator.completeInitialFlow()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(minWidth: 520)
        .task {
            await coordinator.refreshStatuses()
        }
    }

    private func permissionRow(_ permission: AppPermissionCoordinator.PermissionKind) -> some View {
        let status = coordinator.statuses[permission] ?? .init(isGranted: false, detail: "Checking...")

        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: permission.systemImage)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 24, height: 24)
                .foregroundStyle(status.isGranted ? .green : .secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(permission.title)
                    .font(.body.weight(.semibold))

                Text(permission.subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text(status.detail)
                    .font(.caption)
                    .foregroundStyle(status.isGranted ? .green : .orange)
            }

            Spacer(minLength: 8)

            if status.isGranted {
                Label("Ready", systemImage: "checkmark.circle.fill")
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(.green)
                    .font(.caption.weight(.semibold))
            } else {
                HStack(spacing: 8) {
                    Button("Request") {
                        Task {
                            await coordinator.request(permission)
                        }
                    }
                    .buttonStyle(.bordered)

                    Button("Open Settings") {
                        openSettings(for: permission)
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private func openSettings(for permission: AppPermissionCoordinator.PermissionKind) {
        switch permission {
        case .notifications:
            coordinator.openNotificationsSettings()
        case .accessibility:
            coordinator.openAccessibilitySettings()
        case .screenRecording:
            coordinator.openScreenRecordingSettings()
        }
    }
}
