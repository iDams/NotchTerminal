import SwiftUI
import AppKit

private enum SettingsTab: Hashable {
    case general
    case appearance
    case about
    case experimental
}

struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .general

    private var idealHeight: CGFloat {
        switch selectedTab {
        case .general:
            return 430
        case .appearance:
            return 560
        case .about:
            return 640
        case .experimental:
            return 320
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView()
                .tag(SettingsTab.general)
                .tabItem {
                    Label("settings.general".localized, systemImage: "gear")
                }

            AppearanceSettingsView()
                .tag(SettingsTab.appearance)
                .tabItem {
                    Label("settings.appearance".localized, systemImage: "paintpalette")
                }

            AboutSettingsView()
                .tag(SettingsTab.about)
                .tabItem {
                    Label("settings.about".localized, systemImage: "info.circle")
                }

            ExperimentalSettingsView()
                .tag(SettingsTab.experimental)
                .tabItem {
                    Label("settings.experimental".localized, systemImage: "flask")
                }
        }
        .frame(
            minWidth: 560,
            idealWidth: 560,
            maxWidth: 760,
            minHeight: 420,
            idealHeight: min(idealHeight, 700),
            maxHeight: 700
        )
        .onAppear {
            // Center the settings window
            for window in NSApplication.shared.windows {
                if window.title == "Settings" || window.identifier?.rawValue == "com_apple_SwiftUI_Settings_window" {
                    window.center()
                    break
                }
            }
        }
    }
}

struct GeneralSettingsView: View {
    private enum CloseActionDisplayMode: String, CaseIterable, Identifiable {
        case closeWindowOnly
        case terminateProcessAndClose

        var id: String { rawValue }

        var title: String {
            switch self {
            case .closeWindowOnly:
                return "settings.closeActionMode.closeWindow".localized
            case .terminateProcessAndClose:
                return "settings.closeActionMode.terminateProcess".localized
            }
        }
    }

    @AppStorage(AppPreferences.Keys.hapticFeedback) var hapticFeedback: Bool = AppPreferences.Defaults.hapticFeedback
    @AppStorage(AppPreferences.Keys.showDockIcon) var showDockIcon: Bool = AppPreferences.Defaults.showDockIcon
    @AppStorage(AppPreferences.Keys.showCostSummary) var showCostSummary: Bool = AppPreferences.Defaults.showCostSummary
    @AppStorage(AppPreferences.Keys.backgroundRefreshCadenceMinutes) var backgroundRefreshCadenceMinutes: Int = AppPreferences.Defaults.backgroundRefreshCadenceMinutes
    @AppStorage(AppPreferences.Keys.checkProviderStatus) var checkProviderStatus: Bool = AppPreferences.Defaults.checkProviderStatus
    @AppStorage(AppPreferences.Keys.autoOpenOnHover) var autoOpenOnHover: Bool = AppPreferences.Defaults.autoOpenOnHover
    @AppStorage(AppPreferences.Keys.autoOpenOnHoverDelay) var autoOpenOnHoverDelay: Double = AppPreferences.Defaults.autoOpenOnHoverDelay
    @AppStorage(AppPreferences.Keys.lockWhileTyping) var lockWhileTyping: Bool = AppPreferences.Defaults.lockWhileTyping
    @AppStorage(AppPreferences.Keys.preventCloseOnMouseLeave) var preventCloseOnMouseLeave: Bool = AppPreferences.Defaults.preventCloseOnMouseLeave
    @AppStorage(AppPreferences.Keys.showChipCloseButtonOnHover) var showChipCloseButtonOnHover: Bool = AppPreferences.Defaults.showChipCloseButtonOnHover
    @AppStorage(AppPreferences.Keys.confirmBeforeCloseAll) var confirmBeforeCloseAll: Bool = AppPreferences.Defaults.confirmBeforeCloseAll
    @AppStorage(AppPreferences.Keys.closeActionMode) var closeActionMode: String = AppPreferences.Defaults.closeActionMode

    @ObservedObject private var languageManager = LanguageManager.shared
    @State private var selectedLanguage: String = LanguageManager.shared.currentLanguage
    @State private var useSystemLanguage: Bool = !LanguageManager.shared.userHasSelectedLanguage

    private var languageKey: String {
        LanguageManager.shared.currentLanguage
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                languageSection
                systemSection
                automationSection
                terminalActionsSection
                dangerZoneSection
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .id(languageKey)
    }

