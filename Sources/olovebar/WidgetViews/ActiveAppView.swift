import SwiftUI
import MacroAPI
import Cocoa

struct Globals {
    static func computeValues() -> (notchWidth: CGFloat, screenWidth: CGFloat, notchStart: CGFloat, notchEnd: CGFloat) {
        guard let screen = NSScreen.main else {
            let width = NSScreen.main?.frame.width ?? 0
            return (0, width, 0, width)
        }
        
        if let topLeft = screen.auxiliaryTopLeftArea, let topRight = screen.auxiliaryTopRightArea {
            let screenWidth = screen.frame.width
            let leftWidth = topLeft.width
            let rightWidth = topRight.width
            let notchWidth = screenWidth - leftWidth - rightWidth
            let notchStart = leftWidth
            let notchEnd = notchStart + notchWidth
            
            // print("screenWidth: \(screenWidth), notchWidth: \(notchWidth), notchStart: \(notchStart), notchEnd: \(notchEnd)")

            return (notchWidth, screenWidth, notchStart, notchEnd)
        } else {
            // Если челки нет
            let screenWidth = screen.frame.width
            return (0, screenWidth, 0, screenWidth)
        }
    }

    static var values: (notchWidth: CGFloat, screenWidth: CGFloat, notchStart: CGFloat, notchEnd: CGFloat) {
        computeValues()
    }

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
    @State var spacerIndex: Int? = nil
    @State var itemWidths: [Int: CGFloat] = [:]
    
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
        GeometryReader { geo in
            let globalX = geo.frame(in: .global).minX
            let _ = debug("globalX: \(globalX), notchStart: \(Globals.notchStart), notchEnd: \(Globals.notchEnd), notchWidth: \(Globals.notchWidth)")
            
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
                
                if showMenuBar {
                    let _ = debug("=== MENU BAR RENDERING ===")
                    let _ = debug("Current spacerIndex: \(String(describing: spacerIndex))")
                    HStack(spacing: 2) {
                        ForEach(Array(model.menuItems.enumerated()), id: \.element.id) { index, item in
                            let _ = debug("Rendering item[\(index)] '\(item.title)', spacerIndex=\(String(describing: spacerIndex))")
                            if index == spacerIndex {
                                let _ = debug("INSERTING SPACER before item[\(index)]")
                                let nextItemWidth = itemWidths[index] ?? 60
                                Color.clear.frame(width: Globals.notchWidth + nextItemWidth)
                            }
                            menuItemView(item: item, index: index)
                                .background(
                                    GeometryReader { itemGeo in
                                        let itemX = itemGeo.frame(in: .global).minX
                                        let itemWidth = itemGeo.size.width
                                        let _ = debug("Item[\(index)] '\(item.title)' position: x=\(itemX), width=\(itemWidth)")
                                        DispatchQueue.main.async {
                                            itemWidths[index] = itemWidth
                                        }
                                        return Color.clear.preference(
                                            key: ItemPositionKey.self,
                                            value: [index: itemX]
                                        )
                                    }
                                )
                        }
                    }
                    .onPreferenceChange(ItemPositionKey.self) { positions in
                        let _ = debug("=== PREFERENCE CHANGE ===")
                        let _ = debug("screen width: \(Globals.screenWidth), notchStart: \(Globals.notchStart), notchEnd: \(Globals.notchEnd), notchWidth: \(Globals.notchWidth)")
                        let _ = debug("All positions: \(positions)")
                        for i in 0..<model.menuItems.count {
                            if let itemX = positions[i] {
                                let estimatedItemWidth: CGFloat = 60 // примерная ширина элемента меню
                                let itemEnd = itemX + estimatedItemWidth
                                let _ = debug("Check[\(i)]: itemX=\(itemX), itemEnd=\(itemEnd), notchStart=\(Globals.notchStart)")
                                if itemEnd > Globals.notchStart {
                                    let _ = debug("FOUND INTERSECTION at index \(i), setting spacerIndex=\(i)")
                                    spacerIndex = i
                                    return
                                }
                            }
                        }
                        let _ = debug("No intersection found, setting spacerIndex=nil")
                        spacerIndex = nil
                    }
                }
            }
            .frame(minWidth: config.activeAppWidth)
            .frame(height: config.widgetHeight)
            .background(.clear)
            .clipShape(RoundedRectangle(cornerRadius: config.widgetCornerRadius, style: .continuous))
            .padding(.horizontal, 20)
        }
    }
    
    struct ItemPositionKey: PreferenceKey {
        static let defaultValue: [Int: CGFloat] = [:]
        static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
            value.merge(nextValue()) { $1 }
        }
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            LiquidGlassBackground(
                variant: GlassVariant(rawValue: config.widgetGlassVariant)!,
                cornerRadius: config.widgetCornerRadius
            ) {
                Button(action: { 
                    showMenuBar.toggle()
                    hideRight.toggle()
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