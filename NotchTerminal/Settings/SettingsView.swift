import SwiftUI
import AppKit

struct SettingsView: View {
    @State private var selectedTab: SettingsTab
    @State private var measuredTabHeights: [SettingsTab: CGFloat] = [:]
    @State private var settingsWindow: NSWindow?
    @AppStorage(AppPreferences.Keys.showExperimentalSettings) private var showExperimentalSettings = AppPreferences.Defaults.showExperimentalSettings

    private let minimumWindowWidth: CGFloat = 560
    private let maximumWindowWidth: CGFloat = 760
    private let minimumWindowHeight: CGFloat = 320
    private let maximumWindowHeight: CGFloat = 700
    private let tabChromeHeight: CGFloat = 110

    init() {
        if let requestedTab = SettingsNavigationCoordinator.pendingRequestedTab() {
            _selectedTab = State(initialValue: requestedTab)
        } else if UITestSupport.isEnabled {
            let rawTab = ProcessInfo.processInfo.environment["NOTCHTERMINAL_UI_TEST_TAB"] ?? "general"
            _selectedTab = State(initialValue: SettingsTab(uiTestValue: rawTab))
        } else {
            _selectedTab = State(initialValue: .general)
        }
    }

    private var fallbackContentHeight: CGFloat {
        switch selectedTab {
        case .general:
            return 430
        case .notch:
            return 620
        case .appearance:
            return 560
        case .about:
            return 640
        case .aiCronjobs:
            return 560
        case .experimental:
            return 320
        }
    }

    private var targetWindowHeight: CGFloat {
        let contentHeight = measuredTabHeights[selectedTab] ?? fallbackContentHeight
        return min(max(contentHeight + tabChromeHeight, minimumWindowHeight), maximumWindowHeight)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView()
                .tag(SettingsTab.general)
                .tabItem {
                    Label("settings.general".localized, systemImage: "gear")
                }

            NotchSettingsView()
                .tag(SettingsTab.notch)
                .tabItem {
                    Label("settings.notch".localized, systemImage: "slider.horizontal.below.rectangle")
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

            AICronjobsSettingsView()
                .tag(SettingsTab.aiCronjobs)
                .tabItem {
                    Label("NotchAgent", systemImage: "cpu")
                }

            if showExperimentalSettings {
                ExperimentalSettingsView()
                    .tag(SettingsTab.experimental)
                    .tabItem {
                        Label("settings.experimental".localized, systemImage: "flask")
                    }
            }
        }
        .frame(
            minWidth: minimumWindowWidth,
            idealWidth: minimumWindowWidth,
            maxWidth: maximumWindowWidth,
            minHeight: minimumWindowHeight,
            idealHeight: targetWindowHeight,
            maxHeight: maximumWindowHeight
        )
        .background(
            SettingsWindowObserver { window in
                attach(to: window)
            }
        )
        .accessibilityIdentifier("settings-root")
        .onPreferenceChange(SettingsMeasuredHeightsPreferenceKey.self) { heights in
            var nextHeights = measuredTabHeights
            var didChange = false

            for (tab, height) in heights {
                if abs((nextHeights[tab] ?? 0) - height) > 1 {
                    nextHeights[tab] = height
                    didChange = true
                }
            }

            guard didChange else { return }
            measuredTabHeights = nextHeights
            resizeSettingsWindow(animated: true)
        }
        .onAppear {
            if let requestedTab = SettingsNavigationCoordinator.consumePendingTab() {
                if requestedTab == .experimental && !showExperimentalSettings {
                    selectedTab = .general
                } else {
                    selectedTab = requestedTab
                }
            }

            if !showExperimentalSettings && selectedTab == .experimental {
                selectedTab = .general
            }
            resizeSettingsWindow(animated: false)
        }
        .onReceive(NotificationCenter.default.publisher(for: .settingsTabSelectionRequested)) { notification in
            guard let rawTab = notification.userInfo?["tab"] as? String else { return }

            let requestedTab = SettingsTab(rawValue: rawTab) ?? .general
            if requestedTab == .experimental && !showExperimentalSettings {
                selectedTab = .general
            } else {
                selectedTab = requestedTab
            }
        }
        .onChange(of: showExperimentalSettings) { _, isVisible in
            if !isVisible && selectedTab == .experimental {
                selectedTab = .general
            }
            resizeSettingsWindow(animated: true)
        }
        .onChange(of: selectedTab) { _, _ in
            resizeSettingsWindow(animated: true)
        }
    }

