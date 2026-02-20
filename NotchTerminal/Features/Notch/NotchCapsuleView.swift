import SwiftUI

struct NotchCapsuleView: View {
    @EnvironmentObject private var model: NotchViewModel
    @Environment(\.openSettings) private var openSettingsNative
    let openBlackWindow: () -> Void
    let reorganizeBlackWindows: () -> Void
    let restoreBlackWindow: (UUID) -> Void
    let openSettings: () -> Void
    @State private var hoveredMinimizedItemID: UUID?
    @State private var pendingHoverItemID: UUID?
    @State private var hoverActivationWorkItem: DispatchWorkItem?
    @State private var showExpandedControls = false
    @State private var controlsRevealWorkItem: DispatchWorkItem?
    


    init(
        openBlackWindow: @escaping () -> Void = {},
        reorganizeBlackWindows: @escaping () -> Void = {},
        restoreBlackWindow: @escaping (UUID) -> Void = { _ in },
        openSettings: @escaping () -> Void = {}
    ) {
        self.openBlackWindow = openBlackWindow
        self.reorganizeBlackWindows = reorganizeBlackWindows
        self.restoreBlackWindow = restoreBlackWindow
        self.openSettings = openSettings
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(red: 0, green: 0, blue: 0))
                .opacity(model.hasPhysicalNotch ? (model.isExpanded ? 1.0 : 0.0) : 1.0)
            
            if model.auroraBackgroundEnabled && model.isExpanded {
                NotchMetalEffectView()
                    .opacity(0.85) // Allow some black to bleed through
                    .transition(.opacity)
            }

