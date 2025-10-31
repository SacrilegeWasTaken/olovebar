import SwiftUI
 
struct NotchContentView: View {
    @ObservedObject var state: NotchWindowState
    @StateObject var config: Config

    @ObservedObject var activeAppModel = GlobalModels.shared.activeAppModel
    @State private var showSubMenu: Bool = false
    @State private var subMenuID: UUID?
    @State private var isHoveringPopover: Bool = false

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
            set: { newValue in
                if !newValue {
                    showSubMenu = false
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        isHoveringPopover = false
                        state.isHoveringPopover = false
                    }
                }
            }
        )) {
            submenuView(for: item)
                .onHover { hovering in
                    isHoveringPopover = hovering
                    state.isHoveringPopover = hovering
                }
        }
    }
    
    @ViewBuilder
    private func submenuView(for item: MenuItemData) -> some View {
        if let submenu = item.submenu {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(submenu) { subitem in
                    if subitem.isSeparator {
                        Divider()
                            .padding(.vertical, 4)
                    } else {
                        SubmenuItemView(
                            item: subitem,
                            action: {
                                activeAppModel.performAction(for: subitem)
                                Task { @MainActor in
                                    showSubMenu = false
                                    try? await Task.sleep(nanoseconds: 300_000_000)
                                    isHoveringPopover = false
                                    state.isHoveringPopover = false
                                }
                            }
                        )
                    }
                }
            }
            .frame(minWidth: 200)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial)
        }
    }
}

struct SubmenuItemView: View {
    let item: MenuItemData
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(item.title)
                    .foregroundColor(item.isEnabled ? .white : .gray)
                    .font(.system(size: 13))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                if !item.keyEquivalent.isEmpty {
                    Text(item.keyEquivalent)
                        .foregroundColor(.gray)
                        .font(.system(size: 11))
                }
                
                if item.submenu != nil {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                        .font(.system(size: 10))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isHovered ? Color.accentColor.opacity(0.8) : Color.clear)
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .disabled(!item.isEnabled)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}