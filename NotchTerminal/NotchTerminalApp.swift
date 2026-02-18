import SwiftUI
import AppKit
import QuartzCore
import MetalKit
import Combine

@main
struct NotchTerminalApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var notchController: NotchOverlayController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        notchController = NotchOverlayController()
        notchController?.start()
    }
}

@MainActor
final class NotchOverlayController {
    private let collapsedNoNotchSize = NSSize(width: 126, height: 26)
    private let expandedSize = NSSize(width: 336, height: 78)
    private let notchClosedWidthScale: CGFloat = 0.92
    private let notchClosedHeightScale: CGFloat = 0.90
    private let shadowPadding: CGFloat = 16
    private let noNotchTopInset: CGFloat = 6
    private let notchTopInset: CGFloat = 0

    private var panelsByDisplay: [CGDirectDisplayID: NSPanel] = [:]
    private var hostsByDisplay: [CGDirectDisplayID: NSHostingView<AnyView>] = [:]
    private var modelsByDisplay: [CGDirectDisplayID: NotchViewModel] = [:]
    private let blackWindowController = MetalBlackWindowsManager()
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var lastCursorLocation: CGPoint?
    private var cancellables = Set<AnyCancellable>()

    func start() {
        blackWindowController.onMinimizedItemsChanged = { [weak self] items in
            self?.applyMinimizedItems(items)
        }
        rebuildPanels()
        startMouseTracking()
        registerObservers()
    }

