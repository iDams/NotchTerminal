import SwiftUI
import MetalKit

struct NotchMetalEffectView: NSViewRepresentable {
    func makeCoordinator() -> MetalEffectRenderer {
        MetalEffectRenderer(fragmentFunctionName: "notchFragment")
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
}
