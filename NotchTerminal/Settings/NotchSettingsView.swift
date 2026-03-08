import SwiftUI
import AppKit

struct NotchSettingsView: View {
    @State private var screens: [NSScreen] = NSScreen.screens
    @State private var notchOffsetXValues: [CGDirectDisplayID: Double] = [:]
    @State private var notchOffsetYValues: [CGDirectDisplayID: Double] = [:]
    @State private var notchWidthValues: [CGDirectDisplayID: Double] = [:]
    @AppStorage(AppPreferences.Keys.auroraDisplayOverrideIDs) private var auroraDisplayOverrideIDsRaw = ""
    @AppStorage(AppPreferences.Keys.auroraDisplayEnabledMap) private var auroraDisplayEnabledMapRaw = ""
    @AppStorage(AppPreferences.Keys.auroraDisplayThemeMap) private var auroraDisplayThemeMapRaw = ""
    @AppStorage(AppPreferences.Keys.auroraBackgroundEnabled) private var globalAuroraBackgroundEnabled = AppPreferences.Defaults.auroraBackgroundEnabled
    @AppStorage(AppPreferences.Keys.auroraTheme) private var globalAuroraTheme: NotchViewModel.AuroraTheme = .classic

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ZenithSettingsSection(contentSpacing: 12) {
                    ZenithSectionHeading(
                        title: "settings.notch.displays".localized,
                        subtitle: "settings.notch.displays.subtitle".localized,
                        icon: "capsule.portrait"
                    )
                }

