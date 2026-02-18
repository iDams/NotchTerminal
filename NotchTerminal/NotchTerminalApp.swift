import SwiftUI
import AppKit
import QuartzCore
import MetalKit

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
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var lastCursorLocation: CGPoint?

    func start() {
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
                let panel = makePanel(model: model)
                panelsByDisplay[displayID] = panel
                hostsByDisplay[displayID] = panel.contentView as? NSHostingView<AnyView>
            } else {
                hostsByDisplay[displayID]?.rootView = AnyView(
                    NotchCapsuleView()
                        .environmentObject(model)
                )
            }
        }

        layoutPanels(animated: false)
    }

    private func makePanel(model: NotchViewModel) -> NSPanel {
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
                NotchCapsuleView()
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
            let frame = frameForPanel(on: screen, hasNotch: model.hasPhysicalNotch, isExpanded: model.isExpanded)

            if animated {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = model.isExpanded ? 0.10 : 0.13
                    context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    panel.animator().setFrame(frame, display: true)
                }
            } else {
                panel.setFrame(frame, display: true)
            }
        }
    }

    private func frameForPanel(on screen: NSScreen, hasNotch: Bool, isExpanded: Bool) -> CGRect {
        let closedSize: NSSize = {
            guard hasNotch else { return collapsedNoNotchSize }
            let raw = screen.notchSizeOrFallback(fallback: collapsedNoNotchSize)
            return NSSize(
                width: max(92, raw.width * notchClosedWidthScale),
                height: max(22, raw.height * notchClosedHeightScale)
            )
        }()
        let visualSize = isExpanded ? expandedSize : closedSize
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
}

final class NotchViewModel: ObservableObject {
    @Published var isExpanded = false
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

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.black)
                .mask(notchBackgroundMaskGroup)
                .overlay {
                    if model.isExpanded {
                        NotchMetalEffectView()
                            .mask(notchBackgroundMaskGroup)
                            .opacity(0.72)
                    }
                }
                .shadow(color: .black.opacity(0.12), radius: 3, y: 1.5)
        }
        .padding(shadowPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(response: 0.20, dampingFraction: 0.82), value: model.isExpanded)
    }

    private var shadowPadding: CGFloat { 16 }

    private var notchCornerRadius: CGFloat {
        model.isExpanded ? 32 : 8
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
