import Metal
import MetalKit
import simd

@MainActor
final class BarRenderer: NSObject, MTKViewDelegate {

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var pipelineState: MTLRenderPipelineState!

    var color: SIMD4<Float> = SIMD4(0.2, 0.5, 0.1, 0.3)

    init(metalView: MTKView) {
        guard let device = metalView.device else {
            fatalError("Metal device not available")
        }
        self.device = device
        self.commandQueue = device.makeCommandQueue()!
        super.init()

        metalView.delegate = self
        metalView.enableSetNeedsDisplay = true
        metalView.isPaused = false
        metalView.framebufferOnly = false
        metalView.wantsLayer = true
        metalView.layer?.backgroundColor = NSColor.clear.cgColor
        // Ensure the Metal layer is not treated as opaque so alpha is preserved
        metalView.layer?.isOpaque = false
        metalView.clearColor = MTLClearColorMake(0, 0, 0, 0)
        metalView.colorPixelFormat = .bgra8Unorm

        setupPipeline()
    }

    private func setupPipeline() {
        // Загружаем библиотеку из ресурса
        guard let libraryFile = Bundle.module.url(forResource: "Shaders", withExtension: "metal") else {
            fatalError("Shaders.metal not found in bundle")
        }

        let source = try! String(contentsOf: libraryFile)
        let library = try! device.makeLibrary(source: source, options: nil)

        let vertexFunc = library.makeFunction(name: "vertex_main")
        let fragmentFunc = library.makeFunction(name: "fragment_main")

        let pipelineDesc = MTLRenderPipelineDescriptor()
        pipelineDesc.vertexFunction = vertexFunc
        pipelineDesc.fragmentFunction = fragmentFunc
        pipelineDesc.colorAttachments[0].pixelFormat = .bgra8Unorm

        pipelineDesc.colorAttachments[0].isBlendingEnabled = true
        pipelineDesc.colorAttachments[0].rgbBlendOperation = .add
        pipelineDesc.colorAttachments[0].alphaBlendOperation = .add
        pipelineDesc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineDesc.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        pipelineDesc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        pipelineDesc.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        pipelineState = try! device.makeRenderPipelineState(descriptor: pipelineDesc)
    }

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor else { return }

        let commandBuffer = commandQueue.makeCommandBuffer()!
        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        encoder.setRenderPipelineState(pipelineState)

        var c = color
        encoder.setFragmentBytes(&c, length: MemoryLayout<SIMD4<Float>>.stride, index: 0)

        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        encoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
}
