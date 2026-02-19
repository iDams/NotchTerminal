import SwiftUI

struct NotchCapsuleView: View {
    @EnvironmentObject private var model: NotchViewModel
    let openBlackWindow: () -> Void
    let reorganizeBlackWindows: () -> Void
    let restoreBlackWindow: (UUID) -> Void
    @State private var hoveredMinimizedItemID: UUID?
    @State private var pendingHoverItemID: UUID?
    @State private var hoverActivationWorkItem: DispatchWorkItem?
    @State private var showExpandedControls = false
    @State private var controlsRevealWorkItem: DispatchWorkItem?

    init(
        openBlackWindow: @escaping () -> Void = {},
        reorganizeBlackWindows: @escaping () -> Void = {},
        restoreBlackWindow: @escaping (UUID) -> Void = { _ in }
    ) {
        self.openBlackWindow = openBlackWindow
        self.reorganizeBlackWindows = reorganizeBlackWindows
        self.restoreBlackWindow = restoreBlackWindow
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(red: 0, green: 0, blue: 0))
                .opacity(model.hasPhysicalNotch ? (model.isExpanded ? 1.0 : 0.0) : 1.0)

            if model.isExpanded {
                VStack {
                    Spacer(minLength: 0)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            Button(action: openBlackWindow) {
                                Label("New", systemImage: "plus")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(.white.opacity(0.14), in: Capsule())
                            }
                            .buttonStyle(.plain)

                            Button(action: reorganizeBlackWindows) {
                                Label("Reorg", systemImage: "square.grid.2x2")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(.white.opacity(0.14), in: Capsule())
                            }
                            .buttonStyle(.plain)

                            ForEach(model.minimizedItems) { item in
                                minimizedItemButton(for: item)
                            }
                        }
                        .transaction { transaction in
                            transaction.animation = nil
                        }
                        .opacity(showExpandedControls ? 1 : 0)
                        .allowsHitTesting(showExpandedControls)
                        .padding(.horizontal, model.contentPadding)
                        .background(GeometryReader { geo in
                            Color.clear.preference(key: WidthPreferenceKey.self, value: geo.size.width)
                        })
                    }
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: Color(red: 0, green: 0, blue: 0), location: 0.05),
                                .init(color: Color(red: 0, green: 0, blue: 0), location: 0.95),
                                .init(color: .clear, location: 1)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .onPreferenceChange(WidthPreferenceKey.self) { width in
                        DispatchQueue.main.async {
                            model.contentWidth = width
                        }
                    }
                    if model.hasPhysicalNotch {
                        Spacer().frame(height: 8)
                    } else {
                        Spacer(minLength: 0)
                    }
                }
                .transition(.opacity)
            }
        }
        .mask(notchBackgroundMaskGroup)
        .overlay {
            if !model.hasPhysicalNotch && model.fakeNotchGlowEnabled {
                RoundedRectangle(cornerRadius: notchCornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(red: 0.92, green: 0.72, blue: 1.00).opacity(model.isExpanded ? 0.95 : 0.78),
                                Color(red: 0.74, green: 0.46, blue: 1.00).opacity(model.isExpanded ? 0.85 : 0.70)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: model.isExpanded ? 1.3 : 1.0
                    )
                    .shadow(
                        color: Color(red: 0.72, green: 0.40, blue: 1.00).opacity(model.isExpanded ? 0.55 : 0.40),
                        radius: model.isExpanded ? 20 : 13
                    )
                    .shadow(
                        color: Color(red: 0.42, green: 0.24, blue: 0.95).opacity(model.isExpanded ? 0.40 : 0.28),
                        radius: model.isExpanded ? 40 : 24
                    )
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .topTrailing) {
            if showExpandedControls {
                SettingsLink {
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
        .shadow(color: .black.opacity(0.12), radius: 3, y: 1.5)
        .padding(shadowPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: model.isExpanded)
    }

    // MARK: - Subviews

    @ViewBuilder
    private func minimizedItemButton(for item: MinimizedWindowItem) -> some View {
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
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(.white.opacity(0.12), in: Capsule())
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
            minimizedItemPopover(for: item)
        }
    }

    @ViewBuilder
    private func minimizedItemPopover(for item: MinimizedWindowItem) -> some View {
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
                    .scaledToFill()
                    .frame(width: 360, height: 210)
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

    private var shadowPadding: CGFloat { 16 }

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
