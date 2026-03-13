import SwiftUI

struct ExperimentalSettingsView: View {
    @AppStorage(AppPreferences.Keys.enableCRTFilter) var enableCRTFilter: Bool = AppPreferences.Defaults.enableCRTFilter
    @AppStorage(AppPreferences.Keys.fakeNotchGlowEnabled) var fakeNotchGlowEnabled: Bool = AppPreferences.Defaults.fakeNotchGlowEnabled
    @AppStorage(AppPreferences.Keys.fakeNotchGlowTheme) var fakeNotchGlowTheme: NotchViewModel.GlowTheme = .cyberpunk
    @AppStorage(AppPreferences.Keys.startupOrbPillOffsetX) var startupOrbPillOffsetX: Double = AppPreferences.Defaults.startupOrbPillOffsetX
    @AppStorage(AppPreferences.Keys.startupOrbPillOffsetY) var startupOrbPillOffsetY: Double = AppPreferences.Defaults.startupOrbPillOffsetY
    @AppStorage(AppPreferences.Keys.startupOrbNotchOffsetX) var startupOrbNotchOffsetX: Double = AppPreferences.Defaults.startupOrbNotchOffsetX
    @AppStorage(AppPreferences.Keys.startupOrbNotchOffsetY) var startupOrbNotchOffsetY: Double = AppPreferences.Defaults.startupOrbNotchOffsetY
    @AppStorage(AppPreferences.Keys.notchWidthOffset) var notchWidthOffset: Double = AppPreferences.Defaults.notchWidthOffset
    @AppStorage(AppPreferences.Keys.notchHeightOffset) var notchHeightOffset: Double = AppPreferences.Defaults.notchHeightOffset

    private var experimentalFeatures: AppPreferences.ExperimentalFeatureConfiguration {
        AppPreferences.experimentalFeatureConfiguration()
    }

    private var dragToNotchBinding: Binding<Bool> {
        Binding(
            get: { experimentalFeatures.dragToNotchEnabled },
            set: { UserDefaults.standard.set($0, forKey: AppPreferences.Keys.experimentalDragToNotchEnabled) }
        )
    }

    private var startupOrbEnabledBinding: Binding<Bool> {
        Binding(
            get: { experimentalFeatures.startupOrbEnabled },
            set: { UserDefaults.standard.set($0, forKey: AppPreferences.Keys.experimentalStartupOrbEnabled) }
        )
    }

    private var hitTestDebugOverlayBinding: Binding<Bool> {
        Binding(
            get: { experimentalFeatures.hitTestDebugOverlayEnabled },
            set: { UserDefaults.standard.set($0, forKey: AppPreferences.Keys.hitTestDebugOverlayEnabled) }
        )
    }

    private var notchDockingSensitivityBinding: Binding<Double> {
        Binding(
            get: { experimentalFeatures.notchDockingSensitivity },
            set: { UserDefaults.standard.set($0, forKey: AppPreferences.Keys.notchDockingSensitivity) }
        )
    }

    private var projectStatusCardEnabledBinding: Binding<Bool> {
        Binding(
            get: { experimentalFeatures.projectStatusCardEnabled },
            set: { UserDefaults.standard.set($0, forKey: AppPreferences.Keys.experimentalProjectStatusCardEnabled) }
        )
    }

    private var projectStatusShowGitBinding: Binding<Bool> {
        Binding(
            get: { experimentalFeatures.projectStatusShowGit },
            set: { UserDefaults.standard.set($0, forKey: AppPreferences.Keys.experimentalProjectStatusShowGit) }
        )
    }