    private var languageSection: some View {
        ZenithSettingsSection(contentSpacing: 12) {
            ZenithSectionHeading(
                title: "settings.language".localized,
                subtitle: "settings.language.subtitle".localized,
                icon: "globe"
            )

            Toggle(isOn: $useSystemLanguage) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("settings.language.system".localized)
                        .font(.body.weight(.medium))
                    Text("settings.language.system.subtitle".localized)
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
            }
            .onChange(of: useSystemLanguage) { _, newValue in
                if newValue {
                    languageManager.resetToSystemLanguage()
                    selectedLanguage = languageManager.currentLanguage
                }
            }
            .padding(.vertical, 2)

            if !useSystemLanguage {
                Picker("settings.language".localized, selection: $selectedLanguage) {
                    ForEach(languageManager.availableLanguages, id: \.code) { language in
                        Text(language.name).tag(language.code)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 210)
                .onChange(of: selectedLanguage) { _, newValue in
                    languageManager.setLanguage(newValue)
                }
            }
        }
    }

    private var systemSection: some View {
        ZenithSettingsSection(contentSpacing: 12) {
            ZenithSectionHeading(
                title: "settings.system".localized,
                subtitle: "settings.system.subtitle".localized,
                icon: "macwindow"
            )

            ZenithPreferenceToggleRow(
                title: "settings.hapticFeedback".localized,
                subtitle: "settings.hapticFeedback.subtitle".localized,
                icon: "waveform.path",
                binding: $hapticFeedback
            )

            ZenithPreferenceToggleRow(
                title: "settings.showDockIcon".localized,
                subtitle: "settings.showDockIcon.subtitle".localized,
                icon: "dock.rectangle",
                binding: $showDockIcon
            )
        }
    }

    private var automationSection: some View {
        ZenithSettingsSection(contentSpacing: 12) {
            ZenithSectionHeading(
                title: "settings.automation".localized,
                subtitle: "settings.automation.subtitle".localized,
                icon: "cursorarrow.motionlines"
            )

            ZenithPreferenceToggleRow(
                title: "settings.autoOpenOnHover".localized,
                subtitle: "settings.autoOpenOnHover.subtitle".localized,
                icon: "cursorarrow.rays",
                binding: $autoOpenOnHover
            )

            if autoOpenOnHover {
                ZenithSliderPreferenceRow(
                    title: "settings.autoOpenOnHoverDelay".localized,
                    subtitle: "settings.autoOpenOnHoverDelay.subtitle".localized,
                    icon: "timer",
                    value: $autoOpenOnHoverDelay,
                    range: 0.1 ... 2.0,
                    step: 0.1,
                    valueFormatter: { String(format: "%.1fs", $0) }
                )
            }

            ZenithPreferenceToggleRow(
                title: "settings.lockWhileTyping".localized,
                subtitle: "settings.lockWhileTyping.subtitle".localized,
                icon: "keyboard",
                binding: $lockWhileTyping
            )
        }
    }

    private var terminalActionsSection: some View {
        ZenithSettingsSection(contentSpacing: 12) {
            ZenithSectionHeading(
                title: "settings.terminalActions".localized,
                subtitle: "settings.terminalActions.subtitle".localized,
                icon: "slider.horizontal.3"
            )

            ZenithPreferenceToggleRow(
                title: "settings.showChipCloseButton".localized,
                subtitle: "settings.showChipCloseButton.subtitle".localized,
                icon: "xmark.circle",
                binding: $showChipCloseButtonOnHover
            )

            ZenithPreferenceToggleRow(
                title: "settings.confirmBeforeCloseAll".localized,
                subtitle: "settings.confirmBeforeCloseAll.subtitle".localized,
                icon: "exclamationmark.triangle",
                binding: $confirmBeforeCloseAll
            )

            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "bolt.horizontal.circle")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 20, height: 20)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("settings.closeActionMode".localized)
                        .font(.body.weight(.medium))
                    Text("settings.closeActionMode.subtitle".localized)
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }

                Spacer(minLength: 8)

                Picker("settings.closeActionMode".localized, selection: $closeActionMode) {
                    ForEach(CloseActionDisplayMode.allCases) { mode in
                        Text(mode.title).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 210)
            }
            .padding(.vertical, 2)
        }
    }

    private var dangerZoneSection: some View {
        ZenithSettingsSection(contentSpacing: 12) {
            ZenithSectionHeading(
                title: "settings.dangerZone".localized,
                subtitle: "settings.dangerZone.subtitle".localized,
                icon: "exclamationmark.octagon"
            )

            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "power")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 20, height: 20)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("settings.quitApp".localized)
                        .font(.body.weight(.medium))
                    Text("settings.quitApp.subtitle".localized)
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }

                Spacer(minLength: 8)

                Button("action.quit".localized, role: .destructive) {
                    NSApp.terminate(nil)
                }
            }
            .padding(.vertical, 2)
        }
    }
}

struct AppearanceSettingsView: View {
    @AppStorage(AppPreferences.Keys.contentPadding) var contentPadding: Double = AppPreferences.Defaults.contentPadding
    @AppStorage(AppPreferences.Keys.notchWidthOffset) var notchWidthOffset: Double = AppPreferences.Defaults.notchWidthOffset
    @AppStorage(AppPreferences.Keys.notchHeightOffset) var notchHeightOffset: Double = AppPreferences.Defaults.notchHeightOffset

