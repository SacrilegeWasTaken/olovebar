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
    var notchWindow: NotchWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupSignalHandlers()
        setupWindows()
        subscribeNotifications()
    }

    @MainActor
    private func setupWindows() {
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
            x: Globals.screenWidth / 2 - Globals.notchWidth / 2 + 5,
            y: screenFrame.height - Globals.notchHeight + 5, 
            width: Globals.notchWidth - 10, 
            height: Globals.notchHeight - 5
        )

        notchWindow = OLoveBar.setupNotchWindow(frame: notchFrame, config: config, level: level + 4, .black) { state in
            NotchContentView(config: config, state: state)
                .frame(width: .infinity, height: .infinity)
        }
        
        let expandedNotchFrame = NSRect(
            x: notchFrame.minX - 250,
            y: notchFrame.minY - 100,
            width: notchFrame.width + 500,
            height: notchFrame.height + 100
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

    @MainActor
    private func setupSignalHandlers() {
        signal(SIGINT) { _ in
            print("\nReceived SIGINT, exiting...")
            NSApplication.shared.terminate(nil)
        }
        
        signal(SIGTERM) { _ in
            print("\nReceived SIGTERM, exiting...")
            NSApplication.shared.terminate(nil)
        }
    }
}
