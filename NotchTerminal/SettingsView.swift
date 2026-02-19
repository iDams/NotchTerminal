import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            AppearanceSettingsView()
                .tabItem {
                    Label("Appearance", systemImage: "paintpalette")
                }

            AboutSettingsView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 500, height: 450)
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
    @AppStorage("hapticFeedback") var hapticFeedback: Bool = true
    @AppStorage("showCostSummary") var showCostSummary: Bool = false
    @AppStorage("backgroundRefreshCadenceMinutes") var backgroundRefreshCadenceMinutes: Int = 5
    @AppStorage("checkProviderStatus") var checkProviderStatus: Bool = true
    @AppStorage("autoOpenOnHover") var autoOpenOnHover: Bool = true
    @AppStorage("lockWhileTyping") var lockWhileTyping: Bool = true
    @AppStorage("preventCloseOnMouseLeave") var preventCloseOnMouseLeave: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ZenithSettingsSection(contentSpacing: 12) {
                    Text("System")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    ZenithPreferenceToggleRow(
                        title: "Enable haptic feedback",
                        subtitle: "Use haptics when interactions occur in the notch.",
                        binding: $hapticFeedback
                    )
               }

                ZenithSettingsSection(contentSpacing: 12) {
                    Text("Automation")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    ZenithPreferenceToggleRow(
                        title: "Open notch on hover",
                        subtitle: "Automatically expands the notch when the cursor reaches it.",
                        binding: $autoOpenOnHover
                    )

                    ZenithPreferenceToggleRow(
                        title: "Keep open while typing",
                        subtitle: "Avoid auto-close while you are actively typing.",
                        binding: $lockWhileTyping
                    )
                }
            }
            .padding()
        }
    }
}

struct AppearanceSettingsView: View {
    @AppStorage("contentPadding") var contentPadding: Double = 14
    @AppStorage("notchWidthOffset") var notchWidthOffset: Double = -80
    @AppStorage("notchHeightOffset") var notchHeightOffset: Double = -8
    
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
                    Text("Geometry")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    ZenithSliderPreferenceRow(
                        title: "Content padding",
                        value: $contentPadding,
                        range: 0 ... 40,
                        step: 1,
                        valueFormatter: { "\(Int($0))" }
                    )

                    ZenithSliderPreferenceRow(
                        title: "Notch width fine-tune",
                        value: $notchWidthOffset,
                        range: -80 ... 80,
                        step: 1,
                        valueFormatter: { "\(Int($0))" }
                    )

                    ZenithSliderPreferenceRow(
                        title: "Notch height fine-tune",
                        value: $notchHeightOffset,
                        range: -48 ... 48,
                        step: 1,
                        valueFormatter: { "\(Int($0))" }
                    )
                }

                ZenithSettingsSection(contentSpacing: 12) {
                    Text("Compact Ticker")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    ZenithPreferenceToggleRow(
                        title: "Show compact provider ticker",
                        subtitle: "When the notch is closed, rotate provider status in a compact row.",
                        binding: $compactTickerEnabled
                    )

                    if compactTickerEnabled {
                        ZenithSliderPreferenceRow(
                            title: "Rotation interval",
                            value: $compactTickerInterval,
                            range: 4 ... 20,
                            step: 1,
                            valueFormatter: { "\(Int($0))s" }
                        )

                        ZenithSliderPreferenceRow(
                            title: "Closed notch extra width",
                            value: $compactTickerClosedExtraWidth,
                            range: 0 ... 260,
                            step: 2,
                            valueFormatter: { "\(Int($0))" }
                        )
                    }
                }
            }
            .padding()
        }
    }
}

// Helpers

struct ZenithPreferenceToggleRow: View {
    let title: String
    let subtitle: String?
    @Binding var binding: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Toggle(isOn: $binding) {
                Text(title)
                    .font(.body)
            }
            .toggleStyle(.checkbox)

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct ZenithSliderPreferenceRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let valueFormatter: (Double) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Text(valueFormatter(value))
                    .foregroundStyle(.secondary)
            }
            Slider(value: $value, in: range, step: step)
        }
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
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }
}

struct AboutSettingsView: View {
    var body: some View {
        VStack(spacing: 16) {
            // Try specific path first, then bundle
            if let image = NSImage(contentsOfFile: "/Users/marco/Documents/project/NotchTerminal/NotchTerminal/NotchTerminal.svg") ?? 
                           (Bundle.main.path(forResource: "NotchTerminal", ofType: "svg").map { NSImage(contentsOfFile: $0) } ?? nil) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 128, height: 128)
            } else {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 4) {
                Text("NotchTerminal")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Version 1.0.0")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Text("A terminal emulator that lives in your notch.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