    private var projectStatusShowFolderBinding: Binding<Bool> {
        Binding(
            get: { experimentalFeatures.projectStatusShowFolder },
            set: { UserDefaults.standard.set($0, forKey: AppPreferences.Keys.experimentalProjectStatusShowFolder) }
        )
    }

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
                projectStatusCardSection
                NotchTerminalSettingsSection(contentSpacing: 12) {
                    NotchTerminalSectionHeading(
                        title: "settings.experimental.effects".localized,
                        subtitle: "settings.experimental.effects.subtitle".localized,
                        icon: "sparkles"
                    )

                    Text("settings.experimental.warning".localized)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    if hasAnyNoNotch {
                        NotchTerminalPreferenceToggleRow(
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

                    NotchTerminalPreferenceToggleRow(
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
            NotchTerminalSliderPreferenceRow(
                title: "settings.experimental.startupOrb.pillOffsetX".localized,
                subtitle: "settings.experimental.startupOrb.pillOffsetX.subtitle".localized,
                icon: "arrow.left.and.right.circle",
                value: startupOrbPillOffsetXBinding,
                range: -80 ... 80,
                step: 1,
                valueFormatter: { "\(Int($0)) pt" }
            )

            NotchTerminalSliderPreferenceRow(
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
            NotchTerminalSliderPreferenceRow(
                title: "settings.experimental.startupOrb.notchOffsetX".localized,
                subtitle: "settings.experimental.startupOrb.notchOffsetX.subtitle".localized,
                icon: "arrow.left.and.right.circle",
                value: startupOrbNotchOffsetXBinding,
                range: -120 ... 120,
                step: 1,
                valueFormatter: { "\(Int($0)) pt" }
            )

            NotchTerminalSliderPreferenceRow(
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
        NotchTerminalSettingsSection(contentSpacing: 12) {
            NotchTerminalSectionHeading(
                title: "settings.experimental.startupOrb.section".localized,
                subtitle: "settings.experimental.startupOrb.section.subtitle".localized,
                icon: "circle.grid.2x1.right.filled"
            )

            NotchTerminalPreferenceToggleRow(
                title: "settings.experimental.startupOrb".localized,
                subtitle: "settings.experimental.startupOrb.subtitle".localized,
                icon: "circle.grid.2x1.right.filled",
                binding: startupOrbEnabledBinding
            )

            if experimentalFeatures.startupOrbEnabled && hasAnyNoNotch {
                startupOrbPillSection
            }

            if experimentalFeatures.startupOrbEnabled && hasAnyPhysicalNotch {
                startupOrbNotchSection
            }
        }
    }

    private var dockingSection: some View {
        NotchTerminalSettingsSection(contentSpacing: 12) {
            NotchTerminalSectionHeading(
                title: "settings.appearance.docking".localized,
                subtitle: "settings.appearance.docking.subtitle".localized,
                icon: "link"
            )

            NotchTerminalPreferenceToggleRow(
                title: "settings.experimental.dragToNotch".localized,
                subtitle: "settings.experimental.dragToNotch.subtitle".localized,
                icon: "arrow.down.to.line.compact",
                binding: dragToNotchBinding
            )

            if experimentalFeatures.dragToNotchEnabled {
                NotchTerminalSliderPreferenceRow(
                    title: "settings.notchDockingSensitivity".localized,
                    subtitle: "settings.notchDockingSensitivity.subtitle".localized,
                    icon: "record.circle",
                    value: notchDockingSensitivityBinding,
                    range: 0 ... 100,
                    step: 2,
                    valueFormatter: { "\(Int($0)) pt" }
                )
            }
        }
    }

    private var debugSection: some View {
        NotchTerminalSettingsSection(contentSpacing: 12) {
            NotchTerminalSectionHeading(
                title: "settings.experimental.debug".localized,
                subtitle: "settings.experimental.debug.subtitle".localized,
                icon: "ladybug"
            )

            NotchTerminalPreferenceToggleRow(
                title: "settings.experimental.hitTestDebugOverlay".localized,
                subtitle: "settings.experimental.hitTestDebugOverlay.subtitle".localized,
                icon: "viewfinder.circle",
                binding: hitTestDebugOverlayBinding
            )
        }
    }

    private var geometrySection: some View {
        Group {
            if hasAnyPhysicalNotch {
                NotchTerminalSettingsSection(contentSpacing: 12) {
                    NotchTerminalSectionHeading(
                        title: "settings.appearance.geometry".localized,
                        subtitle: "settings.appearance.geometry.subtitle".localized,
                        icon: "aspectratio"
                    )

                    Text("settings.experimental.notchOffsets.note".localized)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    NotchTerminalSliderPreferenceRow(
                        title: "settings.notchWidthOffset".localized,
                        subtitle: "settings.notchWidthOffset.subtitle".localized,
                        icon: "arrow.left.and.right",
                        value: $notchWidthOffset,
                        range: -80 ... 80,
                        step: 1,
                        valueFormatter: { "\(Int($0))" }
                    )

                    NotchTerminalSliderPreferenceRow(
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

    private var projectStatusCardSection: some View {
        NotchTerminalSettingsSection(contentSpacing: 12) {
            NotchTerminalSectionHeading(
                title: "Project Status Card",
                subtitle: "Display contextual project information in the Notch overlay",
                icon: "lanyardcard.fill"
            )

            NotchTerminalPreferenceToggleRow(
                title: "Enable Project Status Card",
                subtitle: "Show the card when Notch is expanded",
                icon: "menubar.rectangle",
                binding: projectStatusCardEnabledBinding
            )

            if experimentalFeatures.projectStatusCardEnabled {
                VStack(alignment: .leading, spacing: 12) {
                    NotchTerminalPreferenceToggleRow(
                        title: "Show Folder Name",
                        subtitle: "Display the active terminal's project folder",
                        icon: "folder",
                        binding: projectStatusShowFolderBinding
                    )

                    NotchTerminalPreferenceToggleRow(
                        title: "Show Git Status",
                        subtitle: "Display current branch and pending changes",
                        icon: "arrow.triangle.branch",
                        binding: projectStatusShowGitBinding
                    )
                }
                .padding(.leading, 32)
            }
        }
    }
}

#Preview("Settings - Experimental") {
    ExperimentalSettingsView()
        .frame(width: 620, height: 420)
}