    private func startMouseTracking() {
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                self?.updateExpansionAndLayout()
            }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func registerObservers() {
        let center = NotificationCenter.default
        let names: [Notification.Name] = [
            NSApplication.didChangeScreenParametersNotification,
            NSWindow.didChangeScreenNotification
        ]

        for name in names {
            let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                DispatchQueue.main.async { [weak self] in
                    self?.rebuildPanels()
                }
            }
            observers.append(token)
        }
    }

    private func rebuildPanels() {
        let screens = NSScreen.screens
        let displayIDs = Set(screens.compactMap(displayID(for:)))

        for (displayID, panel) in panelsByDisplay where !displayIDs.contains(displayID) {
            panel.orderOut(nil)
            panelsByDisplay.removeValue(forKey: displayID)
            hostsByDisplay.removeValue(forKey: displayID)
            modelsByDisplay.removeValue(forKey: displayID)
        }

        for screen in screens {
            guard let displayID = displayID(for: screen) else { continue }
            let hasNotch = detectNotch(on: screen)
            let model = modelsByDisplay[displayID] ?? NotchViewModel()
            model.hasPhysicalNotch = hasNotch
            modelsByDisplay[displayID] = model

            if panelsByDisplay[displayID] == nil {
                let panel = makePanel(model: model, displayID: displayID)
                panelsByDisplay[displayID] = panel
                hostsByDisplay[displayID] = panel.contentView as? NSHostingView<AnyView>

                model.$contentWidth
                    .removeDuplicates()
                    .debounce(for: .milliseconds(50), scheduler: RunLoop.main)
                    .sink { [weak self] _ in
                        self?.layoutPanels(animated: true, displays: [displayID])
                    }
                    .store(in: &cancellables)
            } else {
                hostsByDisplay[displayID]?.rootView = AnyView(
                    NotchCapsuleView(
                        openBlackWindow: { [weak self] in
                            self?.openBlackWindow(for: displayID)
                        },
                        reorganizeBlackWindows: { [weak self] in
                            self?.reorganizeBlackWindows(for: displayID)
                        },
                        restoreBlackWindow: { [weak self] windowID in
                            self?.blackWindowController.restoreWindow(id: windowID)
                        }
                    )
                        .environmentObject(model)
                )
            }
        }

        layoutPanels(animated: false)
    }

    private func makePanel(model: NotchViewModel, displayID: CGDirectDisplayID) -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.contentView = NSHostingView(
            rootView: AnyView(
                NotchCapsuleView(
                    openBlackWindow: { [weak self] in
                        self?.openBlackWindow(for: displayID)
                    },
                    reorganizeBlackWindows: { [weak self] in
                        self?.reorganizeBlackWindows(for: displayID)
                    },
                    restoreBlackWindow: { [weak self] windowID in
                        self?.blackWindowController.restoreWindow(id: windowID)
                    }
                )
                    .environmentObject(model)
            )
        )
        panel.orderFrontRegardless()
        return panel
    }

    private func updateExpansionAndLayout() {
        let cursor = NSEvent.mouseLocation
        if let lastCursorLocation {
            let dx = cursor.x - lastCursorLocation.x
            let dy = cursor.y - lastCursorLocation.y
            if (dx * dx + dy * dy) < 0.25 { return }
        }
        lastCursorLocation = cursor
        var changedDisplays: Set<CGDirectDisplayID> = []

        for screen in NSScreen.screens {
            guard let displayID = displayID(for: screen),
                  let model = modelsByDisplay[displayID] else { continue }

            let activationRect = notchActivationRect(for: screen, hasNotch: model.hasPhysicalNotch)
            let shouldExpand = activationRect.contains(cursor)
            if shouldExpand != model.isExpanded {
                model.isExpanded = shouldExpand
                changedDisplays.insert(displayID)
            }
        }

        if !changedDisplays.isEmpty {
            layoutPanels(animated: true, displays: changedDisplays)
        }
    }

    private func layoutPanels(animated: Bool, displays: Set<CGDirectDisplayID>? = nil) {
        for screen in NSScreen.screens {
            guard let displayID = displayID(for: screen),
                  let panel = panelsByDisplay[displayID],
                  let model = modelsByDisplay[displayID] else { continue }

            if let displays, !displays.contains(displayID) { continue }
            let frame = frameForPanel(on: screen, hasNotch: model.hasPhysicalNotch, isExpanded: model.isExpanded, contentWidth: model.contentWidth)
            panel.ignoresMouseEvents = !model.isExpanded

            if animated {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = model.isExpanded ? 0.25 : 0.20
                    context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    panel.animator().setFrame(frame, display: true)
                }
            } else {
                panel.setFrame(frame, display: true)
            }
        }
    }

    private func frameForPanel(on screen: NSScreen, hasNotch: Bool, isExpanded: Bool, contentWidth: CGFloat) -> CGRect {
        let closedSize: NSSize = {
            guard hasNotch else { return collapsedNoNotchSize }
            let raw = screen.notchSizeOrFallback(fallback: collapsedNoNotchSize)
            return NSSize(
                width: max(92, raw.width * notchClosedWidthScale),
                height: max(22, raw.height * notchClosedHeightScale)
            )
        }()
        
        let visualSize: NSSize
        if isExpanded {
            let minWidth: CGFloat = 336
            let maxWidth: CGFloat = 800
            let targetWidth = min(max(contentWidth + 40, minWidth), maxWidth)
            visualSize = NSSize(width: targetWidth, height: 78)
        } else {
            visualSize = closedSize
        }
        let shoulderExtra: CGFloat = hasNotch ? (isExpanded ? 14 : 6) * 2 : 0
        let panelSize = NSSize(width: visualSize.width + shoulderExtra + (shadowPadding * 2), height: visualSize.height + (shadowPadding * 2))
        let topInset = hasNotch ? notchTopInset : noNotchTopInset

        let visualOrigin = CGPoint(
            x: screen.frame.midX - (visualSize.width + shoulderExtra) / 2.0,
            y: screen.frame.maxY - visualSize.height - topInset
        )

        return CGRect(
            x: visualOrigin.x - shadowPadding,
            y: visualOrigin.y - shadowPadding,
            width: panelSize.width,
            height: panelSize.height
        )
    }

    private func notchActivationRect(for screen: NSScreen, hasNotch: Bool) -> CGRect {
        let notchRect = hardwareNotchRect(for: screen)
        if hasNotch && notchRect != .zero {
            return notchRect.insetBy(dx: -95, dy: -60)
        }

        let virtual = CGRect(
            x: screen.frame.midX - collapsedNoNotchSize.width / 2,
            y: screen.frame.maxY - collapsedNoNotchSize.height - noNotchTopInset,
            width: collapsedNoNotchSize.width,
            height: collapsedNoNotchSize.height
        )
        return virtual.insetBy(dx: -110, dy: -70)
    }

    private func hardwareNotchRect(for screen: NSScreen) -> CGRect {
        let size = screen.notchSize
        guard size != .zero else { return .zero }
        return CGRect(
            x: screen.frame.midX - size.width / 2.0,
            y: screen.frame.maxY - size.height - notchTopInset,
            width: size.width,
            height: size.height
        )
    }

    private func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }
        return CGDirectDisplayID(number.uint32Value)
    }

    private func detectNotch(on screen: NSScreen) -> Bool {
        guard #available(macOS 12.0, *) else { return false }
        let left = screen.auxiliaryTopLeftArea ?? .zero
        let right = screen.auxiliaryTopRightArea ?? .zero
        let blockedWidth = screen.frame.width - left.width - right.width
        return blockedWidth > 20 && min(left.height, right.height) > 0
    }

    private func openBlackWindow(for displayID: CGDirectDisplayID) {
        blackWindowController.createWindow(
            displayID: displayID,
            anchorScreen: screen(forDisplayID: displayID),
            notchTargetsProvider: { [weak self] in
                guard let self else { return [] }
                return self.panelsByDisplay.map { key, panel in
                    MetalBlackWindowsManager.NotchTarget(displayID: key, frame: panel.frame)
                }
            }
        )
    }

    private func reorganizeBlackWindows(for displayID: CGDirectDisplayID) {
        blackWindowController.reorganizeVisibleWindows(
            on: displayID,
            screen: screen(forDisplayID: displayID)
        )
    }

    private func applyMinimizedItems(_ items: [MinimizedWindowItem]) {
        for (displayID, model) in modelsByDisplay {
            model.minimizedItems = items
                .filter { $0.displayID == displayID }
                .sorted { $0.number < $1.number }
        }
    }

    private func screen(forDisplayID targetDisplayID: CGDirectDisplayID) -> NSScreen? {
        NSScreen.screens.first { displayID(for: $0) == targetDisplayID }
    }
}

