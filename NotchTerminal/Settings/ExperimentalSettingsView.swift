import SwiftUI

struct ExperimentalSettingsView: View {
    @AppStorage(AppPreferences.Keys.enableCRTFilter) var enableCRTFilter: Bool = AppPreferences.Defaults.enableCRTFilter
    @AppStorage(AppPreferences.Keys.fakeNotchGlowEnabled) var fakeNotchGlowEnabled: Bool = AppPreferences.Defaults.fakeNotchGlowEnabled
    @AppStorage(AppPreferences.Keys.fakeNotchGlowTheme) var fakeNotchGlowTheme: NotchViewModel.GlowTheme = .cyberpunk
    @AppStorage(AppPreferences.Keys.experimentalDragToNotchEnabled) var experimentalDragToNotchEnabled: Bool = AppPreferences.Defaults.experimentalDragToNotchEnabled
    @AppStorage(AppPreferences.Keys.experimentalStartupOrbEnabled) var experimentalStartupOrbEnabled: Bool = AppPreferences.Defaults.experimentalStartupOrbEnabled
    @AppStorage(AppPreferences.Keys.startupOrbPillOffsetX) var startupOrbPillOffsetX: Double = AppPreferences.Defaults.startupOrbPillOffsetX
    @AppStorage(AppPreferences.Keys.startupOrbPillOffsetY) var startupOrbPillOffsetY: Double = AppPreferences.Defaults.startupOrbPillOffsetY
    @AppStorage(AppPreferences.Keys.startupOrbNotchOffsetX) var startupOrbNotchOffsetX: Double = AppPreferences.Defaults.startupOrbNotchOffsetX
    @AppStorage(AppPreferences.Keys.startupOrbNotchOffsetY) var startupOrbNotchOffsetY: Double = AppPreferences.Defaults.startupOrbNotchOffsetY
    @AppStorage(AppPreferences.Keys.hitTestDebugOverlayEnabled) var hitTestDebugOverlayEnabled: Bool = AppPreferences.Defaults.hitTestDebugOverlayEnabled
    @AppStorage(AppPreferences.Keys.notchDockingSensitivity) var notchDockingSensitivity: Double = AppPreferences.Defaults.notchDockingSensitivity
    @AppStorage(AppPreferences.Keys.notchWidthOffset) var notchWidthOffset: Double = AppPreferences.Defaults.notchWidthOffset
    @AppStorage(AppPreferences.Keys.notchHeightOffset) var notchHeightOffset: Double = AppPreferences.Defaults.notchHeightOffset

    private var startupOrbPillOffsetXBinding: Binding<Double> {
        Binding(
            get: { startupOrbPillOffsetX - AppPreferences.Defaults.startupOrbPillOffsetX },
            set: { startupOrbPillOffsetX = $0 + AppPreferences.Defaults.startupOrbPillOffsetX }
        )
    }

    private var startupOrbPillOffsetYBinding: Binding<Double> {
        Binding(
            get: { startupOrbPillOffsetY - AppPreferences.Defaults.startupOrbPillOffsetY },
            set: { startupOrbPillOffsetY = $0 + AppPreferences.Defaults.startupOrbPillOffsetY }
        )
    }

    private var startupOrbNotchOffsetXBinding: Binding<Double> {
        Binding(
            get: { startupOrbNotchOffsetX - AppPreferences.Defaults.startupOrbNotchOffsetX },
            set: { startupOrbNotchOffsetX = $0 + AppPreferences.Defaults.startupOrbNotchOffsetX }
        )
    }

    private var startupOrbNotchOffsetYBinding: Binding<Double> {
        Binding(
            get: { startupOrbNotchOffsetY - AppPreferences.Defaults.startupOrbNotchOffsetY },
            set: { startupOrbNotchOffsetY = $0 + AppPreferences.Defaults.startupOrbNotchOffsetY }
        )
    }

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
                startupOrbSection
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

    private var startupOrbPillSection: some View {
        VStack(spacing: 12) {
            ZenithSliderPreferenceRow(
                title: "settings.experimental.startupOrb.pillOffsetX".localized,
                subtitle: "settings.experimental.startupOrb.pillOffsetX.subtitle".localized,
                icon: "arrow.left.and.right.circle",
                value: startupOrbPillOffsetXBinding,
                range: -80 ... 80,
                step: 1,
                valueFormatter: { "\(Int($0)) pt" }
            )

            ZenithSliderPreferenceRow(
                title: "settings.experimental.startupOrb.pillOffsetY".localized,
                subtitle: "settings.experimental.startupOrb.pillOffsetY.subtitle".localized,
                icon: "arrow.up.and.down.circle",
                value: startupOrbPillOffsetYBinding,
                range: -60 ... 60,
                step: 1,
                valueFormatter: { "\(Int($0)) pt" }
            )
        }
    }

    private var startupOrbNotchSection: some View {
        VStack(spacing: 12) {
            ZenithSliderPreferenceRow(
                title: "settings.experimental.startupOrb.notchOffsetX".localized,
                subtitle: "settings.experimental.startupOrb.notchOffsetX.subtitle".localized,
                icon: "arrow.left.and.right.circle",
                value: startupOrbNotchOffsetXBinding,
                range: -80 ... 120,
                step: 1,
                valueFormatter: { "\(Int($0)) pt" }
            )

            ZenithSliderPreferenceRow(
                title: "settings.experimental.startupOrb.notchOffsetY".localized,
                subtitle: "settings.experimental.startupOrb.notchOffsetY.subtitle".localized,
                icon: "arrow.up.and.down.circle",
                value: startupOrbNotchOffsetYBinding,
                range: -60 ... 60,
                step: 1,
                valueFormatter: { "\(Int($0)) pt" }
            )
        }
    }

    private var startupOrbSection: some View {
        ZenithSettingsSection(contentSpacing: 12) {
            ZenithSectionHeading(
                title: "settings.experimental.startupOrb.section".localized,
                subtitle: "settings.experimental.startupOrb.section.subtitle".localized,
                icon: "circle.grid.2x1.right.filled"
            )

            ZenithPreferenceToggleRow(
                title: "settings.experimental.startupOrb".localized,
                subtitle: "settings.experimental.startupOrb.subtitle".localized,
                icon: "circle.grid.2x1.right.filled",
                binding: $experimentalStartupOrbEnabled
            )

            if experimentalStartupOrbEnabled && hasAnyNoNotch {
                startupOrbPillSection
            }

            if experimentalStartupOrbEnabled && hasAnyPhysicalNotch {
                startupOrbNotchSection
            }
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
