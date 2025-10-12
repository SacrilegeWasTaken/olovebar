import Cocoa
import MetalKit
import CoreGraphics
import ApplicationServices

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
        window.backgroundColor = NSColor.clear
        window.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue - 1)
        window.ignoresMouseEvents = false 
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.hasShadow = false
        window.isReleasedWhenClosed = false
        window.orderBack(nil)
        
        let container = NSView(frame: frame)
        container.wantsLayer = true
        container.layer = CALayer()
        container.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.4).cgColor
        container.layer?.cornerRadius = 16
        container.layer?.masksToBounds = true
        
        metalView = MTKView(frame: container.bounds)
        metalView.autoresizingMask = [.width, .height]
        metalView.device = MTLCreateSystemDefaultDevice()
        metalView.clearColor = MTLClearColorMake(0.2, 0.2, 0.25, 0.4)
        metalView.framebufferOnly = false
        metalView.isPaused = false
        metalView.enableSetNeedsDisplay = true
        metalView.wantsLayer = true
        metalView.layer?.cornerRadius = 16
        metalView.layer?.masksToBounds = true
        
        container.addSubview(metalView)
        window.contentView = container
        
        window.makeKeyAndOrderFront(nil)
    }


    private func subscribeNotifications() {
        // Subscribe to notifications by system events
        let ncs = NSWorkspace.shared.notificationCenter

        // Subscribe to notifications by this app events
        // `let ncd = NotificationCenter.default`

        ncs.addObserver(
            self, 
            selector: #selector(updateState(_:)), 
            name: NSWorkspace.activeSpaceDidChangeNotification, 
            object: nil
        )
        ncs.addObserver(
            self,
            selector: #selector(updateState(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    @MainActor
    @objc private func updateState(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let runningApp = userInfo[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let appName = runningApp.localizedName else { return }

        print("Active app changed to: \(appName)")
        
        if isAppFullscreen(pid: runningApp.processIdentifier) {
            print("The app is in fullscreen mode. Hiding the bar.")
            window.orderOut(nil)
        } else {
            print("The app is not in fullscreen mode. Showing the bar.")
            window.orderFront(nil)
        }
    }


    private func isAppFullscreen(pid: pid_t) -> Bool {
        let appElement = AXUIElementCreateApplication(pid)
        
        var frontWindow: AnyObject?
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &frontWindow)
        
        guard result == .success, let window = frontWindow else {
            return false
        }
        
        var fullscreenValue: AnyObject?
        let fullscreenResult = AXUIElementCopyAttributeValue(window as! AXUIElement, "AXFullScreen" as CFString, &fullscreenValue)
        
        if fullscreenResult == .success, let fullscreen = fullscreenValue as? Bool {
            return fullscreen
        }
        
        return false
    }
}
