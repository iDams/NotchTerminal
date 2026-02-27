import SwiftUI
import AppKit

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

#Preview("Settings - About") {
    AboutSettingsView()
        .frame(width: 620, height: 680)
}
