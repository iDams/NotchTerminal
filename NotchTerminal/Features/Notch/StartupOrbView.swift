import SwiftUI

enum StartupOrbStyle {
    case pill
    case physicalNotch
}

enum StartupOrbGeometry {
    static func bubbleSize(for style: StartupOrbStyle) -> CGFloat {
        switch style {
        case .pill:
            return 26
        case .physicalNotch:
            return 24
        }
    }

    static func bubbleIconSize(for style: StartupOrbStyle) -> CGFloat {
        switch style {
        case .pill:
            return 12
        case .physicalNotch:
            return 11
        }
    }

    static func detachedOffsetX(for style: StartupOrbStyle, hostWidth: CGFloat, manualOffset: CGFloat = 0) -> CGFloat {
        let rightEdge = (hostWidth / 2) - 10
        switch style {
        case .pill:
            return rightEdge + 24 + manualOffset
        case .physicalNotch:
            return rightEdge + 58 + manualOffset
        }
    }

    static func attachedOffsetX(for style: StartupOrbStyle, hostWidth: CGFloat, manualOffset: CGFloat = 0) -> CGFloat {
        let rightEdge = (hostWidth / 2) - 10
        switch style {
        case .pill:
            return rightEdge - 18 + manualOffset
        case .physicalNotch:
            // Start further inside the real notch so the orb feels like it emerges from behind it.
            return rightEdge + 1 + manualOffset
        }
    }

    static func offsetY(for style: StartupOrbStyle, manualOffset: CGFloat = 0) -> CGFloat {
        switch style {
        case .pill:
            return 0 + manualOffset
        case .physicalNotch:
            return 8 + manualOffset
        }
    }

    static func detachedFrame(
        alignedTo hostRect: CGRect,
        style: StartupOrbStyle,
        manualOffsetX: CGFloat = 0,
        manualOffsetY: CGFloat = 0
    ) -> CGRect {
        let bubbleSize = bubbleSize(for: style)
        let centerX = hostRect.midX + detachedOffsetX(for: style, hostWidth: hostRect.width, manualOffset: manualOffsetX)
        let originX = centerX - (bubbleSize / 2)
        // SwiftUI anchors this view to the top via .overlay(alignment: .top)
        // In AppKit coordinates, the top of the host is hostRect.maxY.
        // We subtract the bubbleSize so the orb drops down from the top edge.
        // SwiftUI offsetY moves the view DOWN (+ve) or UP (-ve). Since AppKit +Y is UP, we subtract offsetY.
        let originY = hostRect.maxY - bubbleSize - offsetY(for: style, manualOffset: manualOffsetY)
        return CGRect(x: originX, y: originY, width: bubbleSize, height: bubbleSize)
    }

    static func hostRectInPanel(
        panelBounds: CGRect,
        hostWidth: CGFloat,
        hostHeight: CGFloat,
        shadowPadding: CGFloat
    ) -> CGRect {
        CGRect(
            x: (panelBounds.width - hostWidth) / 2,
            y: panelBounds.height - shadowPadding - hostHeight,
            width: hostWidth,
            height: hostHeight
        )
    }

    static func hostRectInPanel(
        panelBounds: CGRect,
        model: NotchViewModel,
        shadowPadding: CGFloat
    ) -> CGRect {
        let contentWidth = model.contentWidth
        let padding = model.contentPadding
        let expandedWidth = min(max(contentWidth + (padding * 2), 680), 1100)
        let hostWidth = model.isExpanded
            ? expandedWidth + (model.hasPhysicalNotch ? 28 : 0)
            : model.closedSize.width + (model.hasPhysicalNotch ? 12 : 0)
        let hostHeight = model.isExpanded ? 160.0 : model.closedSize.height

        return hostRectInPanel(
            panelBounds: panelBounds,
            hostWidth: hostWidth,
            hostHeight: hostHeight,
            shadowPadding: shadowPadding
        )
    }

    static func hostRectOnScreen(
        screenFrame: CGRect,
        hostWidth: CGFloat,
        hostHeight: CGFloat,
        topInset: CGFloat
    ) -> CGRect {
        CGRect(
            x: screenFrame.midX - hostWidth / 2,
            y: screenFrame.maxY - hostHeight - topInset,
            width: hostWidth,
            height: hostHeight
        )
    }
}

