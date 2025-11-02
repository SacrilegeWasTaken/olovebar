
import SwiftUI
import AppKit

/// Контейнер для размещения SwiftUI View в NSMenu
@MainActor
final class NSMenuHosting {
    
    /// Создает NSMenuItem с SwiftUI View
    static func menuItem<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> NSMenuItem {
        let hostingView = NSHostingView(rootView: content())
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        
        // Принудительно устанавливаем размер
        let size = hostingView.fittingSize
        hostingView.frame = NSRect(origin: .zero, size: size)
        
        let menuItem = NSMenuItem()
        menuItem.view = hostingView
        
        return menuItem
    }

    
    /// Создает NSMenu с SwiftUI View
    static func menu(items: [MenuItemData], onAction: @escaping (MenuItemData) -> Void) -> NSMenu {
        let menu = NSMenu()
        
        for item in items {
            if item.isSeparator {
                menu.addItem(.separator())
            } else if let submenu = item.submenu, !submenu.isEmpty {
                let menuItem = NSMenuItem(title: item.title, action: nil, keyEquivalent: "")
                menuItem.submenu = self.menu(items: submenu, onAction: onAction)
                menu.addItem(menuItem)
            } else {
                let target = MenuItemTarget(item: item, action: onAction)
                let menuItem = NSMenuItem(title: item.title, action: #selector(MenuItemTarget.performAction(_:)), keyEquivalent: "")
                menuItem.target = target
                objc_setAssociatedObject(menuItem, "target", target, .OBJC_ASSOCIATION_RETAIN)
                menu.addItem(menuItem)
            }
        }
        
        return menu
    }

}


private class MenuItemTarget: NSObject {
    let item: MenuItemData
    let action: (MenuItemData) -> Void
    
    init(item: MenuItemData, action: @escaping (MenuItemData) -> Void) {
        self.item = item
        self.action = action
    }
    
    @objc func performAction(_ sender: NSMenuItem) {
        action(item)
    }
}