final class NotchViewModel: ObservableObject {
    @Published var isExpanded = false
    @Published var minimizedItems: [MinimizedWindowItem] = []
    @Published var contentWidth: CGFloat = 0
    var hasPhysicalNotch = false
}

struct NotchShape: Shape {
    var cornerRadius: CGFloat
    var shoulderRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(cornerRadius, shoulderRadius) }
        set {
            cornerRadius = newValue.first
            shoulderRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let sr = shoulderRadius
        let cr = cornerRadius

        var path = Path()

        // Top-left corner (start)
        path.move(to: CGPoint(x: 0, y: 0))

        // Top edge
        path.addLine(to: CGPoint(x: rect.width, y: 0))

        // Right concave shoulder: arc from (rect.width, 0) to (rect.width - sr, sr)
        // Center at (rect.width, sr) — concave curve bowing outward (right)
        path.addArc(
            center: CGPoint(x: rect.width, y: sr),
            radius: sr,
            startAngle: .degrees(-90),
            endAngle: .degrees(180),
            clockwise: true
        )

        // Right side down to bottom-right corner
        path.addLine(to: CGPoint(x: rect.width - sr, y: rect.height - cr))

        // Bottom-right rounded corner
        path.addArc(
            center: CGPoint(x: rect.width - sr - cr, y: rect.height - cr),
            radius: cr,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: false
        )

        // Bottom edge
        path.addLine(to: CGPoint(x: sr + cr, y: rect.height))

        // Bottom-left rounded corner
        path.addArc(
            center: CGPoint(x: sr + cr, y: rect.height - cr),
            radius: cr,
            startAngle: .degrees(90),
            endAngle: .degrees(180),
            clockwise: false
        )

        // Left side up to left shoulder
        path.addLine(to: CGPoint(x: sr, y: sr))

        // Left concave shoulder: arc from (sr, sr) to (0, 0)
        // Center at (0, sr) — concave curve bowing outward (left)
        path.addArc(
            center: CGPoint(x: 0, y: sr),
            radius: sr,
            startAngle: .degrees(0),
            endAngle: .degrees(-90),
            clockwise: true
        )

        path.closeSubpath()
        return path
    }
}

