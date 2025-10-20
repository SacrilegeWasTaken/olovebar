import SwiftUI
import MacroAPI


struct Globals {
    static let values: (notchWidth: CGFloat, screenWidth: CGFloat, notchStart: CGFloat, notchEnd: CGFloat) = {
        let notchWidth: CGFloat = NSScreen.main?.safeAreaInsets.top ?? 0
        let screenWidth: CGFloat = NSScreen.main?.frame.width ?? 0
        let notchStart = (screenWidth / 2) - (notchWidth / 2)
        let notchEnd = notchStart + notchWidth
        return (notchWidth, screenWidth, notchStart, notchEnd)
    }()

    static var notchWidth: CGFloat { values.notchWidth }
    static var screenWidth: CGFloat { values.screenWidth }
    static var notchStart: CGFloat { values.notchStart }
    static var notchEnd: CGFloat { values.notchEnd }
}


@LogFunctions(.Widgets([.activeAppModel]))
struct ActiveAppWidgetView: View {
    @ObservedObject var model: ActiveAppModel
    @ObservedObject var config: Config
    @Binding var hideRight: Bool
    @State var showMenuBar: Bool = false    
    @State var showSubMenu: Bool = false
    @State var subMenuID: UUID!
    
    private var chevronType: String {
        showMenuBar ? "chevron.right" : "chevron.up"
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
                        Divider().padding(.vertical, 4)
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
            .background(Color.black.opacity(0.9))
        }
    }
    
    private var contentView: some View {
        HStack(spacing: 8) {
            Text(model.appName)
                .foregroundColor(.white)
                .font(.system(size: 12))
                .lineLimit(1)
                .fixedSize()
            
            Image(systemName: chevronType)
                .foregroundColor(.white)
                .font(.system(size: 12))
                .lineLimit(1)
                .fixedSize()
                .animation(.linear(duration: 0.3), value: chevronType)
            
            if showMenuBar {
                let _ = debug("=== NOTCH INFO: start=\(Globals.notchStart), end=\(Globals.notchEnd), width=\(Globals.notchWidth), screenWidth=\(Globals.screenWidth) ===")
                HStack(spacing: 2) {
                    ForEach(Array(model.menuItems.enumerated()), id: \.element.id) { index, item in
                        menuItemView(item: item, index: index)
                    }
                }
                .transition(.opacity)
            }
        }
        .frame(minWidth: config.activeAppWidth)
        .frame(height: config.widgetHeight)
        .background(.clear)
        .clipShape(RoundedRectangle(cornerRadius: config.widgetCornerRadius, style: .continuous))
        .animation(.linear(duration: 0.3), value: showMenuBar)
        .padding(.horizontal, 20)
        .onChange(of: showMenuBar) { _ in
            // spacerInserted = false
        }
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            LiquidGlassBackground(
                variant: GlassVariant(rawValue: config.widgetGlassVariant)!,
                cornerRadius: config.widgetCornerRadius
            ) {
                Button(action: { 
                    withAnimation{ 
                        showMenuBar.toggle()
                        hideRight.toggle()
                    }
                }) {
                    contentView
                }
                .buttonStyle(.plain)
            }
        }
        .onTapGesture {
            if showMenuBar {
                showMenuBar = false
                showSubMenu = false
                hideRight = false
            }
        }
    }
}