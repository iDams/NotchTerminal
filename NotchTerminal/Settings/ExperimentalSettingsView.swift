import SwiftUI

struct ExperimentalSettingsView: View {
    @AppStorage(AppPreferences.Keys.enableCRTFilter) var enableCRTFilter: Bool = AppPreferences.Defaults.enableCRTFilter
    @AppStorage(AppPreferences.Keys.fakeNotchGlowEnabled) var fakeNotchGlowEnabled: Bool = AppPreferences.Defaults.fakeNotchGlowEnabled
    @AppStorage(AppPreferences.Keys.fakeNotchGlowTheme) var fakeNotchGlowTheme: NotchViewModel.GlowTheme = .cyberpunk
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
