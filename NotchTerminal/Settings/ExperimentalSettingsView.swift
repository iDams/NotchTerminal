import SwiftUI

struct ExperimentalSettingsView: View {
    @AppStorage(AppPreferences.Keys.enableCRTFilter) var enableCRTFilter: Bool = AppPreferences.Defaults.enableCRTFilter
    @AppStorage(AppPreferences.Keys.fakeNotchGlowEnabled) var fakeNotchGlowEnabled: Bool = AppPreferences.Defaults.fakeNotchGlowEnabled
    @AppStorage(AppPreferences.Keys.fakeNotchGlowTheme) var fakeNotchGlowTheme: NotchViewModel.GlowTheme = .cyberpunk
    @AppStorage(AppPreferences.Keys.experimentalDragToNotchEnabled) var experimentalDragToNotchEnabled: Bool = AppPreferences.Defaults.experimentalDragToNotchEnabled
    @AppStorage(AppPreferences.Keys.experimentalStartupOrbEnabled) var experimentalStartupOrbEnabled: Bool = AppPreferences.Defaults.experimentalStartupOrbEnabled
    @AppStorage(AppPreferences.Keys.hitTestDebugOverlayEnabled) var hitTestDebugOverlayEnabled: Bool = AppPreferences.Defaults.hitTestDebugOverlayEnabled
    @AppStorage(AppPreferences.Keys.notchDockingSensitivity) var notchDockingSensitivity: Double = AppPreferences.Defaults.notchDockingSensitivity
    @AppStorage(AppPreferences.Keys.notchWidthOffset) var notchWidthOffset: Double = AppPreferences.Defaults.notchWidthOffset
    @AppStorage(AppPreferences.Keys.notchHeightOffset) var notchHeightOffset: Double = AppPreferences.Defaults.notchHeightOffset

    private var hasAnyNoNotch: Bool {
        NSScreen.screens.contains { screen in
            if #available(macOS 12.0, *) {
                let left = screen.auxiliaryTopLeftArea ?? .zero
                let right = screen.auxiliaryTopRightArea ?? .zero
                let blockedWidth = screen.frame.width - left.width - right.width
                return !(blockedWidth > 20 && min(left.height, right.height) > 0)
            }
            return true
        }
    }

    private var hasAnyPhysicalNotch: Bool {
        NSScreen.screens.contains { screen in
            if #available(macOS 12.0, *) {
                let left = screen.auxiliaryTopLeftArea ?? .zero
                let right = screen.auxiliaryTopRightArea ?? .zero
                let blockedWidth = screen.frame.width - left.width - right.width
                return blockedWidth > 20 && min(left.height, right.height) > 0
            }
            return false
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                geometrySection
                dockingSection
                debugSection
                ZenithSettingsSection(contentSpacing: 12) {
                    ZenithSectionHeading(
                        title: "settings.experimental.effects".localized,
                        subtitle: "settings.experimental.effects.subtitle".localized,
                        icon: "sparkles"
                    )

                    Text("settings.experimental.warning".localized)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    if hasAnyNoNotch {
                        ZenithPreferenceToggleRow(
                            title: "settings.experimental.startupOrb".localized,
                            subtitle: "settings.experimental.startupOrb.subtitle".localized,
                            icon: "circle.grid.2x1.right.filled",
                            binding: $experimentalStartupOrbEnabled
                        )

                        ZenithPreferenceToggleRow(
                            title: "settings.fakeNotchGlow".localized,
                            subtitle: "settings.fakeNotchGlow.subtitle".localized,
                            icon: "sun.max.trianglebadge.exclamationmark",
                            binding: $fakeNotchGlowEnabled
                        )

                        if fakeNotchGlowEnabled {
                            Picker("settings.fakeNotchGlowTheme".localized, selection: $fakeNotchGlowTheme) {
                                ForEach(NotchViewModel.GlowTheme.allCases) { theme in
                                    Text(theme.localizedName).tag(theme)
                                }
                            }
                            .pickerStyle(.menu)
                            .padding(.leading, 32)
                        }
                    }

                    ZenithPreferenceToggleRow(
                        title: "settings.crtFilter".localized,
                        subtitle: "settings.crtFilter.subtitle".localized,
                        icon: "tv",
                        binding: $enableCRTFilter
                    )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }

    private var dockingSection: some View {
        ZenithSettingsSection(contentSpacing: 12) {
            ZenithSectionHeading(
                title: "settings.appearance.docking".localized,
                subtitle: "settings.appearance.docking.subtitle".localized,
                icon: "magnet"
            )

            ZenithPreferenceToggleRow(
                title: "settings.experimental.dragToNotch".localized,
                subtitle: "settings.experimental.dragToNotch.subtitle".localized,
                icon: "arrow.down.to.line.compact",
                binding: $experimentalDragToNotchEnabled
            )

            if experimentalDragToNotchEnabled {
                ZenithSliderPreferenceRow(
                    title: "settings.notchDockingSensitivity".localized,
                    subtitle: "settings.notchDockingSensitivity.subtitle".localized,
                    icon: "record.circle",
                    value: $notchDockingSensitivity,
                    range: 0 ... 100,
                    step: 2,
                    valueFormatter: { "\(Int($0)) pt" }
                )
            }
        }
    }

    private var debugSection: some View {
        ZenithSettingsSection(contentSpacing: 12) {
            ZenithSectionHeading(
                title: "settings.experimental.debug".localized,
                subtitle: "settings.experimental.debug.subtitle".localized,
                icon: "ladybug"
            )

            ZenithPreferenceToggleRow(
                title: "settings.experimental.hitTestDebugOverlay".localized,
                subtitle: "settings.experimental.hitTestDebugOverlay.subtitle".localized,
                icon: "viewfinder.circle",
                binding: $hitTestDebugOverlayEnabled
            )
        }
    }

    private var geometrySection: some View {
        Group {
            if hasAnyPhysicalNotch {
                ZenithSettingsSection(contentSpacing: 12) {
                    ZenithSectionHeading(
                        title: "settings.appearance.geometry".localized,
                        subtitle: "settings.appearance.geometry.subtitle".localized,
                        icon: "aspectratio"
                    )

                    Text("settings.experimental.notchOffsets.note".localized)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    ZenithSliderPreferenceRow(
                        title: "settings.notchWidthOffset".localized,
                        subtitle: "settings.notchWidthOffset.subtitle".localized,
                        icon: "arrow.left.and.right",
                        value: $notchWidthOffset,
                        range: -80 ... 80,
                        step: 1,
                        valueFormatter: { "\(Int($0))" }
                    )

                    ZenithSliderPreferenceRow(
                        title: "settings.notchHeightOffset".localized,
                        subtitle: "settings.notchHeightOffset.subtitle".localized,
                        icon: "arrow.up.and.down",
                        value: $notchHeightOffset,
                        range: -48 ... 48,
                        step: 1,
                        valueFormatter: { "\(Int($0))" }
                    )
                }
            }
        }
    }
}

#Preview("Settings - Experimental") {
    ExperimentalSettingsView()
        .frame(width: 620, height: 420)
}
