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

    @AppStorage("hapticFeedback") var hapticFeedback: Bool = true
    @AppStorage("showDockIcon") var showDockIcon: Bool = false
    @AppStorage("showCostSummary") var showCostSummary: Bool = false
    @AppStorage("backgroundRefreshCadenceMinutes") var backgroundRefreshCadenceMinutes: Int = 5
    @AppStorage("checkProviderStatus") var checkProviderStatus: Bool = true
    @AppStorage("autoOpenOnHover") var autoOpenOnHover: Bool = true
    @AppStorage("lockWhileTyping") var lockWhileTyping: Bool = true
    @AppStorage("preventCloseOnMouseLeave") var preventCloseOnMouseLeave: Bool = false
    @AppStorage("showChipCloseButtonOnHover") var showChipCloseButtonOnHover: Bool = true
    @AppStorage("confirmBeforeCloseAll") var confirmBeforeCloseAll: Bool = true
    @AppStorage("closeActionMode") var closeActionMode: String = CloseActionDisplayMode.terminateProcessAndClose.rawValue
    
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
    @AppStorage("contentPadding") var contentPadding: Double = 14
    @AppStorage("notchWidthOffset") var notchWidthOffset: Double = -80
    @AppStorage("notchHeightOffset") var notchHeightOffset: Double = -8
    
    @AppStorage("terminalDefaultWidth") var terminalDefaultWidth: Double = 640
    @AppStorage("terminalDefaultHeight") var terminalDefaultHeight: Double = 400
    @AppStorage("notchDockingSensitivity") var notchDockingSensitivity: Double = 20
    
    @AppStorage("compactTickerEnabled") var compactTickerEnabled: Bool = true
    @AppStorage("compactTickerInterval") var compactTickerInterval: Double = 20
    @AppStorage("compactTickerClosedExtraWidth") var compactTickerClosedExtraWidth: Double = 216
    // @AppStorage does not support Codable enum RawRepresentable directly in some iOS/macOS versions easily without extension, 
    // but typically standard types work. For enums, we often cast to raw values or use specific wrappers. 
    // Since we added these as AppStorage in ViewModel, let's use the same keys but bind to local state or just use raw strings/ints if needed.
    // For simplicity in this view, we will access UserDefaults directly or use simpler bindings if AppStorage fails for enums.
    // Let's rely on standard AppStorage for basic types.
    
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

// Helpers

struct ZenithPreferenceToggleRow: View {
    let title: String
    let subtitle: String?
    let icon: String?
    @Binding var binding: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 20, height: 20)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body.weight(.medium))

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 8)

            Toggle("", isOn: $binding)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.vertical, 2)
    }
}

struct ZenithSliderPreferenceRow: View {
    let title: String
    let subtitle: String?
    let icon: String?
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let valueFormatter: (Double) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 20, height: 20)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.medium))

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()
                Text(valueFormatter(value))
                    .font(.footnote.monospacedDigit())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(Capsule())
                    .foregroundStyle(.secondary)
            }

            Slider(value: $value, in: range, step: step)
        }
        .padding(.vertical, 2)
    }
}

struct ZenithSettingsSection<Content: View>: View {
    let contentSpacing: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: contentSpacing) {
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.46))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }
}

struct ZenithSectionHeading: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

struct AboutSettingsView: View {
    @State private var showThirdPartyNotices = false
    @State private var showOpenURLError = false
    @State private var openURLErrorMessage = ""

    private let websiteURL = URL(string: "https://github.com/iDams/NotchTerminal")
    private let changelogURL = URL(string: "https://github.com/iDams/NotchTerminal/releases")
    private let donationURL = URL(string: "https://buymeacoffee.com/marcoastorj")

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard
                actionsList
                thirdPartyButton
                Divider()
                copyrightText
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showThirdPartyNotices) {
            ThirdPartyNoticesSheet()
        }
        .alert("Could not open link", isPresented: $showOpenURLError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(openURLErrorMessage)
        }
    }

    private var headerCard: some View {
        VStack(spacing: 12) {
            Image("AppLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 92, height: 92)
                .padding(.top, 8)

            VStack(spacing: 4) {
                Text("settings.about.title".localized)
                    .font(.system(size: 34, weight: .bold, design: .rounded))

                Text("settings.about.version".localized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text("app.tagline".localized)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 24)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.45))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private var actionsList: some View {
        VStack(spacing: 8) {
            AboutActionButton(
                title: "settings.about.checkUpdates".localized,
                subtitle: "settings.about.checkUpdates.subtitle".localized,
                systemImage: "arrow.triangle.2.circlepath"
            ) {
                checkForUpdatesOrOpenReleases()
            }

            AboutActionButton(
                title: "settings.about.releaseNotes".localized,
                subtitle: "settings.about.releaseNotes.subtitle".localized,
                systemImage: "newspaper"
            ) {
                openURL(changelogURL)
            }

            AboutActionButton(
                title: "settings.about.website".localized,
                subtitle: "settings.about.website.subtitle".localized,
                systemImage: "globe"
            ) {
                openURL(websiteURL)
            }

            AboutActionButton(
                title: "settings.about.donate".localized,
                subtitle: "settings.about.donate.subtitle".localized,
                systemImage: "cup.and.saucer.fill"
            ) {
                openURL(donationURL)
            }
        }
        .padding(.horizontal, 6)
        .padding(.top, 2)
    }

    private var thirdPartyButton: some View {
        Button {
            showThirdPartyNotices = true
        } label: {
            Label("settings.about.thirdParty".localized, systemImage: "doc.text.magnifyingglass")
                .font(.footnote)
        }
        .buttonStyle(.link)
    }

    private var copyrightText: some View {
        Text("settings.about.copyright".localized)
            .font(.footnote)
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 14)
            .padding(.bottom, 4)
    }

    private func checkForUpdatesOrOpenReleases() {
        let sparkleSelector = Selector(("checkForUpdates:"))
        if NSApp.sendAction(sparkleSelector, to: nil, from: nil) {
            return
        }
        openURL(changelogURL)
    }

    private func openURL(_ url: URL?) {
        guard let url else {
            openURLErrorMessage = "The link is not configured."
            showOpenURLError = true
            return
        }
        if !NSWorkspace.shared.open(url) {
            openURLErrorMessage = "Unable to open: \(url.absoluteString)"
            showOpenURLError = true
        }
    }
}

