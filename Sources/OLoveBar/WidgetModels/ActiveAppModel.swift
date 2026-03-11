import SwiftUI
import Foundation
import Utilities
import MacroAPI
import AppKit

 struct MenuItemData: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let submenu: [MenuItemData]?
    let action: Selector?
    let keyEquivalent: String
    let keyModifiers: NSEvent.ModifierFlags
    let isEnabled: Bool
    let isSeparator: Bool
    let element: AXUIElement?
    
    static func == (lhs: MenuItemData, rhs: MenuItemData) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

@MainActor
@LogFunctions(.Widgets([.activeAppModel]))
class ActiveAppModel: ObservableObject {
    @Published var bundleID: String = ""
    @Published var appName: String = ""
    @Published var menuItems: [MenuItemData] = []

    private var menuLoadTask: Task<Void, Never>?
    private var lastLoadedBundleID: String = ""

    private let maxLaunchStatusChecks = 5

    private let launchStatusCheckDelay: Duration = .milliseconds(500)

    private let maxStabilizationAttempts = 15

    private let stabilizationDelay: Duration = .milliseconds(150)
  
    private let requiredStableSnapshots = 3


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

            // Fast initial snapshot so that top menu appears immediately.
            let initialItems = extractMenuItems()
            if !initialItems.isEmpty {
                menuItems = initialItems
                lastLoadedBundleID = bundleID
                debug("Initial menu snapshot loaded for \(appName), items: \(initialItems.count)")
            }
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

