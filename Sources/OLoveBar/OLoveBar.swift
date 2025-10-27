import Cocoa
import SwiftUI

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }

    var mainWindow: OLoveBarWindow!
    var notchWindow: OLoveBarWindow!

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
        let level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue - 1)
        guard let mainScreen = NSScreen.main else { return }
        let screenFrame = mainScreen.frame
        let frame = NSRect(
            x: barHorizontalCut,
            y: screenFrame.height - barHeight - barVerticalCut,
            width: screenFrame.width - barHorizontalCut * 2,
            height: barHeight - barVerticalCut
        )

        mainWindow = OLoveBar.setupWindow(frame: frame, config: config, level: level) {
            BarContentView(config: config)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }

        let notchFrame = NSRect(
            x: Globals.screenWidth / 2 - Globals.notchWidth / 2 + 1,
            y: screenFrame.height - Globals.notchHeight - 50, 
            width: Globals.notchWidth - 2, 
            height: Globals.notchHeight
        )

        notchWindow = OLoveBar.setupWindow(frame: notchFrame, config: config, level: level + 4, .white) {
            NotchContentView()
        }
        
        let expandedNotchFrame = NSRect(
            x: notchFrame.minX - 150,
            y: notchFrame.minY - 200,
            width: notchFrame.width + 300,
            height: notchFrame.height + 200
        )
        
        notchWindow.setupHoverTracking(collapsedFrame: notchFrame, expandedFrame: expandedNotchFrame)
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
            mainWindow.orderOut(nil)
        } else {
            mainWindow.orderFront(nil)
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
