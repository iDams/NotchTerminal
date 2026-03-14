import SwiftUI

enum SettingsTab: String, Hashable {
    case general
    case notch
    case appearance
    case about
    case aiProviders
    case aiCronjobs
    case experimental

    init(uiTestValue: String) {
        switch uiTestValue {
        case "notch":
            self = .notch
        case "appearance":
            self = .appearance
        case "about":
            self = .about
        case "aiproviders":
            self = .aiProviders
        case "aicronjobs":
            self = .aiCronjobs
        case "experimental":
            self = .experimental
        default:
            self = .general
        }
    }
}

struct SettingsMeasuredHeightsPreferenceKey: PreferenceKey {
    static let defaultValue: [SettingsTab: CGFloat] = [:]

    static func reduce(value: inout [SettingsTab: CGFloat], nextValue: () -> [SettingsTab: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct SettingsContentHeightReporter: ViewModifier {
    let tab: SettingsTab

    func body(content: Content) -> some View {
        content.background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: SettingsMeasuredHeightsPreferenceKey.self,
                    value: [tab: ceil(proxy.size.height)]
                )
            }
        )
    }
}

extension View {
    func reportSettingsContentHeight(for tab: SettingsTab) -> some View {
        modifier(SettingsContentHeightReporter(tab: tab))
    }
}

extension Notification.Name {
    static let settingsTabSelectionRequested = Notification.Name("NotchTerminal.settingsTabSelectionRequested")
}

@MainActor
enum SettingsNavigationCoordinator {
    private static let requestedTabKey = "NotchTerminal.settingsRequestedTab"

    static func request(tab: SettingsTab) {
        UserDefaults.standard.set(tab.rawValue, forKey: requestedTabKey)
        NotificationCenter.default.post(
            name: .settingsTabSelectionRequested,
            object: nil,
            userInfo: ["tab": tab.rawValue]
        )
    }

    static func consumePendingTab() -> SettingsTab? {
        guard let rawValue = UserDefaults.standard.string(forKey: requestedTabKey),
              let tab = SettingsTab(rawValue: rawValue) else {
            return nil
        }

        UserDefaults.standard.removeObject(forKey: requestedTabKey)
        return tab
    }

    static func pendingRequestedTab() -> SettingsTab? {
        guard let rawValue = UserDefaults.standard.string(forKey: requestedTabKey) else {
            return nil
        }

        return SettingsTab(rawValue: rawValue)
    }
}

struct NotchTerminalPreferenceToggleRow: View {
    let title: String
    let subtitle: String?
    let icon: String?
    @Binding var binding: Bool
    var accessibilityID: String?

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
                .accessibilityLabel(title)
                .accessibilityIdentifier(accessibilityID ?? "")
        }
        .padding(.vertical, 2)
        .accessibilityIdentifier(accessibilityID ?? "")
    }
}

struct NotchTerminalSliderPreferenceRow: View {
    let title: String
    let subtitle: String?
    let icon: String?
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let valueFormatter: (Double) -> String
    var accessibilityID: String?

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
                .accessibilityIdentifier(accessibilityID ?? "")
        }
        .padding(.vertical, 2)
        .accessibilityIdentifier(accessibilityID ?? "")
    }
}

struct NotchTerminalSettingsSection<Content: View>: View {
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

struct NotchTerminalSectionHeading: View {
    let title: String
    let subtitle: String
    let icon: String
    var helpTooltip: String? = nil
    @State private var isShowingHelp = false

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

            Spacer(minLength: 8)

            if let helpTooltip, !helpTooltip.isEmpty {
                Button {
                    isShowingHelp.toggle()
                } label: {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $isShowingHelp, arrowEdge: .top) {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Section Help")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                                    .textCase(.uppercase)

                                Label(title, systemImage: icon)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                            }

                            Spacer(minLength: 8)

                            Button {
                                isShowingHelp = false
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .buttonStyle(.plain)
                            .keyboardShortcut(.cancelAction)
                            .accessibilityLabel("Close help")
                        }

                        Divider()

                        Text(helpTooltip)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .frame(width: 360, alignment: .leading)
                    .background(.regularMaterial)
                }
                .help("More info")
                .accessibilityLabel("\(title). More info")
            }
        }
    }
}
