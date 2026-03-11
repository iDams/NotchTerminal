import SwiftUI
import AppKit

@MainActor
final class AIPlaygroundWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?

    func show(on screen: NSScreen?) {
        let targetScreen = screen ?? NSScreen.main ?? NSScreen.screens.first
        guard let targetScreen else { return }

        if let window {
            position(window: window, on: targetScreen)
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentSize = NSSize(width: 1180, height: 760)
        let window = NSWindow(
            contentRect: CGRect(origin: .zero, size: contentSize),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "AI Playground"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.delegate = self
        window.center()
        position(window: window, on: targetScreen)
        window.contentView = NSHostingView(rootView: AIPlaygroundView())
        self.window = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }

    private func position(window: NSWindow, on screen: NSScreen) {
        let visibleFrame = screen.visibleFrame
        let origin = CGPoint(
            x: visibleFrame.midX - window.frame.width / 2,
            y: visibleFrame.midY - window.frame.height / 2
        )
        window.setFrameOrigin(origin)
    }
}

private struct PlaygroundSuggestion: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
}

private struct PlaygroundMessage: Identifiable {
    let id = UUID()
    let role: Role
    let text: String

    enum Role {
        case user
        case assistant
    }
}

struct AIPlaygroundView: View {
    @State private var prompt = ""
    @State private var selectedMode = "Animation"
    @State private var messages: [PlaygroundMessage] = [
        .init(role: .assistant, text: "Describe an idea for a UI, effect, or interaction. This playground is a visual placeholder for future AI workflows.")
    ]

    private let modes = ["Animation", "Prototype", "Prompt", "Notch UI"]
    private let suggestions: [PlaygroundSuggestion] = [
        .init(title: "Docking Flow", subtitle: "Design the snap animation"),
        .init(title: "Terminal Alias", subtitle: "Name a task session"),
        .init(title: "AI Chat", subtitle: "Sketch a command copilot"),
        .init(title: "Aurora Theme", subtitle: "Explore motion and color"),
        .init(title: "Dynamic Bubble", subtitle: "Refine the orb interaction"),
        .init(title: "Open Ports", subtitle: "Build a safer action flow")
    ]

    var body: some View {
        ZStack {
            Color.black

            backgroundBlobs

            VStack(spacing: 0) {
                toolbar
                content
                composer
            }
            .padding(24)
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var toolbar: some View {
        HStack {
            Spacer()

            HStack(spacing: 12) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 26, height: 26)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Playground")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.64))
                    Picker("Mode", selection: $selectedMode) {
                        ForEach(modes, id: \.self) { mode in
                            Text(mode).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .tint(.white)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.black.opacity(0.65), in: Capsule())
            .overlay(
                Capsule().stroke(.white.opacity(0.10), lineWidth: 1)
            )

            Spacer()

            Button("Save") {}
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.black)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(Color(red: 1.0, green: 0.87, blue: 0.02), in: Capsule())
                .buttonStyle(.plain)
        }
        .padding(.bottom, 16)
    }

    private var content: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Idea Stream")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))

                ScrollView {
                    VStack(spacing: 14) {
                        ForEach(messages) { message in
                            messageBubble(message)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 16) {
                Text("Suggestions")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(suggestions) { suggestion in
                        suggestionCard(suggestion)
                    }
                }

                Spacer()
            }
            .frame(width: 340)
        }
        .padding(.top, 10)
    }

    private var composer: some View {
        HStack(spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .foregroundStyle(Color(red: 0.98, green: 0.70, blue: 0.44))

                TextField("Describe a flow, screen, or interaction", text: $prompt)
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .background(.black.opacity(0.52), in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 1))

            Button(action: submitPrompt) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 56, height: 56)
                    .background(Color(red: 0.98, green: 0.70, blue: 0.44), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 22)
    }

    private var backgroundBlobs: some View {
        ZStack {
            RadialGradient(
                colors: [Color(red: 0.28, green: 0.54, blue: 1.0).opacity(0.48), .clear],
                center: .center,
                startRadius: 20,
                endRadius: 260
            )
            .frame(width: 420, height: 420)
            .blur(radius: 12)
            .offset(x: 40, y: -20)

            RadialGradient(
                colors: [Color(red: 1.0, green: 0.48, blue: 0.18).opacity(0.34), .clear],
                center: .center,
                startRadius: 20,
                endRadius: 240
            )
            .frame(width: 360, height: 360)
            .blur(radius: 18)
            .offset(x: 130, y: 34)

            RadialGradient(
                colors: [Color(red: 0.86, green: 0.26, blue: 0.78).opacity(0.30), .clear],
                center: .center,
                startRadius: 10,
                endRadius: 220
            )
            .frame(width: 320, height: 320)
            .blur(radius: 18)
            .offset(x: 10, y: 120)
        }
        .allowsHitTesting(false)
    }

    private func messageBubble(_ message: PlaygroundMessage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(message.role == .assistant ? "Playground" : "You")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.52))

            Text(message.text)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(
                    message.role == .assistant
                        ? LinearGradient(
                            colors: [.white, Color(red: 0.97, green: 0.56, blue: 0.72)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        : LinearGradient(colors: [.white], startPoint: .leading, endPoint: .trailing)
                )
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(.black.opacity(0.34), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func suggestionCard(_ suggestion: PlaygroundSuggestion) -> some View {
        Button {
            prompt = suggestion.subtitle
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(suggestion.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                Text(suggestion.subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.58))
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func submitPrompt() {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        messages.append(.init(role: .user, text: trimmed))
        messages.append(.init(role: .assistant, text: "This is a visual playground stub. Next step is wiring a real AI provider or prompt-to-action pipeline."))
        prompt = ""
    }
}