    @AppStorage(AppPreferences.Keys.terminalDefaultWidth) var terminalDefaultWidth: Double = AppPreferences.Defaults.terminalDefaultWidth
    @AppStorage(AppPreferences.Keys.terminalDefaultHeight) var terminalDefaultHeight: Double = AppPreferences.Defaults.terminalDefaultHeight
    @AppStorage(AppPreferences.Keys.notchDockingSensitivity) var notchDockingSensitivity: Double = AppPreferences.Defaults.notchDockingSensitivity

    @AppStorage(AppPreferences.Keys.compactTickerEnabled) var compactTickerEnabled: Bool = AppPreferences.Defaults.compactTickerEnabled
    @AppStorage(AppPreferences.Keys.compactTickerInterval) var compactTickerInterval: Double = AppPreferences.Defaults.compactTickerInterval
    @AppStorage(AppPreferences.Keys.compactTickerClosedExtraWidth) var compactTickerClosedExtraWidth: Double = AppPreferences.Defaults.compactTickerClosedExtraWidth

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                geometrySection
                terminalDefaultsSection
                dockingSection
                compactTickerSection
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }

    private var geometrySection: some View {
        ZenithSettingsSection(contentSpacing: 12) {
            ZenithSectionHeading(
                title: "settings.appearance.geometry".localized,
                subtitle: "settings.appearance.geometry.subtitle".localized,
                icon: "aspectratio"
            )

            ZenithSliderPreferenceRow(
                title: "settings.contentPadding".localized,
                subtitle: "settings.contentPadding.subtitle".localized,
                icon: "arrow.up.left.and.arrow.down.right",
                value: $contentPadding,
                range: 0 ... 40,
                step: 1,
                valueFormatter: { "\(Int($0))" }
            )

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

    private var terminalDefaultsSection: some View {
        ZenithSettingsSection(contentSpacing: 12) {
            ZenithSectionHeading(
                title: "settings.appearance.terminalDefaults".localized,
                subtitle: "settings.appearance.terminalDefaults.subtitle".localized,
                icon: "macwindow.on.rectangle"
            )

            ZenithSliderPreferenceRow(
                title: "settings.terminalDefaultWidth".localized,
                subtitle: "settings.terminalDefaultWidth.subtitle".localized,
                icon: "arrow.left.and.right",
                value: $terminalDefaultWidth,
                range: 400 ... 1600,
                step: 10,
                valueFormatter: { "\(Int($0))" }
            )

            ZenithSliderPreferenceRow(
                title: "settings.terminalDefaultHeight".localized,
                subtitle: "settings.terminalDefaultHeight.subtitle".localized,
                icon: "arrow.up.and.down",
                value: $terminalDefaultHeight,
                range: 200 ... 1000,
                step: 10,
                valueFormatter: { "\(Int($0))" }
            )
        }
    }

    private var dockingSection: some View {
        ZenithSettingsSection(contentSpacing: 12) {
            ZenithSectionHeading(
                title: "settings.appearance.docking".localized,
                subtitle: "settings.appearance.docking.subtitle".localized,
                icon: "magnet"
            )

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

    private var compactTickerSection: some View {
        ZenithSettingsSection(contentSpacing: 12) {
            ZenithSectionHeading(
                title: "settings.appearance.compactTicker".localized,
                subtitle: "settings.appearance.compactTicker.subtitle".localized,
                icon: "rectangle.compress.vertical"
            )

            ZenithPreferenceToggleRow(
                title: "settings.compactTickerEnabled".localized,
                subtitle: "settings.compactTickerEnabled.subtitle".localized,
                icon: "text.line.first.and.arrowtriangle.forward",
                binding: $compactTickerEnabled
            )

            if compactTickerEnabled {
                ZenithSliderPreferenceRow(
                    title: "settings.compactTickerInterval".localized,
                    subtitle: "settings.compactTickerInterval.subtitle".localized,
                    icon: "timer",
                    value: $compactTickerInterval,
                    range: 4 ... 20,
                    step: 1,
                    valueFormatter: { "\(Int($0))s" }
                )

                ZenithSliderPreferenceRow(
                    title: "settings.compactTickerClosedExtraWidth".localized,
                    subtitle: "settings.compactTickerClosedExtraWidth.subtitle".localized,
                    icon: "arrow.left.and.right.righttriangle.left.righttriangle.right",
                    value: $compactTickerClosedExtraWidth,
                    range: 0 ... 260,
                    step: 2,
                    valueFormatter: { "\(Int($0))" }
                )
            }
        }
    }
}

#Preview("Settings - General") {
    GeneralSettingsView()
        .frame(width: 620, height: 460)
}

#Preview("Settings - Appearance") {
    AppearanceSettingsView()
        .frame(width: 620, height: 620)
}
