import SwiftUI

struct NotchCapsuleView: View {
    @EnvironmentObject private var model: NotchViewModel
    @Environment(\.openSettings) private var openSettingsNative
    let openBlackWindow: () -> Void
    let reorganizeBlackWindows: () -> Void
    let restoreBlackWindow: (UUID) -> Void
    let bringBlackWindow: (UUID) -> Void
    let minimizeBlackWindow: (UUID) -> Void
    let closeBlackWindow: (UUID) -> Void
    let toggleAlwaysOnTop: (UUID) -> Void
    let restoreAllWindows: () -> Void
    let minimizeAllWindows: () -> Void
    let closeAllWindows: () -> Void
    let closeAllWindowsOnDisplay: () -> Void
    let requestCloseAllConfirmation: (CGDirectDisplayID) -> Void
    let openSettings: () -> Void
    @State private var hoveredMinimizedItemID: UUID?
    @State private var pendingHoverItemID: UUID?
    @State private var hoverActivationWorkItem: DispatchWorkItem?
    @State private var showExpandedControls = false
    @State private var controlsRevealWorkItem: DispatchWorkItem?
    @State private var hoveredChipID: UUID?
    @State private var isHoveringPlus = false
    @AppStorage("showChipCloseButtonOnHover") private var showChipCloseButtonOnHover = true
    @AppStorage("confirmBeforeCloseAll") private var confirmBeforeCloseAll = true

    private var expandedWidth: CGFloat {
        let minWidth: CGFloat = 680
        let maxWidth: CGFloat = 1100
        return min(max(model.contentWidth + (model.contentPadding * 2), minWidth), maxWidth)
    }
    
    init(
        openBlackWindow: @escaping () -> Void = {},
        reorganizeBlackWindows: @escaping () -> Void = {},
        restoreBlackWindow: @escaping (UUID) -> Void = { _ in },
        bringBlackWindow: @escaping (UUID) -> Void = { _ in },
        minimizeBlackWindow: @escaping (UUID) -> Void = { _ in },
        closeBlackWindow: @escaping (UUID) -> Void = { _ in },
        toggleAlwaysOnTop: @escaping (UUID) -> Void = { _ in },
        restoreAllWindows: @escaping () -> Void = {},
        minimizeAllWindows: @escaping () -> Void = {},
        closeAllWindows: @escaping () -> Void = {},
        closeAllWindowsOnDisplay: @escaping () -> Void = {},
        requestCloseAllConfirmation: @escaping (CGDirectDisplayID) -> Void = { _ in },
        openSettings: @escaping () -> Void = {}
    ) {
        self.openBlackWindow = openBlackWindow
        self.reorganizeBlackWindows = reorganizeBlackWindows
        self.restoreBlackWindow = restoreBlackWindow
        self.bringBlackWindow = bringBlackWindow
        self.minimizeBlackWindow = minimizeBlackWindow
        self.closeBlackWindow = closeBlackWindow
        self.toggleAlwaysOnTop = toggleAlwaysOnTop
        self.restoreAllWindows = restoreAllWindows
        self.minimizeAllWindows = minimizeAllWindows
        self.closeAllWindows = closeAllWindows
        self.closeAllWindowsOnDisplay = closeAllWindowsOnDisplay
        self.requestCloseAllConfirmation = requestCloseAllConfirmation
        self.openSettings = openSettings
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(red: 0, green: 0, blue: 0))
                .opacity(
                    model.hasPhysicalNotch 
                        ? (model.isExpanded ? 1.0 : (model.isHoveringPreview ? 1.0 : 0.0))
                        : 1.0
                )
                .animation(.easeInOut(duration: 0.2), value: model.isHoveringPreview)
            
            if model.auroraBackgroundEnabled && model.isExpanded {
                NotchMetalEffectView(theme: model.auroraTheme)
                    .opacity(0.85) // Allow some black to bleed through
                    .transition(.opacity)
            }

