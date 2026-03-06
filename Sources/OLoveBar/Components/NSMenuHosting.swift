
import SwiftUI
import AppKit

@MainActor
final class NSMenuHosting {
    
    static func menuItem<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> NSMenuItem {
        let hostingView = NSHostingView(rootView: content())
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        
        let size = hostingView.fittingSize
        hostingView.frame = NSRect(origin: .zero, size: size)
        
        let menuItem = NSMenuItem()
        menuItem.view = hostingView
        
        return menuItem
    }

    
    static func menu(
        items: [MenuItemData],
        rootItems: [MenuItemData],
        isHelpMenu: Bool,
        onAction: @escaping (MenuItemData) -> Void
    ) -> NSMenu {
        let menu = NSMenu()

        if isHelpMenu {
            
            let index = buildHelpIndex(from: rootItems)

            let searchItem = NSMenuItem()
            
            let searchContainer = NSView(frame: NSRect(x: 0, y: 0, width: 308, height: 26))
            let searchField = NSSearchField(frame: NSRect(x: 8, y: 3, width: 308, height: 20))
            searchField.placeholderString = "Search"
            searchField.sendsSearchStringImmediately = true
            searchField.sendsWholeSearchString = true
            searchField.focusRingType = .none
            searchContainer.addSubview(searchField)
            searchItem.view = searchContainer
            menu.addItem(searchItem)


            let helpStartIndex = menu.items.count
            for item in items {
                if item.isSeparator {
                    menu.addItem(.separator())
                } else if let submenu = item.submenu, !submenu.isEmpty {
                    let menuItem = NSMenuItem(title: item.title, action: nil, keyEquivalent: item.keyEquivalent.lowercased())
                    menuItem.keyEquivalentModifierMask = item.keyModifiers
                    menuItem.submenu = self.menu(items: submenu, rootItems: rootItems, isHelpMenu: false, onAction: onAction)
                    menu.addItem(menuItem)
                } else {
                    let target = MenuItemTarget(item: item, action: onAction)
                    let menuItem = NSMenuItem(title: item.title, action: #selector(MenuItemTarget.performAction(_:)), keyEquivalent: item.keyEquivalent.lowercased())
                    menuItem.keyEquivalentModifierMask = item.keyModifiers
                    menuItem.target = target
                    objc_setAssociatedObject(menuItem, "target", target, .OBJC_ASSOCIATION_RETAIN)
                    menu.addItem(menuItem)
                }
            }
            let defaultHelpItems = Array(menu.items[helpStartIndex..<menu.items.count])


            menu.minimumWidth = menu.size.width

            let handler = HelpSearchHandler(
                index: index,
                menu: menu,
                searchField: searchField,
                onAction: onAction,
                defaultItems: defaultHelpItems
            )
            objc_setAssociatedObject(searchField, "helpSearchHandler", handler, .OBJC_ASSOCIATION_RETAIN)

 
            handler.updateResults(for: "")

            return menu
        } else {
    
            for item in items {
                if item.isSeparator {
                    menu.addItem(.separator())
                } else if let submenu = item.submenu, !submenu.isEmpty {
                    let menuItem = NSMenuItem(title: item.title, action: nil, keyEquivalent: item.keyEquivalent.lowercased())
                    menuItem.keyEquivalentModifierMask = item.keyModifiers
                    menuItem.submenu = self.menu(items: submenu, rootItems: rootItems, isHelpMenu: false, onAction: onAction)
                    menu.addItem(menuItem)
                } else {
                    let target = MenuItemTarget(item: item, action: onAction)
                    let menuItem = NSMenuItem(title: item.title, action: #selector(MenuItemTarget.performAction(_:)), keyEquivalent: item.keyEquivalent.lowercased())
                    menuItem.keyEquivalentModifierMask = item.keyModifiers
                    menuItem.target = target
                    objc_setAssociatedObject(menuItem, "target", target, .OBJC_ASSOCIATION_RETAIN)
                    menu.addItem(menuItem)
                }
            }

            return menu
        }
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

// MARK: - Help search support


private func buildHelpIndex(from rootItems: [MenuItemData]) -> [(path: String, item: MenuItemData)] {
    var result: [(String, MenuItemData)] = []

    func walk(items: [MenuItemData], path: [String]) {
        for item in items {
            guard !item.isSeparator else { continue }
            let newPath = path + [item.title]
            let pathString = newPath.joined(separator: " ▸ ")
            result.append((pathString, item))

            if let submenu = item.submenu, !submenu.isEmpty {
                walk(items: submenu, path: newPath)
            }
        }
    }

    walk(items: rootItems, path: [])
    return result
}

@MainActor
private final class HelpSearchHandler: NSObject, NSSearchFieldDelegate {
    private let index: [(path: String, item: MenuItemData)]
    private weak var menu: NSMenu?
    private weak var searchField: NSSearchField?
    private let onAction: (MenuItemData) -> Void
    private let defaultItems: [NSMenuItem]

    init(
        index: [(path: String, item: MenuItemData)],
        menu: NSMenu,
        searchField: NSSearchField,
        onAction: @escaping (MenuItemData) -> Void,
        defaultItems: [NSMenuItem]
    ) {
        self.index = index
        self.menu = menu
        self.searchField = searchField
        self.onAction = onAction
        self.defaultItems = defaultItems
        super.init()

        searchField.delegate = self
    }

    func controlTextDidChange(_ notification: Notification) {
        guard let field = notification.object as? NSSearchField else { return }
        updateResults(for: field.stringValue)
    }

    func updateResults(for query: String) {
        guard let menu else { return }


        while menu.items.count > 1 {
            menu.removeItem(at: 1)
        }

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {

            for item in defaultItems {
                menu.addItem(item)
            }
            return
        }

        let lowercasedQuery = trimmed.lowercased()
        let matches = index.filter { $0.path.lowercased().contains(lowercasedQuery) }
        let limited = matches.prefix(25)

        if limited.isEmpty {
            let noResults = NSMenuItem(title: "No matches", action: nil, keyEquivalent: "")
            noResults.isEnabled = false
            menu.addItem(noResults)
            return
        }

        for match in limited {
            let displayTitle = clippedTitle(for: match.path)
            let item = NSMenuItem(
                title: displayTitle,
                action: #selector(HelpSearchHandler.resultSelected(_:)),
                keyEquivalent: match.item.keyEquivalent.lowercased()
            )
            item.keyEquivalentModifierMask = match.item.keyModifiers
            item.target = self
            objc_setAssociatedObject(item, "helpSearchItem", match.item, .OBJC_ASSOCIATION_RETAIN)
            menu.addItem(item)
        }
    }

    @objc private func resultSelected(_ sender: NSMenuItem) {
        guard let menuItem = objc_getAssociatedObject(sender, "helpSearchItem") as? MenuItemData else { return }
        onAction(menuItem)
    }
}


private func clippedTitle(for path: String, limit: Int = 40) -> String {
    guard path.count > limit else { return path }
    let endIndex = path.index(path.startIndex, offsetBy: max(limit - 1, 0))
    return String(path[..<endIndex]) + "…"
}
