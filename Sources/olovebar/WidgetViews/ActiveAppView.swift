import SwiftUI
import MacroAPI

struct MenuItemFrame: Equatable {
    let minX: CGFloat
    let maxX: CGFloat
}

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
            return (notchWidth, screenWidth, notchStart, notchEnd)
        } else {
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


struct ItemPositionKey: PreferenceKey {
    static let defaultValue: [Int: MenuItemFrame] = [:]
    static func reduce(value: inout [Int: MenuItemFrame], nextValue: () -> [Int: MenuItemFrame]) {
        value.merge(nextValue()) { $1 }
    }
}


@LogFunctions(.Widgets([.activeAppModel]))
struct ActiveAppWidgetView: View {
    @ObservedObject var model: ActiveAppModel
    @ObservedObject var config: Config
    @Binding var hideRight: Bool


    @State var showMenuBar: Bool = false
    @State var showSubMenu: Bool = false
    @State var subMenuID: UUID!

    @State var spacerData: SpacerData? = nil

    private var chevronType: String {
        showMenuBar ? "chevron.right" : "chevron.up"
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

                
            if showMenuBar {
                HStack {
                    ForEach(Array(model.menuItems.enumerated()), id: \.element.id) { index, item in
                        let _ = trace("Drawing \(index): (\(String(describing: spacerData)), \(1)) Item: \(item.title)")
                        if let spacerDataLocal = spacerData {
                            if index == spacerDataLocal.shouldInsertOn {
                                let _ = error("Inserted spacer after index \(index), size: \(Globals.notchWidth + spacerDataLocal.addableWidth)")
                                Color.clear.frame(width: Globals.notchWidth + spacerDataLocal.addableWidth)
                            }
                        }
                        menuItemView(item: item, index: index)
                            .background( GeometryReader { geo in
                                let frame = geo.frame(in: .global)
                                Color.clear.preference(
                                    key: ItemPositionKey.self,
                                    value: [index: MenuItemFrame.init(minX: frame.minX, maxX: frame.maxX)]
                                )
                            }
                        )
                    }
                }
                .onPreferenceChange(ItemPositionKey.self) { newPositions in
                    trace("PreferenceChanged: old -- (\(String(describing: spacerData)), \(1)")
                    for (index, item) in newPositions {
                        let notchIntersection = isNotchIntersection(item: item)
                        if notchIntersection.isIntersected {
                            spacerData = SpacerData(shouldInsertOn: index, addableWidth: notchIntersection.addableWidth)
                            break
                        }
                    }
                    trace("PreferenceChanged: new -- (\(String(describing: spacerData)), \(1))")
                }
            }
            let _ = error("Nilled")
            let _ = spacerData = nil
        }
        .onDisappear(perform: {let _ = error("Nilled"); spacerData = nil})
        .fixedSize()
        .frame(height: config.widgetHeight)
        .frame(minWidth: config.activeAppWidth)
        .padding(.horizontal, 20)
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
                        .background(.clear)
                    }
                }
            }
            .frame(minWidth: 200)
            .padding(.vertical, 4)
            .background(.clear)
        }
    }


    struct NotchIntersection {
        let isIntersected: Bool
        let addableWidth: CGFloat
    }

    private func isNotchIntersection(item: MenuItemFrame) -> NotchIntersection {        
        let rangesIntersect = item.minX < Globals.notchEnd && item.maxX > Globals.notchStart 
        
        guard rangesIntersect else {
            return NotchIntersection(isIntersected: false, addableWidth: 0)
        }
        
        let intersectionStart = max(item.minX, Globals.notchStart)
        let intersectionEnd = min(item.maxX, Globals.notchEnd)
        let intersectionWidth = intersectionEnd - intersectionStart
        let widgetWidth = item.maxX - item.minX
        let addableWidth = widgetWidth - intersectionWidth
        
        trace("""
        🔍 Perfect Intersection:
        Element: [\(String(format: "%.1f", item.minX)), \(String(format: "%.1f", item.maxX))]
        Notch:   [\(String(format: "%.1f", Globals.notchStart)), \(String(format: "%.1f", Globals.notchEnd))]
        Intersection: [\(String(format: "%.1f", intersectionStart)), \(String(format: "%.1f", intersectionEnd))] = \(String(format: "%.1f", intersectionWidth))pt
        """)
        
        return NotchIntersection(isIntersected: true, addableWidth: addableWidth)
    }
}

struct SpacerData {
    let shouldInsertOn: Int
    let addableWidth: CGFloat
}