    private func attach(to window: NSWindow) {
        if let settingsWindow, settingsWindow === window {
            return
        }
        settingsWindow = window
        window.contentMinSize = NSSize(width: minimumWindowWidth, height: minimumWindowHeight)
        window.contentMaxSize = NSSize(width: maximumWindowWidth, height: maximumWindowHeight)
        window.center()
        resizeSettingsWindow(animated: false)
    }

    private func resizeSettingsWindow(animated: Bool) {
        guard let window = settingsWindow else { return }

        DispatchQueue.main.async {
            guard let settingsWindow = self.settingsWindow, settingsWindow === window else { return }

            let currentFrame = window.frame
            let currentContentRect = window.contentRect(forFrameRect: currentFrame)
            let targetContentSize = NSSize(
                width: min(max(currentContentRect.width, self.minimumWindowWidth), self.maximumWindowWidth),
                height: self.targetWindowHeight
            )
            let targetFrameSize = window.frameRect(forContentRect: NSRect(origin: .zero, size: targetContentSize)).size

            guard abs(currentFrame.height - targetFrameSize.height) > 1 else { return }

            let targetFrame = NSRect(
                x: currentFrame.minX,
                y: currentFrame.maxY - targetFrameSize.height,
                width: targetFrameSize.width,
                height: targetFrameSize.height
            )

            window.setFrame(targetFrame, display: true, animate: animated)
        }
    }
}

