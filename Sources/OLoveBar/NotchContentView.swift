import SwiftUI
 
struct NotchContentView: View {
    @ObservedObject var state: NotchWindowState
    @StateObject var config: Config

    @ObservedObject var activeAppModel = GlobalModels.shared.activeAppModel
    @State private var showSubMenu: Bool = false
    @State private var subMenuID: UUID?

    var body: some View {
        Group {
            if state.isExpanded {
                VStack(spacing: 0) {
                    HStack {

                    }
                    .frame(maxWidth: .infinity, minHeight: Globals.notchHeight, maxHeight: Globals.notchHeight)
                    .background(.black)
                    
                    HStack(spacing: 4) {
    
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.black)

                    HStack(spacing: 4) {
                        ForEach(activeAppModel.menuItems) { item in
                            menuItemView(item: item)
                                .cornerRadius(config.widgetCornerRadius)
                                .clipShape(RoundedRectangle(cornerRadius: config.widgetCornerRadius, style: .continuous))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: 35)
                    .background(.black)
                }
                .background(.black)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: state.isExpanded)
    }
    
    @ViewBuilder
    private func menuItemView(item: MenuItemData) -> some View {
        Button(action: {
            if item.submenu != nil {
                showSubMenu = true
                subMenuID = item.id
            } else {
                activeAppModel.performAction(for: item)
            }
        }) {
            Text(item.title)
                .foregroundColor(.white)
                .font(.system(size: 12))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .popover(isPresented: Binding(
            get: { showSubMenu && subMenuID == item.id },
            set: { if !$0 { showSubMenu = false } }
        )) {
            submenuView(for: item)
        }
    }
    
    @ViewBuilder
    private func submenuView(for item: MenuItemData) -> some View {
        if let submenu = item.submenu {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(submenu) { subitem in
                    if subitem.isSeparator {
                        Divider().padding(4)
                    } else {
                        Button(action: {
                            activeAppModel.performAction(for: subitem)
                            showSubMenu = false
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