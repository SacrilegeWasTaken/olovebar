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
    private let logger = Logger(subsystem: "OLoveBar", category: "NotificationPlacement")
    private let diagnosticsEnabled = ProcessInfo.processInfo.environment["OLOVEBAR_AX_DEBUG"] == "1"
    private let diagnosticsLogURL: URL = {
        let logsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/OLoveBar", isDirectory: true)
        return logsDir.appendingPathComponent("notification-ax.log", isDirectory: false)
    }()
    private let diagnosticsMaxFileSizeBytes: UInt64 = 2 * 1024 * 1024
    private let diagnosticsDateFormatter = ISO8601DateFormatter()
    /// Polling interval for keeping notification windows pinned in place.
    private let repositionPollingInterval: TimeInterval = 0.07
    /// Extra fast re-sync passes right after a new AX window appears.
    private let immediateResyncPassCount: Int = 10
    private let immediateResyncStep: TimeInterval = 0.012
    /// Bounds for recursive AX scanning on unknown windows.
    private let subroleSearchMaxDepth: Int = 36
    private let subroleSearchChildrenLimit: Int = 180
    private var cancellables = Set<AnyCancellable>()
    
    private struct SendableTimer: @unchecked Sendable {
        let timer: Timer
    }
    
    private let _timer = OSAllocatedUnfairLock<SendableTimer?>(initialState: nil)
    private let _axObserver = OSAllocatedUnfairLock<AXObserver?>(initialState: nil)
    /// Baseline banner origin per AX window to avoid drift over long-lived notifications.
    private var offsetBaselineOrigins = [CFHashCode: CGPoint]()
    /// De-duplicate diagnostics so AX tree logs stay readable.
    private var loggedWindowSignatures = Set<String>()
    /// Cache only positive AX classification by element hash.
    /// (Avoid caching negatives: some windows become banner-like after initial creation.)
    private var bannerClassificationCache = [CFHashCode: Bool]()
    /// Coalesces immediate re-sync bursts when many windows appear at once.
    private var immediateResyncGeneration: UInt64 = 0

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
            offsetBaselineOrigins.removeAll(keepingCapacity: true)
            return
        }

        startTimerIfNeeded()
        setupObserverIfNeeded()
    }

    private func startTimerIfNeeded() {
        guard _timer.withLock({ $0 }) == nil else { return }

        let newTimer = Timer.scheduledTimer(withTimeInterval: repositionPollingInterval, repeats: true) { [weak self] _ in
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
            offsetBaselineOrigins.removeAll(keepingCapacity: true)
            bannerClassificationCache.removeAll(keepingCapacity: true)
            return
        }

        // Drop stale cache entries for closed windows.
        let liveHashes = Set(windows.map { CFHash($0) })
        bannerClassificationCache = bannerClassificationCache.filter { liveHashes.contains($0.key) }
        offsetBaselineOrigins = offsetBaselineOrigins.filter { liveHashes.contains($0.key) }

        for window in windows {
            repositionIfNeeded(window: window)
        }
    }

    private func repositionIfNeeded(window: AXUIElement) {
        guard isNotificationBanner(window: window) else { return }

        guard var frame = copyFrame(of: window) else { return }
        guard screenFor(frame: frame) != nil else { return }
        let windowHash = CFHash(window)

        let targetOrigin: CGPoint

        if offsetBaselineOrigins[windowHash] == nil {
            offsetBaselineOrigins[windowHash] = frame.origin
        }
        guard let baseline = offsetBaselineOrigins[windowHash] else { return }
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
        if diagnosticsEnabled {
            logWindowDiagnosticsIfNeeded(window: element, trigger: "created")
        }
        repositionIfNeeded(window: element)
        // Run one full pass immediately in the same runloop tick.
        moveAllNotifications()
        scheduleImmediateResync()
    }

    private func isNotificationBanner(window: AXUIElement) -> Bool {
        let elementHash = CFHash(window)
        if let cached = bannerClassificationCache[elementHash] {
            return cached
        }

        if let identifier = copyStringAttribute(kAXIdentifierAttribute as CFString, from: window),
           identifier.hasPrefix("widget") {
            return false
        }

        let primarySubroles: Set<String> = [
            "AXNotificationCenterBanner",
            "AXNotificationCenterAlert"
        ]
        let secondarySubroles: Set<String> = [
            "AXBanner",
            "AXAlert",
            "AXSystemDialog",
            "AXDialog"
        ]

        if let directSubrole = copyStringAttribute(kAXSubroleAttribute as CFString, from: window),
           primarySubroles.contains(directSubrole) {
            bannerClassificationCache[elementHash] = true
            return true
        }
        if let directSubrole = copyStringAttribute(kAXSubroleAttribute as CFString, from: window),
           secondarySubroles.contains(directSubrole),
           isSecondaryBannerWindowCandidate(window) {
            bannerClassificationCache[elementHash] = true
            return true
        }

        var visited = Set<CFHashCode>()
        let primaryMatch = findElementWithSubrole(
            root: window,
            targetSubroles: primarySubroles,
            visited: &visited,
            maxDepth: subroleSearchMaxDepth
        )
        if primaryMatch != nil {
            bannerClassificationCache[elementHash] = true
            return true
        }

        let secondaryMatch = findElementWithSubrole(
            root: window,
            targetSubroles: secondarySubroles,
            visited: &visited,
            maxDepth: subroleSearchMaxDepth
        )
        let isSecondaryBanner = (secondaryMatch != nil) && isSecondaryBannerWindowCandidate(window)
        if isSecondaryBanner {
            bannerClassificationCache[elementHash] = true
            return true
        }

        if diagnosticsEnabled {
            logWindowDiagnosticsIfNeeded(window: window, trigger: "not-matched")
        }
        return false
    }

    /// Secondary subroles are only accepted for compact top-right windows,
    /// so we don't accidentally control other Notification Center UI panels.
    private func isSecondaryBannerWindowCandidate(_ window: AXUIElement) -> Bool {
        let role = copyStringAttribute(kAXRoleAttribute as CFString, from: window) ?? ""
        guard role == kAXWindowRole as String else { return false }
        guard let frame = copyFrame(of: window),
              let screen = screenFor(frame: frame) else { return false }

        let compactWidth = frame.width <= 520
        let compactHeight = frame.height <= 260
        let nearRightEdge = frame.maxX >= (screen.frame.maxX - screen.frame.width * 0.35)
        let nearTopHalf = frame.midY >= (screen.frame.midY - 10)
        return compactWidth && compactHeight && nearRightEdge && nearTopHalf
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
    // AX trees can contain cycles; guard with visited + depth limit.
    private func findElementWithSubrole(
        root: AXUIElement,
        targetSubroles: Set<String>,
        visited: inout Set<CFHashCode>,
        depth: Int = 0,
        maxDepth: Int = 40
    ) -> AXUIElement? {
        guard depth <= maxDepth else { return nil }

        let elementHash = CFHash(root)
        guard visited.insert(elementHash).inserted else { return nil }

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

        for child in children.prefix(subroleSearchChildrenLimit) {
            if let found = findElementWithSubrole(
                root: child,
                targetSubroles: targetSubroles,
                visited: &visited,
                depth: depth + 1,
                maxDepth: maxDepth
            ) {
                return found
            }
        }

        return nil
    }

    private func copyStringAttribute(_ attribute: CFString, from element: AXUIElement) -> String? {
        var valueRef: AnyObject?
        guard AXUIElementCopyAttributeValue(element, attribute, &valueRef) == .success else {
            return nil
        }
        return valueRef as? String
    }

    private func roleAndSubrole(for element: AXUIElement) -> (role: String, subrole: String) {
        let role = copyStringAttribute(kAXRoleAttribute as CFString, from: element) ?? "<nil>"
        let subrole = copyStringAttribute(kAXSubroleAttribute as CFString, from: element) ?? "<nil>"
        return (role, subrole)
    }

    private func logWindowDiagnosticsIfNeeded(window: AXUIElement, trigger: String) {
        guard diagnosticsEnabled else { return }
        let top = roleAndSubrole(for: window)
        let signature = "\(trigger)|\(top.role)|\(top.subrole)"
        guard loggedWindowSignatures.insert(signature).inserted else { return }

        emitDiagnosticsLine("AX diagnostics [\(trigger)] root role=\(top.role) subrole=\(top.subrole)")

        var childrenRef: AnyObject?
        guard AXUIElementCopyAttributeValue(window, kAXChildrenAttribute as CFString, &childrenRef) == .success,
              let children = childrenRef as? [AXUIElement] else {
            emitDiagnosticsLine("AX diagnostics: root has no readable children")
            return
        }

        if children.isEmpty {
            emitDiagnosticsLine("AX diagnostics: root children list is empty")
            return
        }

        for (idx, child) in children.prefix(12).enumerated() {
            let info = roleAndSubrole(for: child)
            emitDiagnosticsLine("AX child[\(idx)] role=\(info.role) subrole=\(info.subrole)")

            var grandChildrenRef: AnyObject?
            guard AXUIElementCopyAttributeValue(child, kAXChildrenAttribute as CFString, &grandChildrenRef) == .success,
                  let grandChildren = grandChildrenRef as? [AXUIElement] else {
                continue
            }

            for (gidx, grandChild) in grandChildren.prefix(8).enumerated() {
                let gInfo = roleAndSubrole(for: grandChild)
                emitDiagnosticsLine("AX child[\(idx)] grandChild[\(gidx)] role=\(gInfo.role) subrole=\(gInfo.subrole)")
            }
        }
    }

    private func emitDiagnosticsLine(_ line: String) {
        guard diagnosticsEnabled else { return }
        logger.notice("\(line, privacy: .public)")
        appendDiagnosticsToFile(line)
    }

    private func scheduleImmediateResync() {
        // Notification Center can animate/reflow windows for a short period.
        // Burst-pass re-sync makes the visible position settle almost instantly.
        immediateResyncGeneration &+= 1
        let generation = immediateResyncGeneration
        for idx in 1...immediateResyncPassCount {
            let delay = immediateResyncStep * Double(idx)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self else { return }
                guard generation == self.immediateResyncGeneration else { return }
                self.moveAllNotifications()
            }
        }
    }

    private func appendDiagnosticsToFile(_ line: String) {
        guard diagnosticsEnabled else { return }
        let timestamp = diagnosticsDateFormatter.string(from: Date())
        let payload = "[\(timestamp)] \(line)\n"
        guard let data = payload.data(using: .utf8) else { return }

        do {
            let logsDir = diagnosticsLogURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: diagnosticsLogURL.path) {
                FileManager.default.createFile(atPath: diagnosticsLogURL.path, contents: nil)
            }
            let attrs = try FileManager.default.attributesOfItem(atPath: diagnosticsLogURL.path)
            let currentFileSize = (attrs[.size] as? NSNumber)?.uint64Value ?? 0
            if currentFileSize >= diagnosticsMaxFileSizeBytes {
                try Data().write(to: diagnosticsLogURL, options: .atomic)
            }

            let handle = try FileHandle(forWritingTo: diagnosticsLogURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
        } catch {
            logger.error("Failed to append AX diagnostics log file: \(error.localizedDescription, privacy: .public)")
        }
    }
}

private func notificationObserverCallback(observer: AXObserver, element: AXUIElement, notification: CFString, context: UnsafeMutableRawPointer?) {
    guard let context = context else { return }
    let controller = Unmanaged<NotificationPlacementController>.fromOpaque(context).takeUnretainedValue()

    Task { @MainActor [weak controller] in
        controller?.handleWindowCreated(element: element)
    }
}

