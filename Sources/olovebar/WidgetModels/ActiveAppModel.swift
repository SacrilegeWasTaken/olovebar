import SwiftUI
import Foundation
import Utilities
import MacroAPI
import AppKit

public struct MenuItemData: Identifiable, Hashable {
    public let id = UUID()
    public let title: String
    public let submenu: [MenuItemData]?
    public let action: Selector?
    public let keyEquivalent: String
    public let isEnabled: Bool
    public let isSeparator: Bool
    let element: AXUIElement?
    
    public static func == (lhs: MenuItemData, rhs: MenuItemData) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

@MainActor
@LogFunctions(.Widgets([.activeAppModel]))
public class ActiveAppModel: ObservableObject {
    @Published var bundleID: String = ""
    @Published var appName: String = ""
    @Published var menuItems: [MenuItemData] = []

    nonisolated(unsafe) private var timer: Timer?

    public init() {
        startTimer()
    }

    deinit {
        timer?.invalidate()
    }

    func startTimer() {
        timer?.invalidate()
        update()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.update()
            }
        }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
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
            keyEquivalent: "",
            isEnabled: true,
            isSeparator: false,
            element: element
        )
    }
}