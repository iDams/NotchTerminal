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

    static func detachedOffsetX(for style: StartupOrbStyle, hostWidth: CGFloat) -> CGFloat {
        let rightEdge = (hostWidth / 2) - 10
        switch style {
        case .pill:
            return rightEdge + 24
        case .physicalNotch:
            return rightEdge + 18
        }
    }

    static func attachedOffsetX(for style: StartupOrbStyle, hostWidth: CGFloat) -> CGFloat {
        let rightEdge = (hostWidth / 2) - 10
        switch style {
        case .pill:
            return rightEdge - 18
        case .physicalNotch:
            return rightEdge - 14
        }
    }

    static func offsetY(for style: StartupOrbStyle) -> CGFloat {
        switch style {
        case .pill:
            return 0
        case .physicalNotch:
            return -2
        }
    }

    static func detachedFrame(alignedTo hostRect: CGRect, style: StartupOrbStyle) -> CGRect {
        let bubbleSize = bubbleSize(for: style)
        let centerX = hostRect.midX + detachedOffsetX(for: style, hostWidth: hostRect.width)
        let originX = centerX - (bubbleSize / 2)
        // SwiftUI anchors this view to the top via .overlay(alignment: .top)
        // In AppKit coordinates, the top of the host is hostRect.maxY.
        // We subtract the bubbleSize so the orb drops down from the top edge.
        // SwiftUI offsetY moves the view DOWN (+ve) or UP (-ve). Since AppKit +Y is UP, we subtract offsetY.
        let originY = hostRect.maxY - bubbleSize - offsetY(for: style)
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

    @State private var showOrb = false
    @State private var isDetached = false
    @State private var hasSettled = false
    @State private var hasPlayedInitialAnimation = false

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
        .task(id: isEligible) {
            if isEligible {
                playIfNeeded()
            }
        }
        .onChange(of: isEligible) { _, eligible in
            if eligible {
                playIfNeeded()
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
            return StartupOrbGeometry.detachedOffsetX(for: style, hostWidth: hostWidth)
        }
        return StartupOrbGeometry.attachedOffsetX(for: style, hostWidth: hostWidth)
    }

    private var orbOffsetY: CGFloat {
        StartupOrbGeometry.offsetY(for: style)
    }

    private var orbScaleX: CGFloat {
        isDetached ? 1.0 : 1.9
    }

    private var orbScaleY: CGFloat {
        isDetached ? 1.0 : 0.54
    }

    private var orbOpacity: Double {
        hasSettled ? 1 : 1
    }

    private func playIfNeeded() {
        guard isEligible else { return }
        guard !(showOrb && hasPlayedInitialAnimation && !hasSettled) else { return }

        if !hasPlayedInitialAnimation {
            hasPlayedInitialAnimation = true
            showOrb = true
            isDetached = false
            hasSettled = false

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                withAnimation(.interactiveSpring(response: 0.38, dampingFraction: 0.62)) {
                    isDetached = true
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
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
}
