import SwiftUI
import AppKit
import MetalKit

@MainActor
final class MetalBlackWindowController {
    private var panel: NSPanel?
    private let expandedSize = CGSize(width: 540, height: 320)
    private let compactSize = CGSize(width: 170, height: 170)
    private var isCompact = false

    func toggle(anchorScreen: NSScreen?) {
        if let panel, panel.isVisible {
            panel.orderOut(nil)
            return
        }
        show(anchorScreen: anchorScreen)
    }

    private func show(anchorScreen: NSScreen?) {
        let screen = anchorScreen ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }

        let panel = panel ?? makePanel()
        self.panel = panel
        isCompact = false

        updateContent(in: panel)
        panel.setFrame(frameForInitialShow(on: screen), display: true)
        panel.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: false)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: CGRect(origin: .zero, size: expandedSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        updateContent(in: panel)
        return panel
    }

    private func updateContent(in panel: NSPanel) {
        let root = MetalBlackWindowContent(
            isCompact: isCompact,
            toggleCompact: { [weak self] in
                self?.toggleCompactSize()
            }
        )
        if let hostingView = panel.contentView as? NSHostingView<MetalBlackWindowContent> {
            hostingView.rootView = root
        } else {
            panel.contentView = NSHostingView(rootView: root)
        }
    }

    private func toggleCompactSize() {
        guard let panel else { return }
        isCompact.toggle()
        updateContent(in: panel)

        let targetSize = isCompact ? compactSize : expandedSize
        let currentFrame = panel.frame
        let targetOrigin = CGPoint(
            x: currentFrame.midX - targetSize.width / 2,
            y: currentFrame.maxY - targetSize.height
        )
        let targetFrame = CGRect(origin: targetOrigin, size: targetSize)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(targetFrame, display: true)
        }
    }

    private func frameForInitialShow(on screen: NSScreen) -> CGRect {
        let origin = CGPoint(
            x: screen.frame.midX - expandedSize.width / 2,
            y: screen.frame.maxY - expandedSize.height - 120
        )
        return CGRect(origin: origin, size: expandedSize)
    }
}

struct MetalBlackWindowContent: View {
    let isCompact: Bool
    let toggleCompact: () -> Void

    private var cornerRadius: CGFloat {
        isCompact ? 18 : 22
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.black)

            BlackWindowMetalEffectView()
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .opacity(isCompact ? 0.22 : 0.35)

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)

            VStack {
                HStack {
                    Spacer()
                    Button(action: toggleCompact) {
                        Image(systemName: isCompact ? "heart.slash.fill" : "heart.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(.white.opacity(0.14), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(10)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .padding(2)
        .animation(.spring(response: 0.22, dampingFraction: 0.85), value: isCompact)
    }
}

struct BlackWindowMetalEffectView: NSViewRepresentable {
    func makeCoordinator() -> Renderer {
        Renderer()
    }

    func makeNSView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        view.isPaused = false
        view.enableSetNeedsDisplay = true
        view.preferredFramesPerSecond = 30
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
                  let fragment = library.makeFunction(name: "blackWindowFragment") else {
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
