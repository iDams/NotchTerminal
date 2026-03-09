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

    static func commandDetachedOffsetX(for style: StartupOrbStyle, hostWidth: CGFloat, manualOffset: CGFloat = 0) -> CGFloat {
        switch style {
        case .pill:
            return detachedOffsetX(for: style, hostWidth: hostWidth, manualOffset: manualOffset)
        case .physicalNotch:
            return detachedOffsetX(for: style, hostWidth: hostWidth, manualOffset: manualOffset + 10)
        }
    }

    static func commandAttachedOffsetX(for style: StartupOrbStyle, hostWidth: CGFloat, manualOffset: CGFloat = 0) -> CGFloat {
        switch style {
        case .pill:
            return attachedOffsetX(for: style, hostWidth: hostWidth, manualOffset: manualOffset)
        case .physicalNotch:
            return attachedOffsetX(for: style, hostWidth: hostWidth, manualOffset: manualOffset + 8)
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
    let event: TerminalCommandOrbEvent?
    let isEligible: Bool
    let showsStartupPreview: Bool
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
    @State private var showCommandOrb = false
    @State private var commandOrbDetached = false
    @State private var currentCommandEventID: UUID?
    @State private var displayedCommandEvent: TerminalCommandOrbEvent?
    @State private var commandOrbHideGeneration = 0
    @State private var commandOrbOpacity = 1.0

    var body: some View {
        Group {
            if showCommandOrb && isEligible, let displayedCommandEvent {
                commandOrbBubble(for: displayedCommandEvent)
                .offset(x: commandOrbOffsetX, y: commandOrbOffsetY)
                .scaleEffect(x: commandOrbScaleX, y: commandOrbScaleY, anchor: .center)
                .opacity(commandOrbOpacity)
                .blur(radius: commandOrbDetached ? 0 : 0.6)
                .transition(.identity)
            } else if showOrb && isEligible {
                orbBubble
                .offset(x: orbOffsetX, y: orbOffsetY)
                .scaleEffect(x: orbScaleX, y: orbScaleY, anchor: .center)
                .opacity(orbOpacity)
                .blur(radius: isDetached ? 0 : 0.6)
                .transition(.identity)
            }
        }
        .onAppear {
            guard showsStartupPreview else { return }
            guard isEligible, !hasScheduledInitialStartupPlayback else { return }
            hasScheduledInitialStartupPlayback = true
            let generation = playbackGeneration
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                guard generation == playbackGeneration, isEligible else { return }
                playIfNeeded()
            }
        }
        .onChange(of: isEligible) { _, eligible in
            guard showsStartupPreview else {
                resetPlayback()
                return
            }
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
        .onChange(of: event?.id) { _, newValue in
            guard newValue != currentCommandEventID else { return }
            currentCommandEventID = newValue
            if let event {
                displayedCommandEvent = event
            }
            syncCommandOrbVisibility(playAnimation: true)
        }
        .onChange(of: showsStartupPreview) { _, shouldShow in
            if shouldShow {
                playIfNeeded()
            } else if event == nil {
                hideStartupPreview()
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

    private var commandOrbOffsetX: CGFloat {
        if commandOrbDetached {
            return StartupOrbGeometry.commandDetachedOffsetX(for: style, hostWidth: hostWidth, manualOffset: currentManualOffsetX)
        }
        return StartupOrbGeometry.commandAttachedOffsetX(for: style, hostWidth: hostWidth, manualOffset: currentManualOffsetX)
    }

    private var commandOrbOffsetY: CGFloat {
        StartupOrbGeometry.offsetY(for: style, manualOffset: currentManualOffsetY)
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

    private var commandOrbScaleX: CGFloat {
        commandOrbDetached ? 1.0 : 1.38
    }

    private var commandOrbScaleY: CGFloat {
        commandOrbDetached ? 1.0 : 0.8
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
        commandOrbHideGeneration += 1
        showOrb = false
        isDetached = false
        hasSettled = false
        hasPlayedInitialAnimation = false
        hasScheduledInitialStartupPlayback = false
        showCommandOrb = false
        commandOrbDetached = false
        commandOrbOpacity = 1.0
        displayedCommandEvent = nil
        currentCommandEventID = nil
    }

    private func hideStartupPreview() {
        guard showOrb else {
            resetPlayback()
            return
        }

        playbackGeneration += 1
        let generation = playbackGeneration
        withAnimation(.spring(response: 0.36, dampingFraction: 0.82, blendDuration: 0.05)) {
            isDetached = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            guard generation == playbackGeneration else { return }
            withAnimation(.easeOut(duration: 0.10)) {
                showOrb = false
            }
            hasSettled = false
            hasPlayedInitialAnimation = false
            hasScheduledInitialStartupPlayback = false
        }
    }

    private func syncCommandOrbVisibility(playAnimation: Bool = false) {
        guard isEligible, event != nil else {
            guard showCommandOrb else {
                commandOrbDetached = false
                commandOrbOpacity = 1.0
                return
            }
            commandOrbHideGeneration += 1
            let hideGeneration = commandOrbHideGeneration
            withAnimation(.spring(response: 0.36, dampingFraction: 0.82, blendDuration: 0.05)) {
                commandOrbDetached = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                guard hideGeneration == commandOrbHideGeneration else { return }
                withAnimation(.easeOut(duration: 0.10)) {
                    commandOrbOpacity = 0.0
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                guard hideGeneration == commandOrbHideGeneration else { return }
                showCommandOrb = false
                commandOrbOpacity = 1.0
                displayedCommandEvent = nil
            }
            return
        }

        commandOrbHideGeneration += 1
        showOrb = false
        showCommandOrb = true
        commandOrbOpacity = 1.0
        displayedCommandEvent = event
        guard playAnimation else {
            commandOrbDetached = true
            return
        }

        commandOrbDetached = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.76, blendDuration: 0.06)) {
                commandOrbDetached = true
            }
        }
    }

    private func commandOrbBubble(for event: TerminalCommandOrbEvent) -> some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.98))

            Circle()
                .stroke(borderColor(for: event), lineWidth: 1)

            orbIcon(for: event.kind)

        }
        .frame(width: bubbleSize, height: bubbleSize)
        .overlay(alignment: .topLeading) {
            Text("\(event.terminalNumber)")
                .font(.system(size: 8, weight: .black, design: .rounded))
                .foregroundStyle(.black)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(.white, in: Capsule())
                .offset(x: -6, y: -6)
        }
        .shadow(color: glowColor(for: event).opacity(0.3), radius: 8, y: 2)
        .shadow(color: .black.opacity(0.20), radius: 6, y: 2)
    }

    @ViewBuilder
    private func orbIcon(for kind: TerminalCommandOrbKind) -> some View {
        if kind == .package {
            Image("OrbNPM")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: bubbleIconSize + 5, height: bubbleIconSize + 5)
        } else if kind == .git {
            Image("OrbGit")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: bubbleIconSize + 5, height: bubbleIconSize + 5)
        } else {
            Image(systemName: symbolName(for: kind))
                .font(.system(size: bubbleIconSize, weight: .bold))
                .foregroundStyle(.white.opacity(0.94))
        }
    }

    private func symbolName(for kind: TerminalCommandOrbKind) -> String {
        switch kind {
        case .build:
            return "hammer.fill"
        case .test:
            return "checklist"
        case .download:
            return "arrow.down.circle.fill"
        case .package, .git, .generic:
            return "terminal.fill"
        }
    }

    private func borderColor(for kindEvent: TerminalCommandOrbEvent) -> Color {
        switch kindEvent.status {
        case .success:
            return Color.green.opacity(0.75)
        case .error:
            return Color.red.opacity(0.78)
        case .running:
            break
        }

        switch kindEvent.kind {
        case .package:
            return Color.blue.opacity(0.55)
        case .git:
            return Color.mint.opacity(0.55)
        case .build:
            return Color.orange.opacity(0.55)
        case .test:
            return Color.green.opacity(0.55)
        case .download:
            return Color.cyan.opacity(0.55)
        case .generic:
            return .white.opacity(commandOrbDetached ? 0.18 : 0.1)
        }
    }

    private func glowColor(for kindEvent: TerminalCommandOrbEvent) -> Color {
        switch kindEvent.status {
        case .success:
            return .green
        case .error:
            return .red
        case .running:
            break
        }

        switch kindEvent.kind {
        case .package:
            return .blue
        case .git:
            return .mint
        case .build:
            return .orange
        case .test:
            return .green
        case .download:
            return .cyan
        case .generic:
            return .black
        }
    }
}
