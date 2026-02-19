import MetalKit
import QuartzCore

final class MetalEffectRenderer: NSObject, MTKViewDelegate {
    private let fragmentFunctionName: String
    private var commandQueue: MTLCommandQueue?
    private var pipelineState: MTLRenderPipelineState?
    private var start = CACurrentMediaTime()

    init(fragmentFunctionName: String) {
        self.fragmentFunctionName = fragmentFunctionName
        super.init()
    }

    func configure(with view: MTKView) {
        guard let device = view.device else { return }
        commandQueue = device.makeCommandQueue()

        guard let library = device.makeDefaultLibrary(),
              let vertex = library.makeFunction(name: "notchVertex"),
              let fragment = library.makeFunction(name: fragmentFunctionName) else {
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
