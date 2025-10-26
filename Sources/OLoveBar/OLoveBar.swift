import Cocoa
import SwiftUI

class BarWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }

    var window: BarWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupWindow()
        subscribeNotifications()
    }

    @MainActor
    private func setupWindow() {
        let config = Config()

        let barHeight: CGFloat = config.barHeight
        let barHorizontalCut: CGFloat = config.barHorizontalCut
        let barVerticalCut: CGFloat = config.barVerticalCut
        guard let mainScreen = NSScreen.main else { return }
        let screenFrame = mainScreen.frame
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
        window.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue - 1)
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.hasShadow = false
        window.orderBack(nil)

        let container = NSView(frame: frame)
        container.wantsLayer = true
        container.layer?.backgroundColor = .clear
        // ensure container's layer is not opaque so alpha can show through
        container.layer?.isOpaque = false
        container.layer?.cornerRadius = config.windowCornerRadius
        container.layer?.masksToBounds = true

        // Host a SwiftUI view inside AppKit
        let hostingView = NSHostingView(rootView: BarContentView(config: config)
                                            .frame(maxWidth: .infinity, maxHeight: .infinity))
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(hostingView)

        // Constrain hosting view to container
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: container.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

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
