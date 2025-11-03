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

    nonisolated(unsafe) private var observer: NSObjectProtocol?

    init() {
        update()
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.update()
            }
        }
    }

    deinit {
        if let observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }


    func update() {
        if let app = NSWorkspace.shared.frontmostApplication {
            let name = app.localizedName ?? ""
            let bid = app.bundleIdentifier ?? ""
            if self.appName != name {
                self.appName = name
                self.bundleID = bid
                self.menuItems = extractMenuItems()
                debug("App changed: \(name), MenuItems count: \(menuItems.count)")
            }
        } else {
            self.appName = "None"
            self.bundleID = ""
            self.menuItems = []
        }
    }
    
    func performAction(for item: MenuItemData) {
        guard let element = item.element else { return }
        AXUIElementPerformAction(element, kAXPressAction as CFString)
        debug("Performed action for: \(item.title)")
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