struct NotchCapsuleView: View {
    @EnvironmentObject private var model: NotchViewModel
    let openBlackWindow: () -> Void
    let reorganizeBlackWindows: () -> Void
    let restoreBlackWindow: (UUID) -> Void
    @State private var hoveredMinimizedItemID: UUID?
    @State private var pendingHoverItemID: UUID?
    @State private var hoverActivationWorkItem: DispatchWorkItem?

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
                .fill(.black)

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
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: workItem)
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
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack(spacing: 6) {
                                            if let icon = item.icon {
                                                Image(nsImage: icon)
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 12, height: 12)
                                            } else {
                                                Image(systemName: "app.fill")
                                                    .font(.system(size: 11, weight: .semibold))
                                            }
                                            Text(item.title)
                                                .font(.system(size: 11, weight: .semibold))
                                        }
                                        if let preview = item.preview {
                                            Image(nsImage: preview)
                                                .resizable()
                                                .interpolation(.high)
                                                .scaledToFit()
                                                .frame(width: 260, height: 150)
                                                .clipShape(.rect(cornerRadius: 8))
                                        } else {
                                            Text("No preview")
                                                .font(.system(size: 10))
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding(8)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .background(GeometryReader { geo in
                            Color.clear.preference(key: WidthPreferenceKey.self, value: geo.size.width)
                        })
                    }
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .black, location: 0.05),
                                .init(color: .black, location: 0.95),
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
        .shadow(color: .black.opacity(0.12), radius: 3, y: 1.5)
        .padding(shadowPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: model.isExpanded)
    }

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
            NotchShape(cornerRadius: notchCornerRadius, shoulderRadius: shoulderRadius)
                .foregroundStyle(.black)
        } else {
            RoundedRectangle(cornerRadius: notchCornerRadius, style: .continuous)
                .foregroundStyle(.black)
        }
    }
}

struct NotchMetalEffectView: NSViewRepresentable {
    func makeCoordinator() -> Renderer {
        Renderer()
    }

    func makeNSView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        view.isPaused = false
        view.enableSetNeedsDisplay = true
        view.preferredFramesPerSecond = 45
        view.sampleCount = 1
        view.framebufferOnly = true
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        view.colorPixelFormat = .bgra8Unorm
        context.coordinator.configure(with: view)
        view.delegate = context.coordinator
        return view
    }

    func updateNSView(_ nsView: MTKView, context: Context) {}

    final class Renderer: NSObject, MTKViewDelegate {
        private var commandQueue: MTLCommandQueue?
        private var pipelineState: MTLRenderPipelineState?
        private var start = CACurrentMediaTime()

        func configure(with view: MTKView) {
            guard let device = view.device else { return }
            commandQueue = device.makeCommandQueue()

            guard let library = device.makeDefaultLibrary(),
                  let vertex = library.makeFunction(name: "notchVertex"),
                  let fragment = library.makeFunction(name: "notchFragment") else {
                return
            }

            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = vertex
            descriptor.fragmentFunction = fragment
            if #available(macOS 13.0, *) {
                descriptor.rasterSampleCount = view.sampleCount
            } else {
                descriptor.sampleCount = view.sampleCount
            }
            descriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
            descriptor.colorAttachments[0].isBlendingEnabled = true
            descriptor.colorAttachments[0].rgbBlendOperation = .add
            descriptor.colorAttachments[0].alphaBlendOperation = .add
            descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            descriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
            descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
            pipelineState = try? device.makeRenderPipelineState(descriptor: descriptor)
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

        func draw(in view: MTKView) {
            guard let drawable = view.currentDrawable,
                  let descriptor = view.currentRenderPassDescriptor,
                  let commandQueue,
                  let pipelineState,
                  let commandBuffer = commandQueue.makeCommandBuffer(),
                  let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
                return
            }

            let time = Float(CACurrentMediaTime() - start)
            encoder.setRenderPipelineState(pipelineState)
            encoder.setFragmentBytes([time], length: MemoryLayout<Float>.size, index: 0)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            encoder.endEncoding()
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}

extension NSScreen {
    var notchSize: CGSize {
        guard #available(macOS 12.0, *) else { return .zero }
        guard safeAreaInsets.top > 0 else { return .zero }

        let notchHeight = safeAreaInsets.top
        let fullWidth = frame.width
        let leftPadding = auxiliaryTopLeftArea?.width ?? 0
        let rightPadding = auxiliaryTopRightArea?.width ?? 0
        guard leftPadding > 0, rightPadding > 0 else { return .zero }

        let notchWidth = fullWidth - leftPadding - rightPadding
        guard notchWidth > 0 else { return .zero }
        return CGSize(width: notchWidth, height: notchHeight)
    }

    func notchSizeOrFallback(fallback: CGSize) -> CGSize {
        let size = notchSize
        guard size != .zero else { return fallback }
        return size
    }
}

struct WidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
