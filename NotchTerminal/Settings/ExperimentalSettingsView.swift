import SwiftUI

struct ExperimentalSettingsView: View {
    @AppStorage(AppPreferences.Keys.enableCRTFilter) var enableCRTFilter: Bool = AppPreferences.Defaults.enableCRTFilter
    @AppStorage(AppPreferences.Keys.fakeNotchGlowEnabled) var fakeNotchGlowEnabled: Bool = AppPreferences.Defaults.fakeNotchGlowEnabled
    @AppStorage(AppPreferences.Keys.fakeNotchGlowTheme) var fakeNotchGlowTheme: NotchViewModel.GlowTheme = .cyberpunk
    @AppStorage(AppPreferences.Keys.experimentalSlapDetectionEnabled) var slapDetectionEnabled: Bool = AppPreferences.Defaults.experimentalSlapDetectionEnabled
    @AppStorage(AppPreferences.Keys.experimentalSlapDetectionSensitivity) var slapDetectionSensitivity: Double = AppPreferences.Defaults.experimentalSlapDetectionSensitivity
    @AppStorage(AppPreferences.Keys.experimentalSlapDetectionRequiredSlaps) var slapDetectionRequiredSlaps: Int = AppPreferences.Defaults.experimentalSlapDetectionRequiredSlaps
    @AppStorage(AppPreferences.Keys.experimentalSlapDetectionAction) var slapDetectionAction: String = AppPreferences.Defaults.experimentalSlapDetectionAction
    @AppStorage(AppPreferences.Keys.startupOrbPillOffsetX) var startupOrbPillOffsetX: Double = AppPreferences.Defaults.startupOrbPillOffsetX
    @AppStorage(AppPreferences.Keys.startupOrbPillOffsetY) var startupOrbPillOffsetY: Double = AppPreferences.Defaults.startupOrbPillOffsetY
    @AppStorage(AppPreferences.Keys.startupOrbNotchOffsetX) var startupOrbNotchOffsetX: Double = AppPreferences.Defaults.startupOrbNotchOffsetX
    @AppStorage(AppPreferences.Keys.startupOrbNotchOffsetY) var startupOrbNotchOffsetY: Double = AppPreferences.Defaults.startupOrbNotchOffsetY
    private var experimentalFeatures: AppPreferences.ExperimentalFeatureConfiguration {
        AppPreferences.experimentalFeatureConfiguration()
    }

    private var dragToNotchBinding: Binding<Bool> {
        Binding(
            get: { experimentalFeatures.dragToNotchEnabled },
            set: { UserDefaults.standard.set($0, forKey: AppPreferences.Keys.experimentalDragToNotchEnabled) }
        )
    }

    private var slapDetectionBinding: Binding<Bool> {
        Binding(
            get: { slapDetectionEnabled },
            set: { slapDetectionEnabled = $0 }
        )
    }

    private var slapSensitivityBinding: Binding<Double> {
        Binding(
            get: { slapDetectionSensitivity },
            set: { slapDetectionSensitivity = $0 }
        )
    }

    private var slapRequiredSlapsBinding: Binding<Double> {
        Binding(
            get: { Double(slapDetectionRequiredSlaps) },
            set: { slapDetectionRequiredSlaps = Int($0) }
        )
    }

    private var startupOrbEnabledBinding: Binding<Bool> {
        Binding(
            get: { experimentalFeatures.startupOrbEnabled },
            set: { UserDefaults.standard.set($0, forKey: AppPreferences.Keys.experimentalStartupOrbEnabled) }
        )
    }

    private var notchDockingSensitivityBinding: Binding<Double> {
        Binding(
            get: { experimentalFeatures.notchDockingSensitivity },
            set: { UserDefaults.standard.set($0, forKey: AppPreferences.Keys.notchDockingSensitivity) }
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
                experimentalNoticeSection
                slapDetectionSection
                dockingSection
                startupOrbSection
                NotchTerminalSettingsSection(contentSpacing: 12) {
                    NotchTerminalSectionHeading(
                        title: "settings.experimental.effects".localized,
                        subtitle: "settings.experimental.effects.subtitle".localized,
                        icon: "sparkles",
                        helpTooltip: "settings.experimental.effects.help".localized
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
            .reportSettingsContentHeight(for: .experimental)
        }
    }

    private var experimentalNoticeSection: some View {
        NotchTerminalSettingsSection(contentSpacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "flask")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.orange)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 6) {
                    Text("settings.experimental.notice.title".localized)
                        .font(.body.weight(.semibold))

                    Text("settings.experimental.notice.body".localized)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
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
                icon: "circle.grid.2x1.right.filled",
                helpTooltip: "settings.experimental.startupOrb.section.help".localized
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
                icon: "link",
                helpTooltip: "settings.experimental.docking.help".localized
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

    private var slapDetectionSection: some View {
        NotchTerminalSettingsSection(contentSpacing: 12) {
            NotchTerminalSectionHeading(
                title: "settings.experimental.slapDetection".localized,
                subtitle: "settings.experimental.slapDetection.subtitle".localized,
                icon: "hand.wave.fill",
                helpTooltip: "settings.experimental.slapDetection.help".localized
            )

            NotchTerminalPreferenceToggleRow(
                title: "settings.experimental.slapDetection.enable".localized,
                subtitle: "settings.experimental.slapDetection.enable.subtitle".localized,
                icon: "sensor.tag.radiowaves.forward",
                binding: slapDetectionBinding
            )

            if slapDetectionEnabled {
                NotchTerminalSliderPreferenceRow(
                    title: "settings.experimental.slapDetection.sensitivity".localized,
                    subtitle: "settings.experimental.slapDetection.sensitivity.subtitle".localized,
                    icon: "gauge.with.dots.needle.bottom.50percent",
                    value: slapSensitivityBinding,
                    range: 0 ... 100,
                    step: 5,
                    valueFormatter: { "\(Int($0))%" }
                )

                NotchTerminalSliderPreferenceRow(
                    title: "settings.experimental.slapDetection.requiredSlaps".localized,
                    subtitle: "settings.experimental.slapDetection.requiredSlaps.subtitle".localized,
                    icon: "hand.tap.fill",
                    value: slapRequiredSlapsBinding,
                    range: 1 ... 5,
                    step: 1,
                    valueFormatter: { $0 == 1 ? "1 slap".localized : "\($0) slaps".localized }
                )

                HStack(spacing: 10) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 20, height: 20)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("settings.experimental.slapDetection.action".localized)
                            .font(.body.weight(.medium))

                        Text("settings.experimental.slapDetection.action.subtitle".localized)
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                    }

                    Spacer()

                    Picker("", selection: $slapDetectionAction) {
                        ForEach(AppPreferences.SlapAction.allCases, id: \.self) { action in
                            Text("settings.experimental.slapDetection.action.\(action.rawValue)".localized)
                                .tag(action.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                .padding(.vertical, 4)
            }
        }
    }

}

#Preview("Settings - Experimental") {
    ExperimentalSettingsView()
        .frame(width: 620, height: 420)
}
