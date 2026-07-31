import SwiftUI
import Foundation
import Utilities
import MacroAPI
import AppKit
@preconcurrency import ApplicationServices

struct MenuItemData: Identifiable, Hashable, @unchecked Sendable {
    /// Stable identity: the title path from the menu bar root (e.g. "File>Open…").
    let id: String
    let title: String
    let submenu: [MenuItemData]?
    let keyEquivalent: String
    let keyModifiers: NSEvent.ModifierFlags
    let isEnabled: Bool
    let isSeparator: Bool
    let element: AXUIElement?

    static func == (lhs: MenuItemData, rhs: MenuItemData) -> Bool {
        lhs.id == rhs.id
            && lhs.title == rhs.title
            && lhs.keyEquivalent == rhs.keyEquivalent
            && lhs.keyModifiers == rhs.keyModifiers
            && lhs.isEnabled == rhs.isEnabled
            && lhs.isSeparator == rhs.isSeparator
            && lhs.submenu == rhs.submenu
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Blocking AX menu-tree access. Every function here performs synchronous IPC
/// to the target application and must only run on `ActiveAppModel.axQueue`,
/// never on the main thread.
private enum MenuTreeReader {
    /// Cap on how long a single AX call may block on an unresponsive app.
    static let messagingTimeout: Float = 0.5
    static let maxSubmenuDepth = 4

    static func extractMenuItems(pid: pid_t) -> [MenuItemData] {
        let appElement = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(appElement, messagingTimeout)

        guard let menuBarItems = menuBarChildren(of: appElement) else { return [] }

        var result: [MenuItemData] = []
        for (index, item) in menuBarItems.enumerated() {
            if index == 0 { continue } // skip the application menu
            if let data = convertMenuItem(item, path: "", depth: 0) {
                result.append(data)
            }
        }
        return result
    }

    static func refreshElement(pid: pid_t, title: String) -> AXUIElement? {
        let appElement = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(appElement, messagingTimeout)

        guard let items = menuBarChildren(of: appElement) else { return nil }
        for menuItem in items {
            if let found = findElementByTitle(in: menuItem, title: title, depth: 0) {
                return found
            }
        }
        return nil
    }

    static func isEnabled(_ element: AXUIElement) -> Bool {
        var enabledValue: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXEnabledAttribute as CFString, &enabledValue) == .success,
              let enabled = enabledValue as? Bool else {
            return true
        }
        return enabled
    }

    static func press(_ element: AXUIElement) -> AXError {
        AXUIElementPerformAction(element, kAXPressAction as CFString)
    }

    private static func menuBarChildren(of appElement: AXUIElement) -> [AXUIElement]? {
        var menuBar: AnyObject?
        guard AXUIElementCopyAttributeValue(appElement, kAXMenuBarAttribute as CFString, &menuBar) == .success,
              let menuBarObj = menuBar else {
            return nil
        }
        // AXUIElement is a CF type; bridge always succeeds when non-nil.
        let menuBarElement = menuBarObj as! AXUIElement

        var children: AnyObject?
        guard AXUIElementCopyAttributeValue(menuBarElement, kAXChildrenAttribute as CFString, &children) == .success,
              let items = children as? [AXUIElement] else {
            return nil
        }
        return items
    }

    private static func convertMenuItem(_ element: AXUIElement, path: String, depth: Int) -> MenuItemData? {
        var titleValue: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleValue) == .success,
              let title = titleValue as? String else { return nil }

        let itemPath = path.isEmpty ? title : "\(path)>\(title)"

        var keyEquivValue: AnyObject?
        let keyEquiv = (AXUIElementCopyAttributeValue(element, "AXMenuItemCmdChar" as CFString, &keyEquivValue) == .success)
            ? (keyEquivValue as? String ?? "")
            : ""

        var modifiers: NSEvent.ModifierFlags = []
        if !keyEquiv.isEmpty {
            var modifiersValue: AnyObject?
            let modResult = AXUIElementCopyAttributeValue(element, "AXMenuItemCmdModifiers" as CFString, &modifiersValue)
            if modResult == .success, let modInt = modifiersValue as? Int {
                // AX modifier bits: 1 = Shift, 2 = Option, 4 = Control, 8 = Function.
                // Command is implied unless the Function bit is set.
                if modInt & 1 != 0 { modifiers.insert(.shift) }
                if modInt & 2 != 0 { modifiers.insert(.option) }
                if modInt & 4 != 0 { modifiers.insert(.control) }
                if modInt & 8 == 0 { modifiers.insert(.command) }
            } else {
                modifiers = .command
            }
        }

        var enabledValue: AnyObject?
        let isEnabled = (AXUIElementCopyAttributeValue(element, kAXEnabledAttribute as CFString, &enabledValue) == .success)
            ? (enabledValue as? Bool ?? true)
            : true

        let isSeparator = title.isEmpty || title == "-"

        var submenu: [MenuItemData]? = nil
        if depth < maxSubmenuDepth {
            var childrenValue: AnyObject?
            if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenValue) == .success,
               let children = childrenValue as? [AXUIElement],
               let firstChild = children.first {
                var menuChildren: AnyObject?
                if AXUIElementCopyAttributeValue(firstChild, kAXChildrenAttribute as CFString, &menuChildren) == .success,
                   let menuItems = menuChildren as? [AXUIElement] {
                    submenu = menuItems.compactMap { convertMenuItem($0, path: itemPath, depth: depth + 1) }
                }
            }
        }