            if model.isExpanded {
                expandedTerminalControls
                    .transition(.opacity)
            }
        }
        .mask(notchBackgroundMaskGroup)
        .contentShape(RoundedRectangle(cornerRadius: notchCornerRadius, style: .continuous))
        .overlay {
            if !model.hasPhysicalNotch && model.fakeNotchGlowEnabled {
                ZStack {
                    // 1. Massive Inner Glow (hacia adentro)
                    // The blur creates a soft glow, but the clipShape perfectly chops off the outside
                    // so it never hits the square bounding box bounds.
                    NotchMetalEffectView(shader: "neonBorderFragment", glowTheme: model.fakeNotchGlowTheme)
                        .mask {
                            RoundedRectangle(cornerRadius: notchCornerRadius, style: .continuous)
                                .stroke(lineWidth: model.isExpanded ? 24 : 16)
                                .blur(radius: model.isExpanded ? 12 : 8)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: notchCornerRadius, style: .continuous))
                        .opacity(0.85)

                    // 2. The sharp neon boundary line with a gentle outward shadow
                    NotchMetalEffectView(shader: "neonBorderFragment", glowTheme: model.fakeNotchGlowTheme)
                        .mask {
                            RoundedRectangle(cornerRadius: notchCornerRadius, style: .continuous)
                                .stroke(lineWidth: model.isExpanded ? 1.8 : 1.2)
                        }
                        .shadow(
                            color: Color(red: 0.72, green: 0.40, blue: 1.00).opacity(model.isExpanded ? 0.9 : 0.7),
                            radius: model.isExpanded ? 10 : 6
                        )
                }
                .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .topLeading) { topLeadingControls }
        .overlay(alignment: .topTrailing) { topTrailingControls }
        .onAppear {
            showExpandedControls = model.isExpanded
        }
        .onChange(of: model.isExpanded) { _, isExpanded in
            controlsRevealWorkItem?.cancel()
            controlsRevealWorkItem = nil

            if isExpanded {
                let workItem = DispatchWorkItem {
                    guard model.isExpanded else { return }
                    withAnimation(.easeOut(duration: 0.15)) {
                        showExpandedControls = true
                    }
                }
                controlsRevealWorkItem = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: workItem)
            } else {
                showExpandedControls = false
                hoveredMinimizedItemID = nil
                pendingHoverItemID = nil
                hoverActivationWorkItem?.cancel()
                hoverActivationWorkItem = nil
                DispatchQueue.main.async {
                    model.isHoveringPreview = false
                    model.isHoveringItem = false
                }
            }
        }
        .onChange(of: hoveredMinimizedItemID) { _, newItemID in
            DispatchQueue.main.async {
                model.isHoveringPreview = (newItemID != nil)
            }
        }
        .onChange(of: pendingHoverItemID) { _, newItemID in
            DispatchQueue.main.async {
                let isHovering = (newItemID != nil || hoveredMinimizedItemID != nil)
                model.isHoveringItem = isHovering
            }
        }
        .frame(
            width: capsuleWidth,
            height: model.isExpanded ? 160 : model.closedSize.height,
            alignment: .top
        )
        .background {
            // Draw the shadow on a decoupled background shape that expressly ignores mouse clicks.
            // This prevents the 42px shadow bounds from stealing clicks from windows below the Notch.
            notchBackgroundMaskGroup
                .shadow(color: .black.opacity(0.12), radius: 3, y: 1.5)
                .allowsHitTesting(false)
        }
        .padding(shadowPadding)
        // Ensure the entire Notch expanding structure is anchored to the top of the NSPanel
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(expansionAnimation, value: model.isExpanded)
    }

    // MARK: - Subviews

    @ViewBuilder
    private func terminalItemButton(for item: TerminalWindowItem) -> some View {
        Button(action: {
            if let event = NSApp.currentEvent {
                if event.modifierFlags.contains(.option) {
                    closeBlackWindow(item.id)
                    return
                }
                
                if event.clickCount == 2 {
                    hoveredMinimizedItemID = nil
                    pendingHoverItemID = nil
                    hoverActivationWorkItem?.cancel()
                    hoverActivationWorkItem = nil
                    bringBlackWindow(item.id)
                    return
                }
            }
            
            hoveredMinimizedItemID = nil
            pendingHoverItemID = nil
            hoverActivationWorkItem?.cancel()
            hoverActivationWorkItem = nil
            restoreBlackWindow(item.id)
        }) {
            ZStack(alignment: .topTrailing) {
                HStack(spacing: 4) {
                    if let icon = item.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 10, height: 10)
                    } else {
                        Image(systemName: "app.fill")
                            .font(.system(size: 10, weight: .bold))
                    }
                    Text("\(item.number)")
                        .font(.system(size: 11, weight: .semibold))
                }
                if showChipCloseButtonOnHover && hoveredChipID == item.id {
                    Button {
                        closeBlackWindow(item.id)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .black))
                            .foregroundStyle(.black)
                            .padding(3)
                            .background(.white, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .offset(x: 8, y: -8)
                    .zIndex(2)
                }
            }
        }
        .buttonStyle(TerminalItemButtonStyle(item: item, pendingHoverItemID: pendingHoverItemID))
        .contextMenu {
            Button("Restore", systemImage: "arrow.up.right.square") {
                restoreBlackWindow(item.id)
            }
            .disabled(!item.isMinimized)
            
            if model.ownDisplayID != item.displayID {
                Button("Move to this Display", systemImage: "macwindow.badge.plus") {
                    bringBlackWindow(item.id)
                }
            }

            Button("Minimize", systemImage: "rectangle.bottomthird.inset.filled") {
                minimizeBlackWindow(item.id)
            }
            .disabled(item.isMinimized)

            Button(item.isAlwaysOnTop ? "Disable Always on Top" : "Always on Top", systemImage: item.isAlwaysOnTop ? "pin.slash" : "pin") {
                toggleAlwaysOnTop(item.id)
            }

            Divider()

            Button("Close", systemImage: "xmark", role: .destructive) {
                closeBlackWindow(item.id)
            }
        }
        .simultaneousGesture(TapGesture(count: 2).onEnded {
            if let event = NSApp.currentEvent, event.modifierFlags.contains(.option) { return }
            hoveredMinimizedItemID = nil
            pendingHoverItemID = nil
            hoverActivationWorkItem?.cancel()
            hoverActivationWorkItem = nil
            bringBlackWindow(item.id)
        })
        .onHover { hovering in
            hoveredChipID = hovering ? item.id : (hoveredChipID == item.id ? nil : hoveredChipID)
            if hovering {
                pendingHoverItemID = item.id
                hoverActivationWorkItem?.cancel()
                let workItem = DispatchWorkItem {
                    if pendingHoverItemID == item.id {
                        hoveredMinimizedItemID = item.id
                    }
                }
                hoverActivationWorkItem = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem)
            } else if hoveredMinimizedItemID == item.id {
                hoveredMinimizedItemID = nil
                pendingHoverItemID = nil
                hoverActivationWorkItem?.cancel()
                hoverActivationWorkItem = nil
            } else if pendingHoverItemID == item.id {
                pendingHoverItemID = nil
                hoverActivationWorkItem?.cancel()
                hoverActivationWorkItem = nil
            }
        }
        .popover(
            isPresented: Binding(
                get: { hoveredMinimizedItemID == item.id },
                set: { showing in
                    hoveredMinimizedItemID = showing ? item.id : nil
                    if !showing {
                        pendingHoverItemID = nil
                        hoverActivationWorkItem?.cancel()
                        hoverActivationWorkItem = nil
                    }
                }
            ),
            attachmentAnchor: .rect(.bounds),
            arrowEdge: .bottom
        ) {
            terminalItemPopover(for: item)
        }
    }

    @ViewBuilder
    private func terminalItemPopover(for item: TerminalWindowItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if let icon = item.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 14, height: 14)
                } else {
                    Image(systemName: "app.fill")
                        .font(.system(size: 12, weight: .semibold))
                }
                Text(item.title)
                    .font(.system(size: 12, weight: .semibold))
            }
            if let preview = item.preview {
                Image(nsImage: preview)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(maxWidth: 360)
                    .clipShape(.rect(cornerRadius: 8))
            } else {
                Text("No preview")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
    }

    private func requestCloseAll() {
        if confirmBeforeCloseAll {
            requestCloseAllConfirmation(model.ownDisplayID)
            return
        }
        closeAllWindows()
    }

    @ViewBuilder
    private var expandedTerminalControls: some View {
        VStack {
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                if model.availableScreens.count > 1 {
                    Button(action: { shiftActiveScreen(delta: -1) }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(model.activeScreenIndex > 0 ? .white.opacity(0.8) : .white.opacity(0.2))
                            .frame(width: 24, height: 28)
                    }
                    .buttonStyle(.plain)
                    .disabled(model.activeScreenIndex == 0)
                }

                expandedScrollContent

                if model.availableScreens.count > 1 {
                    Button(action: { shiftActiveScreen(delta: 1) }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(model.activeScreenIndex < model.availableScreens.count - 1 ? .white.opacity(0.8) : .white.opacity(0.2))
                            .frame(width: 24, height: 28)
                    }
                    .buttonStyle(.plain)
                    .disabled(model.activeScreenIndex == model.availableScreens.count - 1)
                }
            }
            .opacity(showExpandedControls ? 1 : 0)
            .allowsHitTesting(showExpandedControls)
            .padding(.horizontal, model.contentPadding)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .onPreferenceChange(WidthPreferenceKey.self) { width in
                DispatchQueue.main.async {
                    model.contentWidth = width
                }
            }

            Spacer().frame(height: bottomExpandedSpacerHeight)
        }
    }

    private var expandedScrollContent: some View {
        GeometryReader { scrollGeo in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Spacer(minLength: 0)

                    HStack(spacing: 8) {
                        ForEach(model.visibleTerminalItems) { item in
                            terminalItemButton(for: item)
                                .transition(.scale(scale: 0.8).combined(with: .opacity))
                        }

                        if model.activeDisplayID == model.ownDisplayID {
                            Button(action: openBlackWindow) {
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white.opacity(isHoveringPlus ? 1.0 : 0.7))
                                    .frame(width: 28, height: 28)
                                    .background(Color.white.opacity(isHoveringPlus ? 0.25 : 0.1), in: Circle())
                                    .scaleEffect(isHoveringPlus ? 1.1 : 1.0)
                                    .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.6), value: isHoveringPlus)
                            }
                            .buttonStyle(.plain)
                            .help("New Terminal")
                            .onHover { hovering in
                                isHoveringPlus = hovering
                            }
                        }
                    }
                    .padding(.vertical, 12)
                    .background(GeometryReader { innerGeo in
                        Color.clear.preference(key: WidthPreferenceKey.self, value: innerGeo.size.width + 80)
                    })

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .frame(minWidth: scrollGeo.size.width)
                .transaction { transaction in
                    transaction.animation = nil
                }
            }
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: Color(red: 0, green: 0, blue: 0), location: 0.08),
                        .init(color: Color(red: 0, green: 0, blue: 0), location: 0.92),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }
    }

    @ViewBuilder
    private var topLeadingControls: some View {
        if showExpandedControls {
            HStack(spacing: 6) {
                Button(action: reorganizeBlackWindows) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(8)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Reorganize Terminals")

                if !model.terminalItems.isEmpty {
                    Menu {
                        Button("Restore All", systemImage: "arrow.up.right.square") {
                            restoreAllWindows()
                        }
                        Button("Minimize All", systemImage: "rectangle.bottomthird.inset.filled") {
                            minimizeAllWindows()
                        }
                        Divider()
                        Button("Close All on This Display", systemImage: "xmark.square") {
                            closeAllWindowsOnDisplay()
                        }
                        Button("Close All", systemImage: "xmark.circle", role: .destructive) {
                            requestCloseAll()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(.white.opacity(0.8))
                            .padding(8)
                            .contentShape(Circle())
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .tint(.white)
                    .help("Bulk actions")
                }
            }
            .padding(.leading, 10)
            .padding(.top, topControlsPaddingTop)
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private var topTrailingControls: some View {
        if showExpandedControls {
            Button(action: openSettingsWindow) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(8)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 10)
            .padding(.top, topControlsPaddingTop)
            .transition(.opacity)
        }
    }

    private func shiftActiveScreen(delta: Int) {
        let targetIndex = model.activeScreenIndex + delta
        guard targetIndex >= 0, targetIndex < model.availableScreens.count else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            model.activeScreenIndex = targetIndex
        }
    }

    private func openSettingsWindow() {
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows where window.title == "Settings" || window.identifier?.rawValue == "com_apple_SwiftUI_Settings_window" {
            window.makeKeyAndOrderFront(nil)
        }
        if #available(macOS 14.0, *) {
            openSettingsNative()
        } else {
            openSettings()
        }
    }


    // MARK: - Computed Properties



    private var shadowPadding: CGFloat { 42 }

    private var capsuleWidth: CGFloat {
        if model.isExpanded {
            return expandedWidth + (model.hasPhysicalNotch ? 28 : 0)
        }
        return model.closedSize.width + (model.hasPhysicalNotch ? 12 : 0)
    }

    private var notchCornerRadius: CGFloat {
        if model.isExpanded { return 32 }
        return model.hasPhysicalNotch ? 8 : 13
    }

    private var shoulderRadius: CGFloat {
        model.hasPhysicalNotch ? (model.isExpanded ? 14 : 6) : 0
    }

    private var expansionAnimation: Animation {
        .spring(response: 0.35, dampingFraction: 0.82)
    }

    private var topControlsPaddingTop: CGFloat {
        model.hasPhysicalNotch ? 10 : (model.closedSize.height - 24) / 2
    }

    private var bottomExpandedSpacerHeight: CGFloat {
        model.hasPhysicalNotch ? 24 : 30
    }

    @ViewBuilder
    private var notchBackgroundMaskGroup: some View {
        if model.hasPhysicalNotch {
            NotchShape(
                cornerRadius: notchCornerRadius,
                shoulderRadius: shoulderRadius,
                overshoot: 6.0
            )
                .foregroundStyle(Color(red: 0, green: 0, blue: 0).opacity(model.isExpanded || model.isHoveringPreview ? 1.0 : 0.01))
                .animation(.easeInOut(duration: 0.2), value: model.isHoveringPreview)
        } else {
            RoundedRectangle(cornerRadius: notchCornerRadius, style: .continuous)
                .foregroundStyle(Color(red: 0, green: 0, blue: 0))
        }
    }
}

