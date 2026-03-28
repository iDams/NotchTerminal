import SwiftUI

struct OnboardingView: View {
    @ObservedObject private var launchAtLoginManager = LaunchAtLoginManager.shared
    @State private var currentPage = 0
    @State private var openAtLogin = false

    let onFinish: () -> Void

    private let pages = OnboardingPage.allCases

    var body: some View {
        ZStack(alignment: .top) {
            metalBackground

            VStack(spacing: 0) {
                heroPanel
                contentPanel
            }
        }
        .frame(width: 500, height: 610)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .ignoresSafeArea()
        .onAppear {
            openAtLogin = launchAtLoginManager.isEnabled
            launchAtLoginManager.refreshStatus()
        }
    }

    private var metalBackground: some View {
        ZStack(alignment: .topTrailing) {
            NotchMetalEffectView(
                isActive: true,
                shader: "notchFragment",
                theme: .neon,
                preferredFramesPerSecond: 30
            )
            .overlay(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.22),
                        Color.white.opacity(0.08),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

            Circle()
                .fill(.white.opacity(0.09))
                .frame(width: 180, height: 180)
                .blur(radius: 16)
                .offset(x: 92, y: -10)

            Circle()
                .fill(.white.opacity(0.08))
                .frame(width: 150, height: 150)
                .blur(radius: 12)
                .offset(x: -120, y: 96)
        }
        .ignoresSafeArea()
    }

    private var heroPanel: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            Image("AppLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 126, height: 126)
                .shadow(color: .black.opacity(0.22), radius: 16, y: 8)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 215)
    }

    private var contentPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text(current.title)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(current.body)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if current == .loginItem {
                    loginPreferenceCard
                } else {
                    highlightCard
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)

            Spacer()

            HStack {
                Button(previousButtonTitle) {
                    handlePrevious()
                }
                .buttonStyle(OnboardingSecondaryButtonStyle())
                .opacity(currentPage == 0 ? 0 : 1)
                .disabled(currentPage == 0)

                Spacer()

                pageDots

                Spacer()

                Button(nextButtonTitle) {
                    handlePrimaryAction()
                }
                .buttonStyle(OnboardingPrimaryButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.opacity(0.94))
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 24,
                bottomTrailingRadius: 24,
                topTrailingRadius: 0
            )
        )
    }

    private var highlightCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(current.calloutTitle, systemImage: current.calloutIcon)
                .font(.headline)
                .foregroundStyle(.primary)

            Text(current.calloutBody)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        .padding(.top, 6)
    }

    private var loginPreferenceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: $openAtLogin) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("onboarding.openAtLogin.title".localized)
                        .font(.headline)
                    Text("onboarding.openAtLogin.subtitle".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .toggleStyle(.checkbox)

            if launchAtLoginManager.requiresApproval {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.shield")
                        .foregroundStyle(.orange)
                    Text("onboarding.openAtLogin.approval".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text("onboarding.openAtLogin.footer".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let errorMessage = launchAtLoginManager.errorMessage {
                Text(String(format: "settings.openAtLogin.error".localized, errorMessage))
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        .padding(.top, 6)
    }

    private var pageDots: some View {
        HStack(spacing: 10) {
            ForEach(Array(pages.enumerated()), id: \.offset) { index, _ in
                Circle()
                    .fill(index == currentPage ? Color.primary.opacity(0.7) : Color.primary.opacity(0.18))
                    .frame(width: 10, height: 10)
            }
        }
    }

    private var current: OnboardingPage {
        pages[currentPage]
    }

    private var previousButtonTitle: String {
        "onboarding.previous".localized
    }

    private var nextButtonTitle: String {
        current == .loginItem ? "onboarding.finish".localized : "onboarding.next".localized
    }

    private func handlePrevious() {
        guard currentPage > 0 else { return }
        currentPage -= 1
    }

    private func handlePrimaryAction() {
        if current == .loginItem {
            launchAtLoginManager.setEnabled(openAtLogin)
            onFinish()
            return
        }

        currentPage += 1
    }
}

private enum OnboardingPage: Int, CaseIterable {
    case welcome
    case control
    case loginItem

    var title: String {
        switch self {
        case .welcome:
            return "onboarding.welcome.title".localized
        case .control:
            return "onboarding.control.title".localized
        case .loginItem:
            return "onboarding.login.title".localized
        }
    }

    var body: String {
        switch self {
        case .welcome:
            return "onboarding.welcome.body".localized
        case .control:
            return "onboarding.control.body".localized
        case .loginItem:
            return "onboarding.login.body".localized
        }
    }

    var calloutTitle: String {
        switch self {
        case .welcome:
            return "onboarding.welcome.callout.title".localized
        case .control:
            return "onboarding.control.callout.title".localized
        case .loginItem:
            return ""
        }
    }

    var calloutBody: String {
        switch self {
        case .welcome:
            return "onboarding.welcome.callout.body".localized
        case .control:
            return "onboarding.control.callout.body".localized
        case .loginItem:
            return ""
        }
    }

    var calloutIcon: String {
        switch self {
        case .welcome:
            return "sparkles"
        case .control:
            return "menubar.rectangle"
        case .loginItem:
            return "power.circle"
        }
    }
}

private struct OnboardingPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(minWidth: 124)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.05, green: 0.78, blue: 0.52),
                                Color(red: 0.00, green: 0.68, blue: 0.78)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
    }
}

private struct OnboardingSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(.primary)
            .frame(minWidth: 108)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.black.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
    }
}