                if screens.isEmpty {
                    ZenithSettingsSection(contentSpacing: 12) {
                        Text("settings.notch.empty".localized)
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                    }
                } else {
                    ForEach(screenItems) { item in
                        notchDisplaySection(for: item)
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

    @ViewBuilder
    private func notchDisplaySection(for item: NotchDisplayItem) -> some View {
        ZenithSettingsSection(contentSpacing: 12) {
            ZenithSectionHeading(
                title: item.title,
                subtitle: item.subtitle,
                icon: item.icon
            )

            ZenithPreferenceToggleRow(
                title: "settings.notch.enabled".localized,
                subtitle: "settings.notch.enabled.subtitle".localized,
                icon: "power",
                binding: Binding(
                    get: { AppPreferences.isNotchEnabled(for: item.displayID) },
                    set: { AppPreferences.setNotchEnabled($0, for: item.displayID) }
                )
            )

            if AppPreferences.isNotchEnabled(for: item.displayID) {
                ZenithSliderPreferenceRow(
                    title: "settings.notch.offsetX".localized,
                    subtitle: "settings.notch.offsetX.subtitle".localized,
                    icon: "arrow.left.and.right",
                    value: Binding(
                        get: { notchOffsetXValues[item.displayID] ?? AppPreferences.notchOffsetX(for: item.displayID) },
                        set: {
                            notchOffsetXValues[item.displayID] = $0
                            AppPreferences.setNotchOffsetX($0, for: item.displayID)
                        }
                    ),
                    range: -160 ... 160,
                    step: 1,
                    valueFormatter: { "\($0.formatted(.number.precision(.fractionLength(0)))) pt" }
                )

                ZenithSliderPreferenceRow(
                    title: "settings.notch.offsetY".localized,
                    subtitle: "settings.notch.offsetY.subtitle".localized,
                    icon: "arrow.up.and.down",
                    value: Binding(
                        get: { notchOffsetYValues[item.displayID] ?? AppPreferences.notchOffsetY(for: item.displayID) },
                        set: {
                            notchOffsetYValues[item.displayID] = $0
                            AppPreferences.setNotchOffsetY($0, for: item.displayID)
                        }
                    ),
                    range: -80 ... 80,
                    step: 1,
                    valueFormatter: { "\($0.formatted(.number.precision(.fractionLength(0)))) pt" }
                )

                ZenithSliderPreferenceRow(
                    title: "settings.notch.width".localized,
                    subtitle: "settings.notch.width.subtitle".localized,
                    icon: "arrow.left.and.right.righttriangle.left.righttriangle.right",
                    value: Binding(
                        get: { notchWidthValues[item.displayID] ?? AppPreferences.notchWidthAdjustment(for: item.displayID) },
                        set: {
                            notchWidthValues[item.displayID] = $0
                            AppPreferences.setNotchWidthAdjustment($0, for: item.displayID)
                        }
                    ),
                    range: -120 ... 120,
                    step: 1,
                    valueFormatter: { "\($0.formatted(.number.precision(.fractionLength(0)))) pt" }
                )

                Divider()

                ZenithPreferenceToggleRow(
                    title: "settings.notch.customBackground".localized,
                    subtitle: "settings.notch.customBackground.subtitle".localized,
                    icon: "paintpalette",
                    binding: Binding(
                        get: {
                            _ = auroraDisplayOverrideIDsRaw
                            return AppPreferences.hasCustomAuroraOverride(for: item.displayID)
                        },
                        set: {
                            AppPreferences.setCustomAuroraOverrideEnabled($0, for: item.displayID)
                        }
                    )
                )

                if AppPreferences.hasCustomAuroraOverride(for: item.displayID) {
                    ZenithPreferenceToggleRow(
                        title: "settings.notch.customBackground.enabled".localized,
                        subtitle: "settings.notch.customBackground.enabled.subtitle".localized,
                        icon: "waveform.circle",
                        binding: Binding(
                            get: {
                                _ = auroraDisplayEnabledMapRaw
                                return AppPreferences.auroraBackgroundEnabled(
                                    for: item.displayID,
                                    fallback: globalAuroraBackgroundEnabled
                                )
                            },
                            set: {
                                AppPreferences.setAuroraBackgroundEnabled($0, for: item.displayID)
                            }
                        )
                    )

                    if AppPreferences.auroraBackgroundEnabled(
                        for: item.displayID,
                        fallback: globalAuroraBackgroundEnabled
                    ) {
                        HStack(alignment: .center, spacing: 10) {
                            Image(systemName: "swatchpalette")
                                .font(.system(size: 13, weight: .semibold))
                                .frame(width: 20, height: 20)
                                .foregroundStyle(.secondary)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("settings.auroraTheme".localized)
                                    .font(.body.weight(.medium))
                                Text("settings.notch.customBackground.theme.subtitle".localized)
                                    .font(.footnote)
                                    .foregroundStyle(.tertiary)
                            }

                            Spacer(minLength: 8)

                            Picker(
                                "settings.auroraTheme".localized,
                                selection: Binding(
                                    get: {
                                        _ = auroraDisplayThemeMapRaw
                                        let rawValue = AppPreferences.auroraTheme(
                                            for: item.displayID,
                                            fallback: globalAuroraTheme.rawValue
                                        )
                                        return NotchViewModel.AuroraTheme(rawValue: rawValue) ?? globalAuroraTheme
                                    },
                                    set: {
                                        AppPreferences.setAuroraTheme($0.rawValue, for: item.displayID)
                                    }
                                )
                            ) {
                                ForEach(NotchViewModel.AuroraTheme.allCases) { theme in
                                    Text(theme.localizedName).tag(theme)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 220)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
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
                icon: iconName(for: screen)
            )
        }
    }

    private func refreshScreens() {
        screens = NSScreen.screens
        syncSliderState()
    }

    private func syncSliderState() {
        var nextX: [CGDirectDisplayID: Double] = [:]
        var nextY: [CGDirectDisplayID: Double] = [:]
        var nextWidth: [CGDirectDisplayID: Double] = [:]

        for screen in screens {
            guard let displayID = displayID(for: screen) else { continue }
            nextX[displayID] = AppPreferences.notchOffsetX(for: displayID)
            nextY[displayID] = AppPreferences.notchOffsetY(for: displayID)
            nextWidth[displayID] = AppPreferences.notchWidthAdjustment(for: displayID)
        }

        notchOffsetXValues = nextX
        notchOffsetYValues = nextY
        notchWidthValues = nextWidth
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

    private func iconName(for screen: NSScreen) -> String {
        if hasPhysicalNotch(on: screen) {
            return "macbook"
        }

        let name = screen.localizedName.lowercased()
        if name.contains("sidecar") || name.contains("ipad") || name.contains("airplay") {
            return "ipad.landscape"
        }

        return "display"
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
