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
                    Label("General", systemImage: "gear")
                }

            AppearanceSettingsView()
                .tag(SettingsTab.appearance)
                .tabItem {
                    Label("Appearance", systemImage: "paintpalette")
                }

            AboutSettingsView()
                .tag(SettingsTab.about)
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }

            ExperimentalSettingsView()
                .tag(SettingsTab.experimental)
                .tabItem {
                    Label("Experimental", systemImage: "flask")
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
                return "Close window only"
            case .terminateProcessAndClose:
                return "Terminate process and close"
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ZenithSettingsSection(contentSpacing: 12) {
                    ZenithSectionHeading(
                        title: "System",
                        subtitle: "Core behavior and app visibility options.",
                        icon: "macwindow"
                    )

                    ZenithPreferenceToggleRow(
                        title: "Enable haptic feedback",
                        subtitle: "Use haptics when interactions occur in the notch.",
                        icon: "waveform.path",
                        binding: $hapticFeedback
                    )

                    ZenithPreferenceToggleRow(
                        title: "Show Dock icon",
                        subtitle: "Display the app icon in the Dock using the configured AppIcon asset.",
                        icon: "dock.rectangle",
                        binding: $showDockIcon
                    )
               }

                ZenithSettingsSection(contentSpacing: 12) {
                    ZenithSectionHeading(
                        title: "Automation",
                        subtitle: "Controls how and when the notch opens and closes.",
                        icon: "cursorarrow.motionlines"
                    )

                    ZenithPreferenceToggleRow(
                        title: "Open notch on hover",
                        subtitle: "Automatically expands the notch when the cursor reaches it.",
                        icon: "cursorarrow.rays",
                        binding: $autoOpenOnHover
                    )

                    ZenithPreferenceToggleRow(
                        title: "Keep open while typing",
                        subtitle: "Avoid auto-close while you are actively typing.",
                        icon: "keyboard",
                        binding: $lockWhileTyping
                    )
                }

                ZenithSettingsSection(contentSpacing: 12) {
                    ZenithSectionHeading(
                        title: "Terminal Actions",
                        subtitle: "Bulk actions, safety checks, and per-chip behavior.",
                        icon: "slider.horizontal.3"
                    )

                    ZenithPreferenceToggleRow(
                        title: "Show close button on chip hover",
                        subtitle: "Display a small close button when hovering a terminal chip.",
                        icon: "xmark.circle",
                        binding: $showChipCloseButtonOnHover
                    )

                    ZenithPreferenceToggleRow(
                        title: "Confirm before Close All",
                        subtitle: "Ask for confirmation before closing every terminal window.",
                        icon: "exclamationmark.triangle",
                        binding: $confirmBeforeCloseAll
                    )

                    HStack(alignment: .center, spacing: 10) {
                        Image(systemName: "bolt.horizontal.circle")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(width: 20, height: 20)
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Close action mode")
                                .font(.body.weight(.medium))
                            Text("Defines what Close does in chip/context/bulk actions.")
                                .font(.footnote)
                                .foregroundStyle(.tertiary)
                        }

                        Spacer(minLength: 8)

                        Picker("Close action mode", selection: $closeActionMode) {
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
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
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
                ZenithSettingsSection(contentSpacing: 12) {
                    ZenithSectionHeading(
                        title: "Geometry",
                        subtitle: "Fine-tune notch layout and spacing.",
                        icon: "aspectratio"
                    )

                    ZenithSliderPreferenceRow(
                        title: "Content padding",
                        subtitle: "Spacing between terminal content and notch edges.",
                        icon: "arrow.up.left.and.arrow.down.right",
                        value: $contentPadding,
                        range: 0 ... 40,
                        step: 1,
                        valueFormatter: { "\(Int($0))" }
                    )

                    ZenithSliderPreferenceRow(
                        title: "Notch width fine-tune",
                        subtitle: "Adjust horizontal notch size offset.",
                        icon: "arrow.left.and.right",
                        value: $notchWidthOffset,
                        range: -80 ... 80,
                        step: 1,
                        valueFormatter: { "\(Int($0))" }
                    )

                    ZenithSliderPreferenceRow(
                        title: "Notch height fine-tune",
                        subtitle: "Adjust vertical notch size offset.",
                        icon: "arrow.up.and.down",
                        value: $notchHeightOffset,
                        range: -48 ... 48,
                        step: 1,
                        valueFormatter: { "\(Int($0))" }
                    )
                }

                ZenithSettingsSection(contentSpacing: 12) {
                    ZenithSectionHeading(
                        title: "Terminal Window Defaults",
                        subtitle: "Size parameters for new terminal sessions.",
                        icon: "macwindow.on.rectangle"
                    )

                    ZenithSliderPreferenceRow(
                        title: "Default width",
                        subtitle: "Horizontal size in points.",
                        icon: "arrow.left.and.right",
                        value: $terminalDefaultWidth,
                        range: 400 ... 1600,
                        step: 10,
                        valueFormatter: { "\(Int($0))" }
                    )

                    ZenithSliderPreferenceRow(
                        title: "Default height",
                        subtitle: "Vertical size in points.",
                        icon: "arrow.up.and.down",
                        value: $terminalDefaultHeight,
                        range: 200 ... 1000,
                        step: 10,
                        valueFormatter: { "\(Int($0))" }
                    )
                }

                ZenithSettingsSection(contentSpacing: 12) {
                    ZenithSectionHeading(
                        title: "Docking Sensitivity",
                        subtitle: "How close a window needs to be to snap into the notch.",
                        icon: "magnet"
                    )

                    ZenithSliderPreferenceRow(
                        title: "Detection radius",
                        subtitle: "Larger means earlier detection, smaller requires getting closer.",
                        icon: "record.circle",
                        value: $notchDockingSensitivity,
                        range: 0 ... 100,
                        step: 2,
                        valueFormatter: { "\(Int($0)) pt" }
                    )
                }

                ZenithSettingsSection(contentSpacing: 12) {
                    ZenithSectionHeading(
                        title: "Compact Ticker",
                        subtitle: "Provider status in closed-notch mode.",
                        icon: "rectangle.compress.vertical"
                    )

                    ZenithPreferenceToggleRow(
                        title: "Show compact provider ticker",
                        subtitle: "When the notch is closed, rotate provider status in a compact row.",
                        icon: "text.line.first.and.arrowtriangle.forward",
                        binding: $compactTickerEnabled
                    )

                    if compactTickerEnabled {
                        ZenithSliderPreferenceRow(
                            title: "Rotation interval",
                            subtitle: "How often the provider preview changes.",
                            icon: "timer",
                            value: $compactTickerInterval,
                            range: 4 ... 20,
                            step: 1,
                            valueFormatter: { "\(Int($0))s" }
                        )

                        ZenithSliderPreferenceRow(
                            title: "Closed notch extra width",
                            subtitle: "Extra width available in compact mode.",
                            icon: "arrow.left.and.right.righttriangle.left.righttriangle.right",
                            value: $compactTickerClosedExtraWidth,
                            range: 0 ... 260,
                            step: 2,
                            valueFormatter: { "\(Int($0))" }
                        )
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
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
    private let donationURL = URL(string: "https://buymeacoffee.com/idams")

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 12) {
                    Image("AppLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 92, height: 92)
                        .padding(.top, 8)

                    VStack(spacing: 4) {
                        Text("NotchTerminal")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                        
                        Text("Version 1.0.0")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Text("A terminal emulator that lives in your notch.")
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

                VStack(spacing: 8) {
                    AboutActionButton(
                        title: "Check for Updates",
                        subtitle: "Looks for newer versions",
                        systemImage: "arrow.triangle.2.circlepath"
                    ) {
                        checkForUpdatesOrOpenReleases()
                    }

                    AboutActionButton(
                        title: "Release Notes",
                        subtitle: "See what changed",
                        systemImage: "newspaper"
                    ) {
                        openURL(changelogURL)
                    }

                    AboutActionButton(
                        title: "Project Website",
                        subtitle: "Repository and documentation",
                        systemImage: "globe"
                    ) {
                        openURL(websiteURL)
                    }

                    AboutActionButton(
                        title: "Buy Me a Coffee",
                        subtitle: "Support development",
                        systemImage: "cup.and.saucer.fill"
                    ) {
                        openURL(donationURL)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.top, 2)

                Button {
                    showThirdPartyNotices = true
                } label: {
                    Label("View Third-Party Notices", systemImage: "doc.text.magnifyingglass")
                        .font(.footnote)
                }
                .buttonStyle(.link)

                Divider()

                Text("© 2026 Marco Astorga González. All rights reserved. Released as open source.")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 4)
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
                Text("Third-Party Notices")
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

            Text("Licenses and attributions used by this app.")
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
    @AppStorage("auroraBackgroundEnabled") var auroraBackgroundEnabled: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ZenithSettingsSection(contentSpacing: 12) {
                    ZenithSectionHeading(
                        title: "Experimental Effects",
                        subtitle: "Optional visuals that may vary by screen/GPU.",
                        icon: "sparkles"
                    )
                    
                    Text("These visual effects are highly experimental and cost battery life.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    let hasAnyNotch = NSScreen.screens.contains { screen in
                        if #available(macOS 12.0, *) {
                            let left = screen.auxiliaryTopLeftArea ?? .zero
                            let right = screen.auxiliaryTopRightArea ?? .zero
                            let blockedWidth = screen.frame.width - left.width - right.width
                            return blockedWidth > 20 && min(left.height, right.height) > 0
                        }
                        return false
                    }
                    
                    let hasAnyNoNotch = NSScreen.screens.contains { screen in
                        if #available(macOS 12.0, *) {
                            let left = screen.auxiliaryTopLeftArea ?? .zero
                            let right = screen.auxiliaryTopRightArea ?? .zero
                            let blockedWidth = screen.frame.width - left.width - right.width
                            return !(blockedWidth > 20 && min(left.height, right.height) > 0)
                        }
                        return true
                    }

                    if hasAnyNoNotch {
                        ZenithPreferenceToggleRow(
                            title: "Fake Notch Glow",
                            subtitle: "Neon purple glow effect for simulated notches.",
                            icon: "sun.max.trianglebadge.exclamationmark",
                            binding: $fakeNotchGlowEnabled
                        )
                    }

                    if hasAnyNotch {
                        ZenithPreferenceToggleRow(
                            title: "Aurora Background",
                            subtitle: "Animated Metal shader behind the terminal contents.",
                            icon: "wave.3.right.circle",
                            binding: $auroraBackgroundEnabled
                        )
                    }
                    
                    ZenithPreferenceToggleRow(
                        title: "CRT Monitor Filter",
                        subtitle: "Adds curvature, scanlines, and static noise to emulate old hardware.",
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