struct AboutActionButton: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 20)
                    .foregroundStyle(.primary)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct ThirdPartyNoticesSheet: View {
    @Environment(\.dismiss) private var dismiss
    private let markdown: String = {
        let bundle = Bundle.main
        let candidateURLs: [URL?] = [
            bundle.url(forResource: "THIRD_PARTY_NOTICES", withExtension: "md"),
            bundle.url(forResource: "THIRD_PARTY_NOTICES", withExtension: "md", subdirectory: "Resources")
        ]

        for url in candidateURLs.compactMap({ $0 }) {
            if let text = try? String(contentsOf: url, encoding: .utf8) {
                return text
            }
        }

        return """
        # Third-Party Notices

        The notices file could not be loaded from the app bundle.

        - SwiftTerm (MIT): https://github.com/migueldeicaza/SwiftTerm
        - Fork used by this project: https://github.com/iDams/SwiftTerm
        """
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("settings.about.thirdParty".localized)
                    .font(.title3.weight(.semibold))
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close")
            }

            Text("settings.about.thirdParty.subtitle".localized)
                .font(.footnote)
                .foregroundStyle(.secondary)

            MarkdownTextView(markdown: markdown)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .textBackgroundColor).opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )

            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(minWidth: 640, minHeight: 480)
    }
}

struct MarkdownTextView: NSViewRepresentable {
    let markdown: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 16, height: 14)
        textView.linkTextAttributes = [
            .foregroundColor: NSColor.systemBlue
        ]

        scrollView.documentView = textView
        update(textView: textView)
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        update(textView: textView)
    }

    private func update(textView: NSTextView) {
        textView.textStorage?.setAttributedString(styledText(from: markdown))
    }

    private func styledText(from markdown: String) -> NSAttributedString {
        let output = NSMutableAttributedString()

        let bodyParagraph = NSMutableParagraphStyle()
        bodyParagraph.lineSpacing = 2
        bodyParagraph.paragraphSpacing = 8

        let bulletParagraph = NSMutableParagraphStyle()
        bulletParagraph.lineSpacing = 2
        bulletParagraph.paragraphSpacing = 6
        bulletParagraph.headIndent = 16
        bulletParagraph.firstLineHeadIndent = 0

        let h1Attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 21, weight: .bold),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: bodyParagraph
        ]
        let h2Attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15, weight: .semibold),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: bodyParagraph
        ]
        let bodyAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: bodyParagraph
        ]
        let bulletAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: bulletParagraph
        ]

        for rawLine in markdown.components(separatedBy: .newlines) {
            let line = rawLine.replacingOccurrences(of: "`", with: "")
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                output.append(NSAttributedString(string: "\n"))
                continue
            }

            let start = output.length
            if line.hasPrefix("# ") {
                output.append(NSAttributedString(string: String(line.dropFirst(2)) + "\n", attributes: h1Attrs))
            } else if line.hasPrefix("## ") {
                output.append(NSAttributedString(string: String(line.dropFirst(3)) + "\n", attributes: h2Attrs))
            } else if line.hasPrefix("- ") {
                output.append(NSAttributedString(string: "• " + String(line.dropFirst(2)) + "\n", attributes: bulletAttrs))
            } else {
                output.append(NSAttributedString(string: line + "\n", attributes: bodyAttrs))
            }

            let range = NSRange(location: start, length: output.length - start)
            if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
                detector.enumerateMatches(in: output.string, options: [], range: range) { match, _, _ in
                    guard let match, let url = match.url else { return }
                    output.addAttribute(.link, value: url, range: match.range)
                    output.addAttribute(.foregroundColor, value: NSColor.systemBlue, range: match.range)
                }
            }
        }

        return output
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

#Preview("Settings - About") {
    AboutSettingsView()
        .frame(width: 620, height: 680)
}

struct ExperimentalSettingsView: View {
    @AppStorage("enableCRTFilter") var enableCRTFilter: Bool = false
    @AppStorage("fakeNotchGlowEnabled") var fakeNotchGlowEnabled: Bool = false
    @AppStorage("fakeNotchGlowTheme") var fakeNotchGlowTheme: NotchViewModel.GlowTheme = .cyberpunk
    @AppStorage("auroraBackgroundEnabled") var auroraBackgroundEnabled: Bool = false
    @AppStorage("auroraTheme") var auroraTheme: NotchViewModel.AuroraTheme = .classic

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
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
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

                    if hasAnyNotch {
                        ZenithPreferenceToggleRow(
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
                            .padding(.leading, 32) // Indent to show it's a sub-setting
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
}

#Preview("Settings - Experimental") {
    ExperimentalSettingsView()
        .frame(width: 620, height: 420)
}