        return MenuItemData(
            id: itemPath,
            title: title,
            submenu: submenu,
            keyEquivalent: keyEquiv,
            keyModifiers: modifiers,
            isEnabled: isEnabled,
            isSeparator: isSeparator,
            element: element
        )
    }

    private static func findElementByTitle(in element: AXUIElement, title: String, depth: Int) -> AXUIElement? {
        var titleValue: AnyObject?
        if AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleValue) == .success,
           let elementTitle = titleValue as? String, elementTitle == title {
            return element
        }

        guard depth < maxSubmenuDepth else { return nil }

        var childrenValue: AnyObject?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenValue) == .success,
           let children = childrenValue as? [AXUIElement],
           let firstChild = children.first {
            var menuChildren: AnyObject?
            if AXUIElementCopyAttributeValue(firstChild, kAXChildrenAttribute as CFString, &menuChildren) == .success,
               let menuItems = menuChildren as? [AXUIElement] {
                for menuItem in menuItems {
                    if let found = findElementByTitle(in: menuItem, title: title, depth: depth + 1) {
                        return found
                    }
                }
            }
        }

        return nil
    }
}

@MainActor
@LogFunctions(.Widgets([.activeAppModel]))
class ActiveAppModel: ObservableObject {
    @Published var bundleID: String = ""
    @Published var appName: String = ""
    @Published var menuItems: [MenuItemData] = []

    private static let axQueue = DispatchQueue(label: "ActiveAppModel.ax", qos: .userInitiated)

    private var menuLoadTask: Task<Void, Never>?
    private var lastLoadedBundleID: String = ""

    private let maxLaunchStatusChecks = 5
    private let launchStatusCheckDelay: Duration = .milliseconds(500)
    private let maxStabilizationAttempts = 15
    private let stabilizationDelay: Duration = .milliseconds(150)
    private let requiredStableSnapshots = 3

    /// Hard cap on total stabilization time to avoid long AX hammering.
    private let maxStabilizationTime: Duration = .seconds(2)

    init() {
        update()
        setupWorkspaceNotifications()
    }

    deinit {
        menuLoadTask?.cancel()
    }