            if model.isExpanded {
                VStack {
                    Spacer(minLength: 0)
                    HStack(spacing: 12) {
                        GeometryReader { scrollGeo in
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    Spacer(minLength: 0) // Flexible spacer to push items to center

                                    // Inner HStack: terminal items + the "New" button together
                                    HStack(spacing: 8) {
                                        ForEach(model.terminalItems) { item in
                                            terminalItemButton(for: item)
                                        }

                                        // "+" button right next to the last terminal
                                        Button(action: openBlackWindow) {
                                            Image(systemName: "plus")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundStyle(.white.opacity(0.7))
                                                .frame(width: 28, height: 28)
                                                .background(Color.white.opacity(0.1), in: Circle())
                                        }
                                        .buttonStyle(.plain)
                                        .help("New Terminal")
                                    }
                                    .background(GeometryReader { innerGeo in
                                        // The extra 80 accounts for the padding and spaces around the ScrollView
                                        Color.clear.preference(key: WidthPreferenceKey.self, value: innerGeo.size.width + 80)
                                    })

                                    Spacer(minLength: 0) // Flexible spacer to push items to center
                                }
                                // Force the internal HStack to fill the ScrollView so the Spacers work correctly
                                .frame(minWidth: scrollGeo.size.width)
                                .padding(.horizontal, 16) // Extra padding to keep items away from the fading edges
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
                    if model.hasPhysicalNotch {
                        Spacer().frame(height: 20)
                    } else {
                        Spacer().frame(height: 26)
                    }
                }
                .transition(.opacity)
            }
        }
        .mask(notchBackgroundMaskGroup)
        .overlay {
            if !model.hasPhysicalNotch && model.fakeNotchGlowEnabled {
                // The neon shader sweeping effect
                NotchMetalEffectView(shader: "neonBorderFragment")
                    .mask {
                        RoundedRectangle(cornerRadius: notchCornerRadius, style: .continuous)
                            .stroke(lineWidth: model.isExpanded ? 1.5 : 1.0)
                    }
                    .shadow(
                        color: Color(red: 0.72, green: 0.40, blue: 1.00).opacity(model.isExpanded ? 0.65 : 0.45),
                        radius: model.isExpanded ? 20 : 13
                    )
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .topTrailing) {
            if showExpandedControls {
                Button(action: {
                    if #available(macOS 14.0, *) {
                        openSettingsNative()
                    } else {
                        openSettings()
                    }
                }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(8)
                        .contentShape(Circle())
                        .transaction { transaction in
                            transaction.animation = nil
                        }
                }
                .buttonStyle(.plain)
                .padding(.trailing, 10)
                .padding(.top, model.hasPhysicalNotch ? 0 : 4)
                .transition(.opacity)
            }
        }
        .overlay(alignment: .topLeading) {
            if showExpandedControls {
                Button(action: reorganizeBlackWindows) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(8)
                        .contentShape(Circle())
                        .transaction { transaction in
                            transaction.animation = nil
                        }
                }
                .buttonStyle(.plain)
                .help("Reorganize Terminals")
                .padding(.leading, 10)
                .padding(.top, model.hasPhysicalNotch ? 0 : 4)
                .transition(.opacity)
            }
        }
        .onAppear {
            showExpandedControls = model.isExpanded
        }
        .onChange(of: model.isExpanded) { _, isExpanded in
            controlsRevealWorkItem?.cancel()
            controlsRevealWorkItem = nil

            if isExpanded {
                let workItem = DispatchWorkItem {
                    guard model.isExpanded else { return }
                    withAnimation(.easeOut(duration: 0.12)) {
                        showExpandedControls = true
                    }
                }
                controlsRevealWorkItem = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: workItem)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .shadow(color: .black.opacity(0.12), radius: 3, y: 1.5)
        .padding(shadowPadding)
        // Ensure the entire Notch expanding structure is anchored to the top of the NSPanel
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: model.isExpanded)
    }

    // MARK: - Subviews

    @ViewBuilder
    private func terminalItemButton(for item: TerminalWindowItem) -> some View {
        Button(action: {
            hoveredMinimizedItemID = nil
            pendingHoverItemID = nil
            hoverActivationWorkItem?.cancel()
            hoverActivationWorkItem = nil
            restoreBlackWindow(item.id)
        }) {
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
            .foregroundStyle(item.isMinimized ? .white.opacity(0.8) : .white)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(item.isMinimized ? .white.opacity(0.12) : .white.opacity(0.24), in: Capsule())
            .shadow(color: item.isMinimized ? .clear : .white.opacity(0.4), radius: item.isMinimized ? 0 : 4)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
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

    // MARK: - Computed Properties



    private var shadowPadding: CGFloat { 42 }

    private var notchCornerRadius: CGFloat {
        if model.isExpanded { return 32 }
        return model.hasPhysicalNotch ? 8 : 13
    }

    private var shoulderRadius: CGFloat {
        model.hasPhysicalNotch ? (model.isExpanded ? 14 : 6) : 0
    }

    @ViewBuilder
    private var notchBackgroundMaskGroup: some View {
        if model.hasPhysicalNotch {
            NotchShape(
                cornerRadius: notchCornerRadius,
                shoulderRadius: shoulderRadius,
                overshoot: (model.isExpanded && model.hasPhysicalNotch) ? 2.0 : 0.0
            )
                .foregroundStyle(Color(red: 0, green: 0, blue: 0))
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

private struct NotchCapsulePreviewHarness: View {
    @StateObject private var model: NotchViewModel

    init(expanded: Bool, physicalNotch: Bool) {
        let previewModel = NotchViewModel()
        previewModel.isExpanded = expanded
        previewModel.hasPhysicalNotch = physicalNotch
        previewModel.contentPadding = 14
        previewModel.fakeNotchGlowEnabled = true
        previewModel.terminalItems = [
            TerminalWindowItem(id: UUID(), number: 1, displayID: 0, title: "NotchTerminal · ~/project", icon: nil, preview: nil, isMinimized: false),
            TerminalWindowItem(id: UUID(), number: 2, displayID: 0, title: "NotchTerminal · ~/docs", icon: nil, preview: nil, isMinimized: true)
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
