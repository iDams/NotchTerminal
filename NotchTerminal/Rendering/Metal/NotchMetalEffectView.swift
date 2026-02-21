import SwiftUI
import MetalKit
struct NotchMetalEffectView: NSViewRepresentable {
    var shader: String = "notchFragment"
    var theme: NotchViewModel.AuroraTheme = .classic
    var glowTheme: NotchViewModel.GlowTheme = .cyberpunk

    func makeCoordinator() -> MetalEffectRenderer {
        let renderer = MetalEffectRenderer(fragmentFunctionName: shader)
        renderer.auroraTheme = theme
        renderer.glowTheme = glowTheme
        return renderer
    }

    func makeNSView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        view.isPaused = false
        view.enableSetNeedsDisplay = false
        view.preferredFramesPerSecond = 45
        view.sampleCount = 1
        view.framebufferOnly = true
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        view.colorPixelFormat = .bgra8Unorm
        context.coordinator.configure(with: view)
        view.delegate = context.coordinator
        return view
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        context.coordinator.auroraTheme = theme
        context.coordinator.glowTheme = glowTheme
    }
}

/// A reusable modifier that applies a complex, multi-layered blurred mask to a View
/// to create a volumetric radial glow that extends safely past its bounding box.
public struct ZenithVolumetricGlowModifier: ViewModifier {
    public var cornerRadius: CGFloat
    public var isExpanded: Bool
    
    public func body(content: Content) -> some View {
        content
            .padding(-30) // Expand bounds so the glow doesn't hit a square wall
            .mask {
                ZStack {
                    // Large ambient radial glow
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(lineWidth: isExpanded ? 24 : 18)
                        .blur(radius: isExpanded ? 16 : 12)
                        .opacity(0.55)
                        
                    // Medium tighter glow
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(lineWidth: isExpanded ? 8 : 6)
                        .blur(radius: isExpanded ? 6 : 4)
                        .opacity(0.8)

                    // Core sharp neon line
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(lineWidth: isExpanded ? 2.0 : 1.5)
                }
                .padding(30) // Constrain the drawing paths back to the true notch bounds
            }
            .allowsHitTesting(false)
    }
}
