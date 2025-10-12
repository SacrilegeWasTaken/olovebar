import Cocoa
import MetalKit

final class BarWindow: NSWindow {
    override var canBecomeKey: Bool {
        false
    }
    override var canBecomeMain: Bool {
        false
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: BarWindow!
    var metalView: MTKView!

    public func applicationDidFinishLaunching(_ notification: Notification) {
        let barHeight: CGFloat = 35
        let barHorizontalCut: CGFloat = 10
        let barVerticalCut: CGFloat = 4
        let screenFrame = NSScreen.main!.frame
        let frame = NSRect(
            x: barHorizontalCut,
            y: screenFrame.height - barHeight - barVerticalCut,
            width: screenFrame.width - barHorizontalCut * 2,
            height: barHeight - barVerticalCut 
        )


        print("Screen frame: \(frame)")
        
        window = BarWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.isOpaque = false
        window.backgroundColor = NSColor.clear
        window.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue - 1)
        window.ignoresMouseEvents = false 
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.hasShadow = false
        window.isReleasedWhenClosed = false
        window.orderBack(nil)

        // Контейнер для Metal
        let container = NSView(frame: frame)
        container.wantsLayer = true
        container.layer = CALayer()
        container.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.4).cgColor
        container.layer?.cornerRadius = 16
        container.layer?.masksToBounds = true

        // Metal внутри контейнера
        metalView = MTKView(frame: container.bounds)
        metalView.autoresizingMask = [.width, .height]
        metalView.device = MTLCreateSystemDefaultDevice()
        metalView.clearColor = MTLClearColorMake(0.2, 0.2, 0.25, 0.4)
        metalView.framebufferOnly = false
        metalView.isPaused = false
        metalView.enableSetNeedsDisplay = true

        // Metal слой подчиняется маске
        metalView.wantsLayer = true
        metalView.layer?.cornerRadius = 16
        metalView.layer?.masksToBounds = true

        container.addSubview(metalView)
        window.contentView = container

        window.makeKeyAndOrderFront(nil)
    }
}