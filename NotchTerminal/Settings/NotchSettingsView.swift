import SwiftUI
import AppKit

struct NotchSettingsView: View {
    @State private var screens: [NSScreen] = NSScreen.screens
    @State private var notchOffsetXValues: [CGDirectDisplayID: Double] = [:]
    @State private var notchOffsetYValues: [CGDirectDisplayID: Double] = [:]
    @State private var notchWidthValues: [CGDirectDisplayID: Double] = [:]
    @AppStorage(AppPreferences.Keys.auroraBackgroundEnabled) private var globalAuroraBackgroundEnabled = AppPreferences.Defaults.auroraBackgroundEnabled
    @AppStorage(AppPreferences.Keys.auroraTheme) private var globalAuroraTheme: NotchViewModel.AuroraTheme = .classic

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                NotchTerminalSettingsSection(contentSpacing: 12) {
                    NotchTerminalSectionHeading(
                        title: "settings.notch.displays".localized,
                        subtitle: "settings.notch.displays.subtitle".localized,
                        icon: "capsule.portrait"
                    )
                }

                if screens.isEmpty {
                    NotchTerminalSettingsSection(contentSpacing: 12) {
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
            .reportSettingsContentHeight(for: .notch)
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
        NotchTerminalSettingsSection(contentSpacing: 12) {
            NotchTerminalSectionHeading(
                title: item.title,
                subtitle: item.subtitle,
                icon: item.icon
            )

            NotchTerminalPreferenceToggleRow(
                title: "settings.notch.enabled".localized,
                subtitle: "settings.notch.enabled.subtitle".localized,
                icon: "power",
                binding: Binding(
                    get: { AppPreferences.notchConfiguration(for: item.displayID).isEnabled },
                    set: { AppPreferences.setNotchEnabled($0, for: item.displayID) }
                )
            )

            if AppPreferences.notchConfiguration(for: item.displayID).isEnabled {
                NotchTerminalSliderPreferenceRow(
                    title: "settings.notch.offsetX".localized,
                    subtitle: "settings.notch.offsetX.subtitle".localized,
                    icon: "arrow.left.and.right",
                    value: Binding(
                        get: { notchOffsetXValues[item.displayID] ?? AppPreferences.notchConfiguration(for: item.displayID).offsetX },
                        set: {
                            notchOffsetXValues[item.displayID] = $0
                            AppPreferences.setNotchOffsetX($0, for: item.displayID)
                        }
                    ),
                    range: -160 ... 160,
                    step: 1,
                    valueFormatter: { "\($0.formatted(.number.precision(.fractionLength(0)))) pt" }
                )

                NotchTerminalSliderPreferenceRow(
                    title: "settings.notch.offsetY".localized,
                    subtitle: "settings.notch.offsetY.subtitle".localized,
                    icon: "arrow.up.and.down",
                    value: Binding(
                        get: { notchOffsetYValues[item.displayID] ?? AppPreferences.notchConfiguration(for: item.displayID).offsetY },
                        set: {
                            notchOffsetYValues[item.displayID] = $0
                            AppPreferences.setNotchOffsetY($0, for: item.displayID)
                        }
                    ),
                    range: -80 ... 80,
                    step: 1,
                    valueFormatter: { "\($0.formatted(.number.precision(.fractionLength(0)))) pt" }
                )

                NotchTerminalSliderPreferenceRow(
                    title: "settings.notch.width".localized,
                    subtitle: "settings.notch.width.subtitle".localized,
                    icon: "arrow.left.and.right.righttriangle.left.righttriangle.right",
                    value: Binding(
                        get: { notchWidthValues[item.displayID] ?? AppPreferences.notchConfiguration(for: item.displayID).widthAdjustment },
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

                NotchTerminalPreferenceToggleRow(
                    title: "settings.notch.customBackground".localized,
                    subtitle: "settings.notch.customBackground.subtitle".localized,
                    icon: "paintpalette",
                    binding: Binding(
                        get: { auroraConfiguration(for: item.displayID).usesCustomOverride },
                        set: {
                            AppPreferences.setCustomAuroraOverrideEnabled($0, for: item.displayID)
                        }
                    )
                )

                if auroraConfiguration(for: item.displayID).usesCustomOverride {
                    NotchTerminalPreferenceToggleRow(
                        title: "settings.notch.customBackground.enabled".localized,
                        subtitle: "settings.notch.customBackground.enabled.subtitle".localized,
                        icon: "waveform.circle",
                        binding: Binding(
                            get: { auroraConfiguration(for: item.displayID).backgroundEnabled },
                            set: {
                                AppPreferences.setAuroraBackgroundEnabled($0, for: item.displayID)
                            }
                        )
                    )

                    if auroraConfiguration(for: item.displayID).backgroundEnabled {
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
                                    get: { auroraThemeSelection(for: item.displayID) },
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
            let configuration = AppPreferences.notchConfiguration(for: displayID)
            nextX[displayID] = configuration.offsetX
            nextY[displayID] = configuration.offsetY
            nextWidth[displayID] = configuration.widthAdjustment
        }

        notchOffsetXValues = nextX
        notchOffsetYValues = nextY
        notchWidthValues = nextWidth
    }

    private func auroraConfiguration(for displayID: CGDirectDisplayID) -> AppPreferences.AuroraDisplayConfiguration {
        AppPreferences.auroraConfiguration(
            for: displayID,
            fallbackEnabled: globalAuroraBackgroundEnabled,
            fallbackTheme: globalAuroraTheme.rawValue
        )
    }

    private func auroraThemeSelection(for displayID: CGDirectDisplayID) -> NotchViewModel.AuroraTheme {
        let configuration = auroraConfiguration(for: displayID)
        return NotchViewModel.AuroraTheme(rawValue: configuration.theme) ?? globalAuroraTheme
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
