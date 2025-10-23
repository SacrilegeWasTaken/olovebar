import SwiftUI
import MacroAPI


@LogFunctions(.Widgets([.activeAppModel]))
struct ActiveAppWidgetView: View {
    @ObservedObject var model: ActiveAppModel
    @ObservedObject var config: Config

    @State private var showMenuBar: Bool = false
    @State private var showSubMenu: Bool = false
    @State private var subMenuID: UUID!


    var body: some View {
        Button(action: {
            withAnimation {
                showMenuBar.toggle()
            }
        }) {
            HStack(spacing: 4) {
                Text(model.appName)
                    .foregroundColor(.white)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .fixedSize()

                Image(systemName: showMenuBar ? "chevron.down" : "chevron.up")
                    .foregroundColor(.white)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .fixedSize()
            }
            .padding(.horizontal, 20)
            .frame(height: config.widgetHeight)
            .frame(minWidth: config.activeAppWidth)
            .background(
                LiquidGlassBackground(
                    variant: GlassVariant(rawValue: config.widgetGlassVariant)!,
                    cornerRadius: config.widgetCornerRadius
                ) {}
            )
            .cornerRadius(config.widgetCornerRadius)
            .contentShape(Rectangle()) 
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showMenuBar) {
            HStack(spacing: 8) {
                ForEach(Array(model.menuItems.enumerated()), id: \.element.id) { index, item in
                    menuItemView(item: item, index: index)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
    }


    @ViewBuilder
    private func menuItemView(item: MenuItemData, index: Int) -> some View {
        Button(item.title) {
            showSubMenu = true
            subMenuID = item.id
        }
        .fixedSize()
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
                            model.performAction(for: subitem)
                            showSubMenu = false
                            showMenuBar = false
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