    private func setupWorkspaceNotifications() {
        let notifications: [Notification.Name] = [
            NSWorkspace.didActivateApplicationNotification,
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didUnhideApplicationNotification,
            NSWorkspace.didHideApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification
        ]

        notifications.forEach { name in
            NSWorkspace.shared.notificationCenter.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.update()
                }
            }
        }
    }

    /// Runs a blocking AX operation on the dedicated background queue.
    private static func onAXQueue<T: Sendable>(_ work: @escaping @Sendable () -> T) async -> T {
        await withCheckedContinuation { continuation in
            axQueue.async {
                continuation.resume(returning: work())
            }
        }
    }

    func update(forceReload: Bool = false) {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            appName = "None"
            bundleID = ""
            menuItems = []
            menuLoadTask?.cancel()
            lastLoadedBundleID = ""
            return
        }

        let name = app.localizedName ?? ""
        let bid = app.bundleIdentifier ?? ""
        let appChanged = bundleID != bid

        appName = name
        bundleID = bid

        if appChanged {
            menuItems = []
            lastLoadedBundleID = ""
        }

        ensureMenuItemsLoaded(force: forceReload || appChanged)
    }

    func ensureMenuItemsLoaded(force: Bool = false) {
        // Avoid restarting the loader when the current cache is still valid.
        guard force || menuItems.isEmpty || bundleID != lastLoadedBundleID else { return }

        // If a loader is already running and we have menu items, do not start another one.
        if menuLoadTask != nil, !menuItems.isEmpty, bundleID == lastLoadedBundleID, !force {
            return
        }

        menuLoadTask?.cancel()
        menuLoadTask = Task { @MainActor [weak self] in
            guard let self else { return }

            let currentBundle = self.bundleID
            let app = NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == currentBundle }
            guard let pid = app?.processIdentifier else { return }

            // Optionally wait for the app to finish launching before hammering AX.
            if let app {
                for _ in 0..<self.maxLaunchStatusChecks {
                    guard !Task.isCancelled else { return }
                    if app.isFinishedLaunching { break }
                    try? await Task.sleep(for: self.launchStatusCheckDelay)
                }
            }

            var lastSnapshot: [MenuItemData] = []
            var stableCount = 0
            let stabilizationStart = ContinuousClock.now

            for attempt in 0..<self.maxStabilizationAttempts {
                guard !Task.isCancelled else { return }

                let elapsed = stabilizationStart.duration(to: .now)
                if elapsed >= self.maxStabilizationTime {
                    info("⚠️ Menu stabilization time budget exceeded for \(self.appName) after \(attempt) attempts")
                    break
                }

                let items = await Self.onAXQueue { MenuTreeReader.extractMenuItems(pid: pid) }
                guard !Task.isCancelled, self.bundleID == currentBundle else { return }

                if !items.isEmpty {
                    let nonSeparatorCount = items.filter { !$0.isSeparator }.count
                    let hasSubmenu = items.contains { ($0.submenu?.isEmpty == false) }

                    // Publish the first non-empty snapshot so the menu appears quickly.
                    if self.menuItems.isEmpty {
                        self.menuItems = items
                        self.lastLoadedBundleID = self.bundleID
                        debug("Menu snapshot filled during stabilization for \(self.appName), items: \(items.count)")
                    }

                    if !lastSnapshot.isEmpty && items.count == lastSnapshot.count {
                        stableCount += 1
                    } else {
                        stableCount = 1
                        lastSnapshot = items
                    }

                    if stableCount >= self.requiredStableSnapshots,
                       (nonSeparatorCount >= 2 || hasSubmenu) {
                        self.menuItems = items
                        self.lastLoadedBundleID = self.bundleID
                        debug("Menu cache stabilized for \(self.appName), items: \(items.count) after \(attempt + 1) attempts")
                        return
                    }
                }

                try? await Task.sleep(for: self.stabilizationDelay)
            }

            if !lastSnapshot.isEmpty {
                info("⚠️ Menu stabilization timed out for \(self.appName), using last snapshot with \(lastSnapshot.count) items")
                self.menuItems = lastSnapshot
                self.lastLoadedBundleID = self.bundleID
            } else {
                info("⚠️ Menu load failed for \(self.appName): no menu items detected after stabilization attempts")
            }
        }
    }

    func performAction(for item: MenuItemData) {
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        let pid = app.processIdentifier
        let title = item.title
        let element = item.element

        Task { @MainActor [weak self] in
            let succeeded = await Self.onAXQueue { () -> Bool in
                var workingElement = element ?? MenuTreeReader.refreshElement(pid: pid, title: title)
                guard var current = workingElement else { return false }

                if !MenuTreeReader.isEnabled(current) {
                    return true // item is disabled: nothing to do, no cache refresh needed
                }

                if MenuTreeReader.press(current) == .success {
                    return true
                }

                // On failure, refetch the element by title and retry once.
                guard let fresh = MenuTreeReader.refreshElement(pid: pid, title: title) else { return false }
                current = fresh
                workingElement = fresh
                return MenuTreeReader.press(current) == .success
            }

            if !succeeded {
                self?.debug("❌ Menu action failed for '\(title)', refreshing menu cache")
                self?.ensureMenuItemsLoaded(force: true)
            }
        }
    }
}