// MARK: - Preference Key

struct WidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Button Style

struct TerminalItemButtonStyle: ButtonStyle {
    let item: TerminalWindowItem
    let pendingHoverItemID: UUID?
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(item.isMinimized ? .white.opacity(0.8) : .white)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                item.isMinimized 
                    ? .white.opacity(configuration.isPressed ? 0.45 : (pendingHoverItemID == item.id ? 0.35 : 0.24))
                    : .white.opacity(configuration.isPressed ? 0.30 : (pendingHoverItemID == item.id ? 0.20 : 0.12)),
                in: Capsule()
            )
            .shadow(color: item.isMinimized ? .clear : .white.opacity(0.4), radius: item.isMinimized ? 0 : 4)
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.88 : 1.0)
            .animation(.interactiveSpring(response: 0.15, dampingFraction: 0.6), value: configuration.isPressed)
            .animation(.interactiveSpring(response: 0.15, dampingFraction: 0.6), value: pendingHoverItemID)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed {
                    NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                }
            }
    }
}

private struct NotchCapsulePreviewHarness: View {
    @StateObject private var model: NotchViewModel

    init(expanded: Bool, physicalNotch: Bool) {
        let previewModel = NotchViewModel()
        previewModel.isExpanded = expanded
        previewModel.hasPhysicalNotch = physicalNotch
        previewModel.contentPadding = 14
        previewModel.fakeNotchGlowEnabled = true
        previewModel.terminalItems = [
            TerminalWindowItem(id: UUID(), number: 1, displayID: 0, title: "NotchTerminal · ~/project", icon: nil, preview: nil, isMinimized: false, isAlwaysOnTop: false),
            TerminalWindowItem(id: UUID(), number: 2, displayID: 0, title: "NotchTerminal · ~/docs", icon: nil, preview: nil, isMinimized: true, isAlwaysOnTop: false)
        ]
        _model = StateObject(wrappedValue: previewModel)
    }

    var body: some View {
        NotchCapsuleView()
            .environmentObject(model)
            .frame(width: 640, height: 210, alignment: .top)
            .background(Color(nsColor: .windowBackgroundColor))
    }
}

#Preview("Notch - Expanded (Fake)") {
    NotchCapsulePreviewHarness(expanded: true, physicalNotch: false)
}

#Preview("Notch - Collapsed (Fake)") {
    NotchCapsulePreviewHarness(expanded: false, physicalNotch: false)
}
