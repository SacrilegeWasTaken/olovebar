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
        }

        ensureMenuItemsLoaded(force: forceReload || appChanged)
    }

    func ensureMenuItemsLoaded(force: Bool = false) {
        guard force || menuItems.isEmpty || bundleID != lastLoadedBundleID else { return }

        menuLoadTask?.cancel()
        menuLoadTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while true {
                debug("Getting app menus")
                let items = self.extractMenuItems()
                if !items.isEmpty {
                    self.menuItems = items
                    self.lastLoadedBundleID = self.bundleID
                    debug("Menu cache updated: \(self.appName), MenuItems count: \(items.count)")
                    break
                }

                guard !Task.isCancelled else { return }
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }
    
    func performAction(for item: MenuItemData) {
        // Сначала пытаемся выполнить действие с текущим элементом
        var workingElement: AXUIElement? = item.element
        
        // Если элемента нет, пытаемся переполучить его синхронно
        if workingElement == nil {
            debug("⚠️ Element nil for '\(item.title)', attempting to reload...")
            if let freshElement = refreshMenuItemElement(for: item) {
                workingElement = freshElement
                debug("✅ Successfully reloaded element for '\(item.title)'")
            } else {
                debug("❌ Could not reload element for '\(item.title)'")
                ensureMenuItemsLoaded(force: true) // Обновляем кэш асинхронно для будущих кликов
                return
            }
        }
        
        guard let element = workingElement else {
            return
        }
        
        // Проверяем isEnabled динамически, но не блокируем выполнение если не удалось проверить
        var enabledValue: AnyObject?
        let enabledCheckResult = AXUIElementCopyAttributeValue(element, kAXEnabledAttribute as CFString, &enabledValue)
        
        if enabledCheckResult == .success, let enabled = enabledValue as? Bool, !enabled {
            debug("⚠️ Cannot perform action for '\(item.title)': item is currently disabled")
            return
        }
        
        // Пытаемся выполнить действие
        let result = AXUIElementPerformAction(element, kAXPressAction as CFString)
        
        if result == .success {
            debug("✅ Performed action for: \(item.title)")
        } else {
            // При любой ошибке пытаемся переполучить элемент и повторить попытку
            let errorCode = result.rawValue
            debug("🔄 Action failed for '\(item.title)' (code: \(errorCode)), reloading element and retrying...")
            
            if let freshElement = refreshMenuItemElement(for: item) {
                // Пробуем снова с новым элементом
                let retryResult = AXUIElementPerformAction(freshElement, kAXPressAction as CFString)
                if retryResult == .success {
                    debug("✅ Successfully performed action for '\(item.title)' after reload")
                    // Обновляем кэш для будущих кликов
                    ensureMenuItemsLoaded(force: true)
                } else {
                    debug("❌ Still failed after reload for '\(item.title)': AXError = \(retryResult.rawValue)")
                    ensureMenuItemsLoaded(force: true)
                }
            } else {
                debug("❌ Could not reload element for '\(item.title)', refreshing full menu cache...")
                // Если не удалось найти элемент, обновляем всё меню синхронно
                let freshItems = extractMenuItems()
                if !freshItems.isEmpty {
                    menuItems = freshItems
                    lastLoadedBundleID = bundleID
                    // Пытаемся найти элемент в обновленном кэше
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
    
    /// Синхронно переполучает элемент из текущего меню приложения по title
    private func refreshMenuItemElement(for item: MenuItemData) -> AXUIElement? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        
        var menuBar: AnyObject?
        guard AXUIElementCopyAttributeValue(appElement, kAXMenuBarAttribute as CFString, &menuBar) == .success,
              let menuBarElement = menuBar as! AXUIElement? else { return nil }
        
        var children: AnyObject?
        guard AXUIElementCopyAttributeValue(menuBarElement, kAXChildrenAttribute as CFString, &children) == .success,
              let items = children as? [AXUIElement] else { return nil }
        
        // Ищем элемент в основном меню и подменю по title
        for menuItem in items {
            if let found = findElementByTitle(in: menuItem, title: item.title) {
                return found
            }
        }
        
        return nil
    }
    
    /// Рекурсивно ищет элемент по title в меню и подменю
    private func findElementByTitle(in element: AXUIElement, title: String) -> AXUIElement? {
        var titleValue: AnyObject?
        if AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleValue) == .success,
           let elementTitle = titleValue as? String, elementTitle == title {
            return element
        }
        
        // Проверяем подменю
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
    
    /// Находит элемент в массиве MenuItemData по title (рекурсивно ищет в подменю)
    private func findItemInMenu(items: [MenuItemData], matching target: MenuItemData) -> MenuItemData? {
        for item in items {
            // Проверяем точное совпадение title
            if item.title == target.title {
                return item
            }
            // Ищем в подменю
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
              let menuBarElement = menuBar as! AXUIElement? else {
            debug("No menuBar for \(app.localizedName ?? "")")
            return []
        }
        
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