private struct SettingsWindowObserver: NSViewRepresentable {
    let onResolve: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        ObserverView(onResolve: onResolve)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let observerView = nsView as? ObserverView else { return }
        observerView.onResolve = onResolve
        DispatchQueue.main.async {
            observerView.resolveWindowIfNeeded()
        }
    }

    private final class ObserverView: NSView {
        var onResolve: (NSWindow) -> Void

        init(onResolve: @escaping (NSWindow) -> Void) {
            self.onResolve = onResolve
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            resolveWindowIfNeeded()
        }

        func resolveWindowIfNeeded() {
            guard let window else { return }
            onResolve(window)
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
    @AppStorage(AppPreferences.Keys.showExperimentalSettings) var showExperimentalSettings: Bool = AppPreferences.Defaults.showExperimentalSettings
    @AppStorage(AppPreferences.Keys.autoOpenOnHover) var autoOpenOnHover: Bool = AppPreferences.Defaults.autoOpenOnHover
    @AppStorage(AppPreferences.Keys.autoOpenOnHoverDelay) var autoOpenOnHoverDelay: Double = AppPreferences.Defaults.autoOpenOnHoverDelay
    @AppStorage(AppPreferences.Keys.lockWhileTyping) var lockWhileTyping: Bool = AppPreferences.Defaults.lockWhileTyping
    @AppStorage(AppPreferences.Keys.preventCloseOnMouseLeave) var preventCloseOnMouseLeave: Bool = AppPreferences.Defaults.preventCloseOnMouseLeave
    @ObservedObject private var languageManager = LanguageManager.shared
    @ObservedObject private var persistenceHealth = PersistenceHealth.shared
    @State private var selectedLanguage: String = LanguageManager.shared.currentLanguage
    @State private var useSystemLanguage: Bool = !LanguageManager.shared.userHasSelectedLanguage

    private var terminalActionConfiguration: AppPreferences.TerminalActionConfiguration {
        AppPreferences.terminalActionConfiguration()
    }

    private var showChipCloseButtonBinding: Binding<Bool> {
        Binding(
            get: { terminalActionConfiguration.showChipCloseButtonOnHover },
            set: { UserDefaults.standard.set($0, forKey: AppPreferences.Keys.showChipCloseButtonOnHover) }
        )
    }

    private var confirmBeforeCloseAllBinding: Binding<Bool> {
        Binding(
            get: { terminalActionConfiguration.confirmBeforeCloseAll },
            set: { AppPreferences.setConfirmBeforeCloseAll($0) }
        )
    }

    private var closeActionModeBinding: Binding<String> {
        Binding(
            get: { terminalActionConfiguration.closeActionMode },
            set: { UserDefaults.standard.set($0, forKey: AppPreferences.Keys.closeActionMode) }
        )
    }

    private var languageKey: String {
        LanguageManager.shared.currentLanguage
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let details = persistenceHealth.failureDetails {
                    persistenceWarningSection(details: details)
                }
                languageSection
                systemSection
                automationSection
                terminalActionsSection
                dangerZoneSection
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .reportSettingsContentHeight(for: .general)
        }
        .id(languageKey)
    }

    private func persistenceWarningSection(details: String) -> some View {
        NotchTerminalSettingsSection(contentSpacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "externaldrive.badge.exclamationmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.orange)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 6) {
                    Text("persistence.warning.title".localized)
                        .font(.body.weight(.semibold))

                    Text("persistence.warning.body".localized)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(String(format: "persistence.warning.details".localized, details))
                        .font(.footnote.monospaced())
                        .foregroundStyle(.tertiary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityIdentifier("persistence-warning")
    }

    private var languageSection: some View {
        NotchTerminalSettingsSection(contentSpacing: 12) {
            NotchTerminalSectionHeading(
                title: "settings.language".localized,
                subtitle: "settings.language.subtitle".localized,
                icon: "globe",
                helpTooltip: "settings.language.help".localized
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
        NotchTerminalSettingsSection(contentSpacing: 12) {
            NotchTerminalSectionHeading(
                title: "settings.system".localized,
                subtitle: "settings.system.subtitle".localized,
                icon: "macwindow",
                helpTooltip: "settings.system.help".localized
            )

            NotchTerminalPreferenceToggleRow(
                title: "settings.hapticFeedback".localized,
                subtitle: "settings.hapticFeedback.subtitle".localized,
                icon: "waveform.path",
                binding: $hapticFeedback
            )

            NotchTerminalPreferenceToggleRow(
                title: "settings.showDockIcon".localized,
                subtitle: "settings.showDockIcon.subtitle".localized,
                icon: "dock.rectangle",
                binding: $showDockIcon,
                accessibilityID: "settings-show-dock-icon-row"
            )

            NotchTerminalPreferenceToggleRow(
                title: "settings.showExperimentalSettings".localized,
                subtitle: "settings.showExperimentalSettings.subtitle".localized,
                icon: "flask",
                binding: $showExperimentalSettings
            )
        }
    }

    private var automationSection: some View {
        NotchTerminalSettingsSection(contentSpacing: 12) {
            NotchTerminalSectionHeading(
                title: "settings.automation".localized,
                subtitle: "settings.automation.subtitle".localized,
                icon: "cursorarrow.motionlines",
                helpTooltip: "settings.automation.help".localized
            )

            NotchTerminalPreferenceToggleRow(
                title: "settings.autoOpenOnHover".localized,
                subtitle: "settings.autoOpenOnHover.subtitle".localized,
                icon: "cursorarrow.rays",
                binding: $autoOpenOnHover,
                accessibilityID: "settings-auto-open-on-hover-row"
            )

            if autoOpenOnHover {
                NotchTerminalSliderPreferenceRow(
                    title: "settings.autoOpenOnHoverDelay".localized,
                    subtitle: "settings.autoOpenOnHoverDelay.subtitle".localized,
                    icon: "timer",
                    value: $autoOpenOnHoverDelay,
                    range: 0.1 ... 2.0,
                    step: 0.1,
                    valueFormatter: { String(format: "%.1fs", $0) },
                    accessibilityID: "settings-auto-open-delay"
                )
            }

            NotchTerminalPreferenceToggleRow(
                title: "settings.lockWhileTyping".localized,
                subtitle: "settings.lockWhileTyping.subtitle".localized,
                icon: "keyboard",
                binding: $lockWhileTyping
            )
        }
    }

    private var terminalActionsSection: some View {
        NotchTerminalSettingsSection(contentSpacing: 12) {
            NotchTerminalSectionHeading(
                title: "settings.terminalActions".localized,
                subtitle: "settings.terminalActions.subtitle".localized,
                icon: "slider.horizontal.3",
                helpTooltip: "settings.terminalActions.help".localized
            )

            NotchTerminalPreferenceToggleRow(
                title: "settings.showChipCloseButton".localized,
                subtitle: "settings.showChipCloseButton.subtitle".localized,
                icon: "xmark.circle",
                binding: showChipCloseButtonBinding
            )

            NotchTerminalPreferenceToggleRow(
                title: "settings.confirmBeforeCloseAll".localized,
                subtitle: "settings.confirmBeforeCloseAll.subtitle".localized,
                icon: "exclamationmark.triangle",
                binding: confirmBeforeCloseAllBinding
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

                Picker("settings.closeActionMode".localized, selection: closeActionModeBinding) {
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
        NotchTerminalSettingsSection(contentSpacing: 12) {
            NotchTerminalSectionHeading(
                title: "settings.dangerZone".localized,
                subtitle: "settings.dangerZone.subtitle".localized,
                icon: "exclamationmark.octagon",
                helpTooltip: "settings.dangerZone.help".localized
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

    @AppStorage(AppPreferences.Keys.terminalDefaultWidth) var terminalDefaultWidth: Double = AppPreferences.Defaults.terminalDefaultWidth
    @AppStorage(AppPreferences.Keys.terminalDefaultHeight) var terminalDefaultHeight: Double = AppPreferences.Defaults.terminalDefaultHeight

    @AppStorage(AppPreferences.Keys.auroraBackgroundEnabled) var auroraBackgroundEnabled: Bool = AppPreferences.Defaults.auroraBackgroundEnabled
    @AppStorage(AppPreferences.Keys.auroraTheme) var auroraTheme: NotchViewModel.AuroraTheme = .classic

    private var hasAnyNotch: Bool {
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
                terminalDefaultsSection
                effectsSection
                resetSection
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .reportSettingsContentHeight(for: .appearance)
        }
    }

    private var geometrySection: some View {
        NotchTerminalSettingsSection(contentSpacing: 12) {
            NotchTerminalSectionHeading(
                title: "settings.appearance.geometry".localized,
                subtitle: "settings.appearance.geometry.subtitle".localized,
                icon: "aspectratio",
                helpTooltip: "settings.appearance.geometry.help".localized
            )

            NotchTerminalSliderPreferenceRow(
                title: "settings.contentPadding".localized,
                subtitle: "settings.contentPadding.subtitle".localized,
                icon: "arrow.up.left.and.arrow.down.right",
                value: $contentPadding,
                range: 0 ... 40,
                step: 1,
                valueFormatter: { "\(Int($0))" }
            )
        }
    }

    private var terminalDefaultsSection: some View {
        NotchTerminalSettingsSection(contentSpacing: 12) {
            NotchTerminalSectionHeading(
                title: "settings.appearance.terminalDefaults".localized,
                subtitle: "settings.appearance.terminalDefaults.subtitle".localized,
                icon: "macwindow.on.rectangle",
                helpTooltip: "settings.appearance.terminalDefaults.help".localized
            )

            NotchTerminalSliderPreferenceRow(
                title: "settings.terminalDefaultWidth".localized,
                subtitle: "settings.terminalDefaultWidth.subtitle".localized,
                icon: "arrow.left.and.right",
                value: $terminalDefaultWidth,
                range: 400 ... 1600,
                step: 10,
                valueFormatter: { "\(Int($0))" }
            )

            NotchTerminalSliderPreferenceRow(
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


    private var effectsSection: some View {
        NotchTerminalSettingsSection(contentSpacing: 12) {
            NotchTerminalSectionHeading(
                title: "settings.appearance.effects".localized,
                subtitle: "settings.appearance.effects.subtitle".localized,
                icon: "sparkles",
                helpTooltip: "settings.appearance.effects.help".localized
            )

            if hasAnyNotch {
                NotchTerminalPreferenceToggleRow(
                    title: "settings.auroraBackground".localized,
                    subtitle: "settings.auroraBackground.subtitle".localized,
                    icon: "waveform.circle",
                    binding: $auroraBackgroundEnabled
                )

                if auroraBackgroundEnabled {
                    Picker("settings.auroraTheme".localized, selection: $auroraTheme) {
                        ForEach(NotchViewModel.AuroraTheme.allCases) { theme in
                            Text(theme.localizedName).tag(theme)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.leading, 32)
                }
            }
        }
    }

    private var resetSection: some View {
        NotchTerminalSettingsSection(contentSpacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("settings.appearance.reset".localized)
                        .font(.body.weight(.medium))
                    Text("settings.appearance.reset.subtitle".localized)
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
                Spacer(minLength: 8)
                Button("action.resetDefaults".localized) {
                    resetAppearanceDefaults()
                }
                .disabled(isUsingAppearanceDefaults)
            }
        }
    }

    private var isUsingAppearanceDefaults: Bool {
        contentPadding == AppPreferences.Defaults.contentPadding &&
        terminalDefaultWidth == AppPreferences.Defaults.terminalDefaultWidth &&
        terminalDefaultHeight == AppPreferences.Defaults.terminalDefaultHeight &&
        auroraBackgroundEnabled == AppPreferences.Defaults.auroraBackgroundEnabled &&
        auroraTheme == .classic
    }

    private func resetAppearanceDefaults() {
        contentPadding = AppPreferences.Defaults.contentPadding
        terminalDefaultWidth = AppPreferences.Defaults.terminalDefaultWidth
        terminalDefaultHeight = AppPreferences.Defaults.terminalDefaultHeight
        auroraBackgroundEnabled = AppPreferences.Defaults.auroraBackgroundEnabled
        auroraTheme = .classic
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
