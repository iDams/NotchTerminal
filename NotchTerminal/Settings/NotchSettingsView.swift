import SwiftUI
import AppKit

struct NotchSettingsView: View {
    @State private var screens: [NSScreen] = NSScreen.screens

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ZenithSettingsSection(contentSpacing: 12) {
                    ZenithSectionHeading(
                        title: "settings.notch.displays".localized,
                        subtitle: "settings.notch.displays.subtitle".localized,
                        icon: "capsule.portrait"
                    )

                    if screens.isEmpty {
                        Text("settings.notch.empty".localized)
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                    } else {
                        ForEach(screenItems) { item in
                            ZenithPreferenceToggleRow(
                                title: item.title,
                                subtitle: item.subtitle,
                                icon: item.icon,
                                binding: Binding(
                                    get: {
                                        AppPreferences.isNotchEnabled(for: item.displayID)
                                    },
                                    set: { isEnabled in
                                        AppPreferences.setNotchEnabled(isEnabled, for: item.displayID)
                                    }
                                )
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .onAppear {
            refreshScreens()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            refreshScreens()
        }
    }

    private var screenItems: [NotchDisplayItem] {
        screens.compactMap { screen in
            guard let displayID = displayID(for: screen) else { return nil }
            let notchKindKey = hasPhysicalNotch(on: screen)
                ? "settings.notch.display.physical"
                : "settings.notch.display.pill"
            let mainSuffix = (screen == NSScreen.main)
                ? " • \("settings.notch.display.main".localized)"
                : ""
            return NotchDisplayItem(
                displayID: displayID,
                title: screen.localizedName,
                subtitle: "\(notchKindKey.localized)\(mainSuffix)",
                icon: hasPhysicalNotch(on: screen) ? "macbook" : "rectangle.tophalf.inset.filled"
            )
        }
    }

    private func refreshScreens() {
        screens = NSScreen.screens
    }

    private func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }
        return CGDirectDisplayID(number.uint32Value)
    }

    private func hasPhysicalNotch(on screen: NSScreen) -> Bool {
        guard #available(macOS 12.0, *) else { return false }
        let left = screen.auxiliaryTopLeftArea ?? .zero
        let right = screen.auxiliaryTopRightArea ?? .zero
        let blockedWidth = screen.frame.width - left.width - right.width
        return blockedWidth > 20 && min(left.height, right.height) > 0
    }
}

private struct NotchDisplayItem: Identifiable {
    let displayID: CGDirectDisplayID
    let title: String
    let subtitle: String
    let icon: String

    var id: CGDirectDisplayID { displayID }
}

#Preview("Settings - Notch") {
    NotchSettingsView()
}
