import SwiftUI
import AppKit
import MetalKit

struct MetalBlackWindowContent: View {
    let displayTitle: String
    let displayIcon: NSImage?
    let windowNumber: Int
    let isCompact: Bool
    let isAlwaysOnTop: Bool
    let isMaximized: Bool
    let terminalFontSize: CGFloat
    let toggleCompact: () -> Void
    let increaseFontSize: () -> Void
    let decreaseFontSize: () -> Void
    let commandSubmitted: (String) -> Void
    let directoryChanged: (String) -> Void
    let closeWindow: () -> Void
    let minimize: () -> Void
    let maximize: () -> Void
    let toggleAlwaysOnTop: () -> Void
    let isAnimatingMinimize: Bool
    let expandedFrameSize: CGSize
    let previewSnapshot: NSImage?
    let currentDirectory: String
    let preferMouseReporting: Bool

    @AppStorage(AppPreferences.Keys.enableCRTFilter) private var enableCRTFilter: Bool = AppPreferences.Defaults.enableCRTFilter
    @Environment(\.controlActiveState) private var controlActiveState
    @State private var showOpenPortsPopover = false
    @State private var openPorts: [OpenPortEntry] = []
    @State private var isLoadingOpenPorts = false
    @State private var portsMessage: String?

    private var cornerRadius: CGFloat { isCompact ? 18 : 22 }
    private var terminalCornerRadius: CGFloat { isCompact ? 12 : 16 }
    private var isRunningInPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.black)

            BlackWindowMetalEffectView(isActive: ((controlActiveState == .key) || !openPorts.isEmpty) && !isAnimatingMinimize)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .opacity(isCompact ? 0.22 : 0.35)

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)

            VStack(spacing: 0) {
                if isCompact {
                    compactHeader
                } else {
                    regularHeader
                }

                terminalBody
                Spacer()
            }
            .padding(10)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .background(Color.black.opacity(0.001))
        .animation(.spring(response: 0.22, dampingFraction: 0.85), value: isCompact)
    }

    private var compactHeader: some View {
        HStack(spacing: 6) {
            Button(action: closeWindow) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(width: 16, height: 16)
                    .background(.white.opacity(0.1), in: Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: 5) {
                if let displayIcon {
                    Image(nsImage: displayIcon)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                }
                Text(displayIcon != nil ? displayTitle : "NT")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(.white.opacity(0.1), in: Capsule())

            Spacer()

            Button(action: toggleCompact) {
                Image(systemName: "pip.exit")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(width: 16, height: 16)
                    .background(.white.opacity(0.1), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 4)
    }

    private var regularHeader: some View {
        HStack(spacing: 8) {
            headerButton(systemName: "xmark", action: closeWindow)
            headerButton(systemName: "minus", action: minimize)
            headerButton(
                systemName: isMaximized ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
                action: maximize
            )

            Spacer()

            HStack(spacing: 6) {
                if let displayIcon {
                    Image(nsImage: displayIcon)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 14, height: 14)
                }
                Text(displayTitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .allowsHitTesting(false)

            Spacer()

            networkButton

            Button(action: toggleAlwaysOnTop) {
                Image(systemName: isAlwaysOnTop ? "pin.fill" : "pin.slash")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(isAlwaysOnTop ? .yellow : .white)
                    .frame(width: 20, height: 20)
                    .background((isAlwaysOnTop ? Color.yellow.opacity(0.2) : .white.opacity(0.14)), in: Circle())
            }
            .buttonStyle(.plain)

            headerButton(systemName: "pip", action: toggleCompact)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 6)
        .background {
            WindowDragRegionView()
                .background(Color.white.opacity(0.001))
                .onTapGesture(count: 2) {
                    maximize()
                }
        }
    }

    private var networkButton: some View {
        Button {
            showOpenPortsPopover.toggle()
            if showOpenPortsPopover {
                refreshOpenPorts()
            }
        } label: {
            Image(systemName: "network")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(.white.opacity(0.14), in: Circle())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showOpenPortsPopover, arrowEdge: .bottom) {
            OpenPortsPopoverView(
                ports: openPorts,
                isLoading: isLoadingOpenPorts,
                message: portsMessage,
                onRefresh: { refreshOpenPorts() },
                onKill: { port in killPortProcess(port) }
            )
        }
    }

    private var terminalBody: some View {
        Group {
            if isRunningInPreview {
                RoundedRectangle(cornerRadius: terminalCornerRadius, style: .continuous)
                    .fill(Color.black.opacity(0.94))
                    .overlay(alignment: .topLeading) {
                        Text("Preview Terminal")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(12)
                    }
            } else {
                ZStack {
                    SwiftTermContainerView(
                        windowNumber: windowNumber,
                        fontSize: terminalFontSize,
                        currentDirectory: currentDirectory,
                        preferMouseReporting: preferMouseReporting,
                        commandSubmitted: commandSubmitted,
                        directoryChanged: directoryChanged
                    )
                    .modifier(CRTFilterModifier(enabled: enableCRTFilter))
                    .opacity(isAnimatingMinimize ? 0 : 1)

                    if isAnimatingMinimize, let previewSnapshot {
                        GeometryReader { geo in
                            Image(nsImage: previewSnapshot)
                                .resizable()
                                .scaledToFill()
                                .frame(width: geo.size.width, height: geo.size.height)
                                .clipped()
                        }
                    }
                }
            }
        }
        .clipped()
        .padding(.top, isCompact ? 8 : 14)
        .padding(.horizontal, isCompact ? 6 : 10)
        .padding(.bottom, isCompact ? 6 : 8)
        .clipShape(.rect(cornerRadius: terminalCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: terminalCornerRadius, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
                .allowsHitTesting(false)
        }
    }

    private func headerButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(.white.opacity(0.14), in: Circle())
        }
        .buttonStyle(.plain)
    }

    private func refreshOpenPorts() {
        isLoadingOpenPorts = true
        portsMessage = nil

        Task {
            do {
                let ports = try await PortProcessService.fetchListeningPorts()
                await MainActor.run {
                    openPorts = ports
                    isLoadingOpenPorts = false
                    portsMessage = ports.isEmpty ? "openPorts.message.noListening".localized : nil
                }
            } catch {
                await MainActor.run {
                    isLoadingOpenPorts = false
                    portsMessage = "openPorts.message.loadFailed".localized
                }
            }
        }
    }

    private func killPortProcess(_ port: OpenPortEntry) {
        Task {
            let terminated = await PortProcessService.terminate(pid: port.pid)
            await MainActor.run {
                if terminated {
                    openPorts.removeAll { $0.id == port.id }
                    portsMessage = openPorts.isEmpty ? "openPorts.message.noListening".localized : nil
                } else {
                    portsMessage = String(format: "openPorts.message.terminateFailed".localized, String(port.pid))
                }
            }
        }
    }
}

#Preview("Terminal Window") {
    MetalBlackWindowContent(
        displayTitle: "NotchTerminal · ~/project",
        displayIcon: nil,
        windowNumber: 1,
        isCompact: false,
        isAlwaysOnTop: false,
        isMaximized: false,
        terminalFontSize: 13,
        toggleCompact: {},
        increaseFontSize: {},
        decreaseFontSize: {},
        commandSubmitted: { _ in },
        directoryChanged: { _ in },
        closeWindow: {},
        minimize: {},
        maximize: {},
        toggleAlwaysOnTop: {},
        isAnimatingMinimize: false,
        expandedFrameSize: CGSize(width: 820, height: 520),
        previewSnapshot: nil,
        currentDirectory: "/Users/marco/project",
        preferMouseReporting: false
    )
    .frame(width: 860, height: 560)
    .padding()
    .background(Color(nsColor: .windowBackgroundColor))
}

struct BlackWindowMetalEffectView: NSViewRepresentable {
    var isActive: Bool = true

    func makeCoordinator() -> Renderer {
        Renderer()
    }

    func makeNSView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        view.isPaused = !isActive
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

    func updateNSView(_ nsView: MTKView, context: Context) {
        nsView.isPaused = !isActive
    }

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