struct StartupOrbView: View {
    let style: StartupOrbStyle
    let hostWidth: CGFloat
    let isEligible: Bool
    @AppStorage(AppPreferences.Keys.startupOrbPillOffsetX) private var startupOrbPillOffsetX = AppPreferences.Defaults.startupOrbPillOffsetX
    @AppStorage(AppPreferences.Keys.startupOrbPillOffsetY) private var startupOrbPillOffsetY = AppPreferences.Defaults.startupOrbPillOffsetY
    @AppStorage(AppPreferences.Keys.startupOrbNotchOffsetX) private var startupOrbNotchOffsetX = AppPreferences.Defaults.startupOrbNotchOffsetX
    @AppStorage(AppPreferences.Keys.startupOrbNotchOffsetY) private var startupOrbNotchOffsetY = AppPreferences.Defaults.startupOrbNotchOffsetY

    @State private var showOrb = false
    @State private var isDetached = false
    @State private var hasSettled = false
    @State private var hasPlayedInitialAnimation = false
    @State private var playbackGeneration = 0
    @State private var hasScheduledInitialStartupPlayback = false

    var body: some View {
        Group {
            if showOrb && isEligible {
                orbBubble
                .offset(x: orbOffsetX, y: orbOffsetY)
                .scaleEffect(x: orbScaleX, y: orbScaleY, anchor: .center)
                .opacity(orbOpacity)
                .blur(radius: isDetached ? 0 : 0.6)
                .transition(.identity)
            }
        }
        .onAppear {
            guard isEligible, !hasScheduledInitialStartupPlayback else { return }
            hasScheduledInitialStartupPlayback = true
            let generation = playbackGeneration
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                guard generation == playbackGeneration, isEligible else { return }
                playIfNeeded()
            }
        }
        .onChange(of: isEligible) { _, eligible in
            if eligible {
                if hasScheduledInitialStartupPlayback {
                    playIfNeeded()
                } else {
                    hasScheduledInitialStartupPlayback = true
                    let generation = playbackGeneration
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                        guard generation == playbackGeneration, isEligible else { return }
                        playIfNeeded()
                    }
                }
            } else {
                resetPlayback()
            }
        }
    }

    private var orbBubble: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.98))

            Circle()
                .stroke(.white.opacity(isDetached ? 0.16 : 0.08), lineWidth: 1)

            Image("AppLogo")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: bubbleIconSize, height: bubbleIconSize)
        }
        .frame(width: bubbleSize, height: bubbleSize)
        .shadow(color: .black.opacity(0.20), radius: 6, y: 2)
    }

    private var bubbleSize: CGFloat {
        StartupOrbGeometry.bubbleSize(for: style)
    }

    private var bubbleIconSize: CGFloat {
        StartupOrbGeometry.bubbleIconSize(for: style)
    }

    private var orbOffsetX: CGFloat {
        if isDetached {
            return StartupOrbGeometry.detachedOffsetX(for: style, hostWidth: hostWidth, manualOffset: currentManualOffsetX)
        }
        return StartupOrbGeometry.attachedOffsetX(for: style, hostWidth: hostWidth, manualOffset: currentManualOffsetX)
    }

    private var orbOffsetY: CGFloat {
        StartupOrbGeometry.offsetY(for: style, manualOffset: currentManualOffsetY)
    }

    private var currentManualOffsetX: CGFloat {
        switch style {
        case .pill:
            return startupOrbPillOffsetX
        case .physicalNotch:
            return startupOrbNotchOffsetX
        }
    }

    private var currentManualOffsetY: CGFloat {
        switch style {
        case .pill:
            return startupOrbPillOffsetY
        case .physicalNotch:
            return startupOrbNotchOffsetY
        }
    }

    private var orbScaleX: CGFloat {
        isDetached ? 1.0 : 1.45
    }

    private var orbScaleY: CGFloat {
        isDetached ? 1.0 : 0.76
    }

    private var orbOpacity: Double {
        hasSettled ? 1 : 1
    }

    private func playIfNeeded() {
        guard isEligible else { return }
        guard !(showOrb && hasPlayedInitialAnimation && !hasSettled) else { return }

        if !hasPlayedInitialAnimation {
            playbackGeneration += 1
            let generation = playbackGeneration
            hasPlayedInitialAnimation = true
            showOrb = true
            isDetached = false
            hasSettled = false

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                guard generation == playbackGeneration, isEligible else { return }
                withAnimation(.spring(response: 0.44, dampingFraction: 0.74, blendDuration: 0.08)) {
                    isDetached = true
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                guard generation == playbackGeneration, isEligible else { return }
                withAnimation(.easeOut(duration: 0.18)) {
                    hasSettled = true
                }
            }
            return
        }

        showOrb = true
        isDetached = true
        hasSettled = true
    }

    private func resetPlayback() {
        playbackGeneration += 1
        showOrb = false
        isDetached = false
        hasSettled = false
        hasPlayedInitialAnimation = false
        hasScheduledInitialStartupPlayback = false
    }
}