            // Try to find a running application that matches current bundle ID.
            let app = NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == currentBundle }

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

            for attempt in 0..<self.maxStabilizationAttempts {
                guard !Task.isCancelled else { return }

                let items = self.extractMenuItems()

                if !items.isEmpty {
                    let nonSeparatorCount = items.filter { !$0.isSeparator }.count
                    let hasSubmenu = items.contains { ($0.submenu?.isEmpty == false) }

                    // If the fast initial snapshot did not populate menuItems, do it now.
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
        // First try to perform an action on the cached AX element.
        var workingElement: AXUIElement? = item.element
        
        // If there is no cached element, try to refetch it synchronously.
        if workingElement == nil {
            debug("⚠️ Element nil for '\(item.title)', attempting to reload...")
            if let freshElement = refreshMenuItemElement(for: item) {
                workingElement = freshElement
                debug("✅ Successfully reloaded element for '\(item.title)'")
            } else {
                debug("❌ Could not reload element for '\(item.title)'")
                ensureMenuItemsLoaded(force: true) // Refresh cache asynchronously for future clicks.
                return
            }
        }
        
        guard let element = workingElement else {
            return
        }
        
        // Check kAXEnabledAttribute dynamically, but do not treat errors as fatal.
        var enabledValue: AnyObject?
        let enabledCheckResult = AXUIElementCopyAttributeValue(element, kAXEnabledAttribute as CFString, &enabledValue)
        
        if enabledCheckResult == .success, let enabled = enabledValue as? Bool, !enabled {
            debug("⚠️ Cannot perform action for '\(item.title)': item is currently disabled")
            return
        }
        
        // Try to perform kAXPressAction.
        let result = AXUIElementPerformAction(element, kAXPressAction as CFString)
        
        if result == .success {
            debug("✅ Performed action for: \(item.title)")
        } else {
            // On any error, try to refetch the element and retry.
            let errorCode = result.rawValue
            debug("🔄 Action failed for '\(item.title)' (code: \(errorCode)), reloading element and retrying...")
            
            if let freshElement = refreshMenuItemElement(for: item) {
                // Retry with refreshed element.
                let retryResult = AXUIElementPerformAction(freshElement, kAXPressAction as CFString)
                if retryResult == .success {
                    debug("✅ Successfully performed action for '\(item.title)' after reload")
                    // Refresh cache for future clicks.
                    ensureMenuItemsLoaded(force: true)
                } else {
                    debug("❌ Still failed after reload for '\(item.title)': AXError = \(retryResult.rawValue)")
                    ensureMenuItemsLoaded(force: true)
                }
            } else {
                debug("❌ Could not reload element for '\(item.title)', refreshing full menu cache...")
                // As a last resort, synchronously reload the whole menu tree.
                let freshItems = extractMenuItems()
                if !freshItems.isEmpty {
                    menuItems = freshItems
                    lastLoadedBundleID = bundleID
                    // Try to find matching item within freshly extracted tree.
                    if let updatedItem = findItemInMenu(items: freshItems, matching: item) {
                        if let updatedElement = updatedItem.element {
                            let finalResult = AXUIElementPerformAction(updatedElement, kAXPressAction as CFString)
                            if finalResult == .success {
                                debug("✅ Successfully performed action for '\(item.title)' after full menu reload")
                            } else {
                                debug("❌ Failed even after full menu reload: AXError = \(finalResult.rawValue)")
                            }
                        }
                    }
                }
            }
        }
    }
    
    /// Synchronously re-fetches an AX element for a menu item by its title.
    private func refreshMenuItemElement(for item: MenuItemData) -> AXUIElement? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        
        var menuBar: AnyObject?
        guard AXUIElementCopyAttributeValue(appElement, kAXMenuBarAttribute as CFString, &menuBar) == .success,
              let menuBarObj = menuBar else { return nil }
        let menuBarElement = menuBarObj as! AXUIElement
        
        var children: AnyObject?
        guard AXUIElementCopyAttributeValue(menuBarElement, kAXChildrenAttribute as CFString, &children) == .success,
              let items = children as? [AXUIElement] else { return nil }
        
        // Search through main menu and its submenus by title.
        for menuItem in items {
            if let found = findElementByTitle(in: menuItem, title: item.title) {
                return found
            }
        }
        
        return nil
    }
    
    /// Recursively searches for a menu element with the given title.
    private func findElementByTitle(in element: AXUIElement, title: String) -> AXUIElement? {
        var titleValue: AnyObject?
        if AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleValue) == .success,
           let elementTitle = titleValue as? String, elementTitle == title {
            return element
        }
        
        // Traverse into submenu if present.
        var childrenValue: AnyObject?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenValue) == .success,
           let children = childrenValue as? [AXUIElement], children.count > 0 {
            if let firstChild = children.first {
                var menuChildren: AnyObject?
                if AXUIElementCopyAttributeValue(firstChild, kAXChildrenAttribute as CFString, &menuChildren) == .success,
                   let menuItems = menuChildren as? [AXUIElement] {
                    for menuItem in menuItems {
                        if let found = findElementByTitle(in: menuItem, title: title) {
                            return found
                        }
                    }
                }
            }
        }
        
        return nil
    }
    
    /// Finds a MenuItemData in a tree by matching title (recursively walks submenus).
    private func findItemInMenu(items: [MenuItemData], matching target: MenuItemData) -> MenuItemData? {
        for item in items {
            // Prefer exact title match.
            if item.title == target.title {
                return item
            }
            // Recurse into submenu.
            if let submenu = item.submenu {
                if let found = findItemInMenu(items: submenu, matching: target) {
                    return found
                }
            }
        }
        return nil
    }
    
    private func extractMenuItems() -> [MenuItemData] {
        guard let app = NSWorkspace.shared.frontmostApplication else { return [] }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        
        var menuBar: AnyObject?
        guard AXUIElementCopyAttributeValue(appElement, kAXMenuBarAttribute as CFString, &menuBar) == .success,
              let menuBarObj = menuBar else {
            debug("No menuBar for \(app.localizedName ?? "")")
            return []
        }
        let menuBarElement = menuBarObj as! AXUIElement
        
        var children: AnyObject?
        guard AXUIElementCopyAttributeValue(menuBarElement, kAXChildrenAttribute as CFString, &children) == .success,
              let items = children as? [AXUIElement] else {
            debug("No menuBar children")
            return []
        }
        
        debug("MenuBar items: \(items.count)")
        var result: [MenuItemData] = []
        for (index, item) in items.enumerated() {
            if index == 0 { continue }
            if let data = convertAXMenuItem(item) {
                result.append(data)
            }
        }
        debug("Extracted \(result.count) menu items")
        return result
    }

    private func convertAXMenuItem(_ element: AXUIElement) -> MenuItemData? {
        var titleValue: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleValue) == .success,
              let title = titleValue as? String else { return nil }
        
        var keyEquivValue: AnyObject?
        let keyEquiv = (AXUIElementCopyAttributeValue(element, "AXMenuItemCmdChar" as CFString, &keyEquivValue) == .success) ? (keyEquivValue as? String ?? "") : ""
        
        var modifiersValue: AnyObject?
        var modifiers: NSEvent.ModifierFlags = []
        if !keyEquiv.isEmpty {
            let modResult = AXUIElementCopyAttributeValue(element, "AXMenuItemCmdModifiers" as CFString, &modifiersValue)
            if modResult == .success, let modInt = modifiersValue as? Int {
                // Map AX modifier bits to NSEvent.ModifierFlags
                // Bit 0 (1): Shift
                // Bit 1 (2): Option
                // Bit 2 (4): Control  
                // Bit 3 (8): Function
                if modInt & 1 != 0 { modifiers.insert(.shift) }
                if modInt & 2 != 0 { modifiers.insert(.option) }
                if modInt & 4 != 0 { modifiers.insert(.control) }
                // if modInt & 8 != 0 { modifiers.insert(.function) }
                // Command is included unless Function is set
                if modInt & 8 == 0 {
                    modifiers.insert(.command)
                }
            } else {
                modifiers = .command
            }
        }
        
        var enabledValue: AnyObject?
        let isEnabled = (AXUIElementCopyAttributeValue(element, kAXEnabledAttribute as CFString, &enabledValue) == .success) ? (enabledValue as? Bool ?? true) : true
        
        let isSeparator = title.isEmpty || title == "-"
        
        var childrenValue: AnyObject?
        var submenu: [MenuItemData]? = nil
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenValue) == .success,
           let children = childrenValue as? [AXUIElement], children.count > 0 {
            if let firstChild = children.first {
                var menuChildren: AnyObject?
                if AXUIElementCopyAttributeValue(firstChild, kAXChildrenAttribute as CFString, &menuChildren) == .success,
                   let menuItems = menuChildren as? [AXUIElement] {
                    submenu = menuItems.compactMap { convertAXMenuItem($0) }
                }
            }
        }
        
        return MenuItemData(
            title: title,
            submenu: submenu,
            action: nil,
            keyEquivalent: keyEquiv,
            keyModifiers: modifiers,
            isEnabled: isEnabled,
            isSeparator: isSeparator,
            element: element
        )
    }
}