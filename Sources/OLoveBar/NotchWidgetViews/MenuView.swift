import SwiftUI
import MacroAPI

fileprivate struct WidgetPositionKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

@MainActor
@LogFunctions(.OLoveBar)
fileprivate class MenuStateManager: ObservableObject {

    static              var shared:         MenuStateManager = MenuStateManager()
    @ObservedObject     var notchState:     NotchWindowState = .shared
    @Published          var hoveredPath:    [UUID] = []
    private             var menuCloseTask:  Task<Void, Never>?


    func isInPath(_ itemID: UUID) -> Bool {
        hoveredPath.contains(where: { $0 == itemID })
    }
    func addToPath(_ itemID: UUID) {
        hoveredPath.append(itemID)
    }
    func removeFromPath(_ itemID: UUID) {
        hoveredPath.removeAll { $0 == itemID }
    }
    func resetPath() {
        hoveredPath = []
    }
    func isFirst(_ itemID: UUID) -> Bool {
        hoveredPath.first == itemID
    }

    /// ### Setting schedule to reset menu items path
    /// `Task.cancel()` not stopping already started `Task.sleep()` immediately, so we're checking `Task.isCancelled`.
    func setMenuCloseTaskSchedule() {
        menuCloseTask?.cancel()
        menuCloseTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(0.1))
            guard let self = self, !Task.isCancelled else { return }
            self.resetPath()
        }
    }


    func cancelMenuCloseTask() {
        menuCloseTask?.cancel()
        menuCloseTask = nil
    }
}


struct MenuWidgetView: View {
    let config: Config

    @ObservedObject var activeAppModel = GlobalModels.shared.activeAppModel

    var body: some View {
        ForEach(activeAppModel.menuItems) { item in
            MenuButtonView(
                item: item,
                config: config
            )
        }
    }
}


fileprivate struct MenuButtonView: View {
    let item: MenuItemData
    let config: Config


    @ObservedObject var activeAppModel = GlobalModels.shared.activeAppModel
    @ObservedObject var menuState = MenuStateManager.shared
    

    private var isHighlighted: Bool {
        menuState.isFirst(item.id) && menuState.notchState.isFullyExpanded
    }
    @State private var widgetMiddle: CGFloat = .zero


    var body: some View {
        Button(action: {
            if item.submenu != nil {
                showSubmenu()
            } else {
                activeAppModel.performAction(for: item)
                menuState.resetPath()
            }
        }) {
            Text(item.title)
                .foregroundColor(.white)
                .font(.system(size: 12))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isHighlighted ? Color.accentColor : Color.clear)
                .cornerRadius(config.widgetCornerRadius)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.1), value: isHighlighted)
        .onHover { hovering in
            guard menuState.notchState.isFullyExpanded else { return }
            if hovering {
                menuState.cancelMenuCloseTask()
                if menuState.hoveredPath.first != item.id {
                    menuState.resetPath()
                    menuState.addToPath(item.id)
                }
            } else {
                menuState.setMenuCloseTaskSchedule()
            }
        }
        .background(
            GeometryReader { geo in 
                Color.clear
                    .preference(key: WidgetPositionKey.self, value: geo.frame(in: .global).midX)
            }
        )
        .onPreferenceChange(WidgetPositionKey.self) { value in
            widgetMiddle = value
        }
    }


    private func showSubmenu() {
        guard let submenu = item.submenu, !submenu.isEmpty else { return }
        
        let menu = NSMenuHosting.menu(items: submenu) { [activeAppModel] subitem in
            activeAppModel.performAction(for: subitem)
        }
        
        if let window = NSApp.windows.first(where: { $0 is NotchWindow }) as? NotchWindow,
        let contentView = window.contentView {
            let menuWidth = menu.size.width
            let y: CGFloat = -10
            let x = widgetMiddle - (menuWidth / 2)
            menu.popUp(positioning: nil, at: CGPoint(x: x, y: y), in: contentView)
        }
    }
}


fileprivate struct SubMenuView: View {
    let item: MenuItemData
    let config: Config

    @ObservedObject var activeAppModel = GlobalModels.shared.activeAppModel
    @ObservedObject var menuState = MenuStateManager.shared

    @ViewBuilder
    var body: some View {
        if let submenu = item.submenu {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(submenu) { subitem in
                    if subitem.isSeparator {
                        Divider().padding(4)
                    } else {
                        Button(action: {
                            activeAppModel.performAction(for: subitem)
                        }) {
                            Text(subitem.title)
                                .foregroundColor(.white)
                                .font(.system(size: 12))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(minWidth: 200)
            .padding(.vertical, 4)
        }
    }
}