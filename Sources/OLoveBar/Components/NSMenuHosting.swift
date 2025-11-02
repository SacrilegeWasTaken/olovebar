
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
    static func menu<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> NSMenu {
        let menu = NSMenu()
        menu.addItem(menuItem(content: content))
        return menu
    }
}