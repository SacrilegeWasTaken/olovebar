import AppKit
@preconcurrency import ApplicationServices
import Combine
import os

/// Controls placement of macOS notification banners using Accessibility.
/// This mirrors the general idea of tools like PingPlace, but is implemented
/// specifically for OLoveBar and driven by its `Config`.
@MainActor
final class NotificationPlacementController {
    static let shared = NotificationPlacementController(config: Config.shared)

    private let config: Config
    private var cancellables = Set<AnyCancellable>()
    
    private struct SendableTimer: @unchecked Sendable {
        let timer: Timer
    }
    
    private let _timer = OSAllocatedUnfairLock<SendableTimer?>(initialState: nil)
    private let _axObserver = OSAllocatedUnfairLock<AXObserver?>(initialState: nil)
    /// Baseline banner origin used in "offset" mode to avoid cumulative drift.
    private var offsetBaselineOrigin: CGPoint?

    init(config: Config) {
        self.config = config
        observeConfig()
        updateRunningState()
    }

    deinit {
        let obs = _axObserver.withLock { let o = $0; $0 = nil; return o }
        let boxedTimer = _timer.withLock { let t = $0; $0 = nil; return t }

        Task { @MainActor in
            boxedTimer?.timer.invalidate()
        }

        if let o = obs {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(o), .defaultMode)
        }
    }

    private func observeConfig() {
        config.$notificationsEnabled
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateRunningState()
            }
            .store(in: &cancellables)
    }

    private func updateRunningState() {
        guard config.notificationsEnabled, AXIsProcessTrusted() else {
            stopTimer()
            tearDownObserver()
            offsetBaselineOrigin = nil
            return
        }

        startTimerIfNeeded()
        setupObserverIfNeeded()
    }

    private func startTimerIfNeeded() {
        guard _timer.withLock({ $0 }) == nil else { return }

        let newTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
        RunLoop.main.add(newTimer, forMode: .common)
        
        let sendableT = SendableTimer(timer: newTimer)
        _timer.withLock { $0 = sendableT }
    }

    private func stopTimer() {
        let boxedTimer = _timer.withLock { let t = $0; $0 = nil; return t }
        boxedTimer?.timer.invalidate()
    }

    private func setupObserverIfNeeded() {
        guard _axObserver.withLock({ $0 }) == nil else { return }

        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.notificationcenterui")
        guard let app = apps.first else { return }

        var observer: AXObserver?
        let result = AXObserverCreate(app.processIdentifier, notificationObserverCallback, &observer)
        guard result == .success, let observer else { return }

        _axObserver.withLock { $0 = observer }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        AXObserverAddNotification(observer, appElement, kAXWindowCreatedNotification as CFString, selfPtr)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observer), .defaultMode)

        // As a safety net, reposition already visible notification banners right away.
        moveAllNotifications()
    }

    private func tearDownObserver() {
        _axObserver.withLock { obs in
            if let observer = obs {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observer), .defaultMode)
            }
            obs = nil
        }
    }

    private func tick() {
        guard AXIsProcessTrusted() else {
            stopTimer()
            return
        }

        moveAllNotifications()
    }

    private func notificationCenterAppElement() -> AXUIElement? {
        // Notification banners are drawn by the Notification Center UI process.
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.notificationcenterui")
        guard let app = apps.first else { return nil }
        return AXUIElementCreateApplication(app.processIdentifier)
    }

    private func copyWindows(from app: AXUIElement) -> [AXUIElement]? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value)
        guard result == .success, let array = value as? [AXUIElement] else { return nil }
        return array
    }

    private func moveAllNotifications() {
        guard let appElement = notificationCenterAppElement(),
              let windows = copyWindows(from: appElement) else {
            offsetBaselineOrigin = nil
            return
        }

        for window in windows {
            repositionIfNeeded(window: window)
        }
    }

    private func repositionIfNeeded(window: AXUIElement) {
        guard isNotificationBanner(window: window) else { return }

        guard var frame = copyFrame(of: window) else { return }
        guard screenFor(frame: frame) != nil else { return }

        let targetOrigin: CGPoint

        if offsetBaselineOrigin == nil {
            offsetBaselineOrigin = frame.origin
        }
        guard let baseline = offsetBaselineOrigin else { return }
        targetOrigin = CGPoint(
            x: baseline.x + config.notificationsOffsetX,
            y: baseline.y + config.notificationsOffsetY
        )

        // Debounce tiny changes to avoid unnecessary AX writes.
        if abs(frame.origin.x - targetOrigin.x) < 1.0,
           abs(frame.origin.y - targetOrigin.y) < 1.0 {
            return
        }

        frame.origin = targetOrigin
        setPosition(of: window, to: targetOrigin)
    }

    // Called immediately when a new notification window is created via AXObserver.
    func handleWindowCreated(element: AXUIElement) {
        repositionIfNeeded(window: element)
    }

    private func isNotificationBanner(window: AXUIElement) -> Bool {
        let targetSubroles = ["AXNotificationCenterBanner", "AXNotificationCenterAlert"]
        return findElementWithSubrole(root: window, targetSubroles: targetSubroles) != nil
    }

    private func copyFrame(of element: AXUIElement) -> CGRect? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, "AXFrame" as CFString, &value)
        guard result == .success,
              let cfValue = value,
              CFGetTypeID(cfValue) == AXValueGetTypeID() else {
            return nil
        }
        let axValue = cfValue as! AXValue

        var rect = CGRect.zero
        guard AXValueGetType(axValue) == .cgRect,
              AXValueGetValue(axValue, .cgRect, &rect) else {
            return nil
        }

        return rect
    }

    private func setPosition(of element: AXUIElement, to point: CGPoint) {
        var mutablePoint = point
        guard let value = AXValueCreate(.cgPoint, &mutablePoint) else { return }
        _ = AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, value)
    }

    private func screenFor(frame: CGRect) -> NSScreen? {
        for screen in NSScreen.screens {
            if screen.frame.intersects(frame) {
                return screen
            }
        }
        return NSScreen.main
    }

    // Adapted from PingPlace: recursively search for elements with specific AXSubrole.
    private func findElementWithSubrole(root: AXUIElement, targetSubroles: [String]) -> AXUIElement? {
        var subroleRef: AnyObject?
        if AXUIElementCopyAttributeValue(root, kAXSubroleAttribute as CFString, &subroleRef) == .success {
            if let subrole = subroleRef as? String, targetSubroles.contains(subrole) {
                return root
            }
        }

        var childrenRef: AnyObject?
        guard AXUIElementCopyAttributeValue(root, kAXChildrenAttribute as CFString, &childrenRef) == .success,
              let children = childrenRef as? [AXUIElement] else {
            return nil
        }

        for child in children {
            if let found = findElementWithSubrole(root: child, targetSubroles: targetSubroles) {
                return found
            }
        }

        return nil
    }
}

private func notificationObserverCallback(observer: AXObserver, element: AXUIElement, notification: CFString, context: UnsafeMutableRawPointer?) {
    guard let context = context else { return }
    let controller = Unmanaged<NotificationPlacementController>.fromOpaque(context).takeUnretainedValue()

    Task { @MainActor [weak controller] in
        controller?.handleWindowCreated(element: element)
    }
}

