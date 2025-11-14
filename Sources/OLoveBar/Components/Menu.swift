import SwiftUI
import AppKit

/// Удобный компонент для создания NSMenu из SwiftUI
@MainActor
struct Menu {
    
    /// Создает и показывает NSMenu относительно указанной view
    /// - Parameters:
    ///   - anchor: View относительно которой показывать меню
    ///   - builder: Билдер для создания пунктов меню
    static func show<Anchor: View>(
        relativeTo anchor: Anchor,
        at point: CGPoint = .zero,
        @MenuBuilder builder: () -> [MenuItem]
    ) {
        let items = builder()
        let menu = buildNSMenu(from: items)
        
        // Находим NSView для якоря
        if let window = NSApp.windows.first(where: { $0.isKeyWindow || $0.isVisible }),
           let contentView = window.contentView {
            menu.popUp(positioning: nil, at: point, in: contentView)
        }
    }
    
    /// Создает NSMenu из массива MenuItem
    @MainActor
    static func buildNSMenu(from items: [MenuItem]) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        
        for item in items {
            menu.addItem(item.asNSMenuItem())
        }
        
        return menu
    }
}

// MARK: - MenuItem

/// Описание пункта меню
struct MenuItem {
    let title: String
    let action: (() -> Void)?
    let keyEquivalent: String
    let isEnabled: Bool
    var isSeparator: Bool
    let submenu: [MenuItem]?
    let view: AnyView?
    
    init(
        title: String = "",
        keyEquivalent: String = "",
        isEnabled: Bool = true,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.action = action
        self.keyEquivalent = keyEquivalent
        self.isEnabled = isEnabled
        self.isSeparator = false
        self.submenu = nil
        self.view = nil
    }
    
    init(submenu title: String, items: [MenuItem]) {
        self.title = title
        self.action = nil
        self.keyEquivalent = ""
        self.isEnabled = true
        self.isSeparator = false
        self.submenu = items
        self.view = nil
    }
    
    init<Content: View>(view: Content) {
        self.title = ""
        self.action = nil
        self.keyEquivalent = ""
        self.isEnabled = true
        self.isSeparator = false
        self.submenu = nil
        self.view = AnyView(view)
    }
    
    static var separator: MenuItem {
        var item = MenuItem(title: "", action: nil)
        item.isSeparator = true
        return item
    }
    
    private func asSeparator() -> MenuItem {
        var item = self
        item.isSeparator = true
        return item
    }
    
    @MainActor
    func asNSMenuItem() -> NSMenuItem {
        if isSeparator {
            return .separator()
        }
        
        if let view = view {
            let menuItem = NSMenuItem()
            let hostingView = NSHostingView(rootView: view)
            hostingView.translatesAutoresizingMaskIntoConstraints = false
            let size = hostingView.fittingSize
            hostingView.frame = NSRect(origin: .zero, size: size)
            menuItem.view = hostingView
            return menuItem
        }
        
        let menuItem = NSMenuItem(
            title: title,
            action: action != nil ? #selector(MenuItemTarget.performAction) : nil,
            keyEquivalent: keyEquivalent
        )
        menuItem.isEnabled = isEnabled
        
        if let action = action {
            let target = MenuItemTarget(action: action)
            menuItem.target = target
            objc_setAssociatedObject(menuItem, "target", target, .OBJC_ASSOCIATION_RETAIN)
        }
        
        if let submenuItems = submenu {
            let submenu = NSMenu()
            submenu.autoenablesItems = false
            for item in submenuItems {
                submenu.addItem(item.asNSMenuItem())
            }
            menuItem.submenu = submenu
        }
        
        return menuItem
    }
}

// MARK: - MenuBuilder

@resultBuilder
struct MenuBuilder {
    static func buildBlock(_ components: MenuItem...) -> [MenuItem] {
        components
    }
    
    static func buildBlock(_ components: [MenuItem]...) -> [MenuItem] {
        components.flatMap { $0 }
    }
    
    static func buildOptional(_ component: [MenuItem]?) -> [MenuItem] {
        component ?? []
    }
    
    static func buildEither(first component: [MenuItem]) -> [MenuItem] {
        component
    }
    
    static func buildEither(second component: [MenuItem]) -> [MenuItem] {
        component
    }
    
    static func buildArray(_ components: [[MenuItem]]) -> [MenuItem] {
        components.flatMap { $0 }
    }
}

// MARK: - MenuItemTarget

private class MenuItemTarget: NSObject {
    let action: () -> Void
    
    init(action: @escaping () -> Void) {
        self.action = action
    }
    
    @objc func performAction() {
        action()
    }
}
