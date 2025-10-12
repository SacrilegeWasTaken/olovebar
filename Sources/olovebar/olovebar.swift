import Cocoa
import MetalKit

final class BarWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}


final class AppDelegate: NSObject, NSApplicationDelegate {

    var window: BarWindow!
    var metalView: MTKView!
    var renderer: BarRenderer!

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupWindow()
        subscribeNotifications()
    }

    @MainActor
    private func setupWindow() {
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

        window = BarWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .statusBar
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.hasShadow = false
        window.orderBack(nil)

        let container = NSView(frame: frame)
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.clear.cgColor
        // ensure container's layer is not opaque so alpha can show through
        container.layer?.isOpaque = false
        container.layer?.cornerRadius = 16
        container.layer?.masksToBounds = true

        metalView = MTKView(frame: container.bounds)
        metalView.autoresizingMask = [.width, .height]
        metalView.device = MTLCreateSystemDefaultDevice()
        metalView.isPaused = false
        metalView.enableSetNeedsDisplay = true
        metalView.framebufferOnly = false
        metalView.wantsLayer = true
        metalView.layer?.backgroundColor = NSColor.clear.cgColor
        metalView.layer?.isOpaque = false
        metalView.layer?.cornerRadius = 16
        metalView.layer?.masksToBounds = true

        renderer = BarRenderer(metalView: metalView)
        container.addSubview(metalView)
        window.contentView = container
        window.makeKeyAndOrderFront(nil)
    }

    private func subscribeNotifications() {
        let ncs = NSWorkspace.shared.notificationCenter
        ncs.addObserver(self, selector: #selector(updateState(_:)),
                        name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        ncs.addObserver(self, selector: #selector(updateState(_:)),
                        name: NSWorkspace.didActivateApplicationNotification, object: nil)
    }

    @MainActor
    @objc private func updateState(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let runningApp = userInfo[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }

        if isAppFullscreen(pid: runningApp.processIdentifier) {
            window.orderOut(nil)
        } else {
            window.orderFront(nil)
        }
    }

    private func isAppFullscreen(pid: pid_t) -> Bool {
        let appElement = AXUIElementCreateApplication(pid)
        var frontWindow: AnyObject?
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &frontWindow)
        guard result == .success, let window = frontWindow else { return false }

        var fullscreenValue: AnyObject?
        let fullscreenResult = AXUIElementCopyAttributeValue(window as! AXUIElement, "AXFullScreen" as CFString, &fullscreenValue)
        if fullscreenResult == .success, let fullscreen = fullscreenValue as? Bool {
            return fullscreen
        }
        return false
    }
}
