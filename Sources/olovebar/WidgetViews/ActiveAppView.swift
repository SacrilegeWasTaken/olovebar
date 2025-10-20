import SwiftUI
import MacroAPI

struct WidthPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct StartXPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
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
    @State private var itemWidths: [UUID: CGFloat] = [:]
    @State private var itemPositions: [UUID: CGFloat] = [:]
    var body: some View {
        let notchWidth: CGFloat = NSScreen.main?.safeAreaInsets.top ?? 0
        let screenWidth: CGFloat = NSScreen.main?.frame.width ?? 0
        let notchStart = (screenWidth - notchWidth) / 2
        let notchEnd = notchStart + notchWidth
        
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
                        HStack(spacing: 8) {
                    let chevronType = switch showMenuBar {
                        case true: "chevron.right"
                        case false: "chevron.up"
                    }
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
                            let _ = debug("notchStart=\(notchStart), notchEnd=\(notchEnd)")
                            HStack(spacing: 2) {
                                ForEach(Array(model.menuItems.enumerated()), id: \.element.id) { index, item in
                                    let itemX = itemPositions[item.id] ?? 0
                                    let itemWidth = itemWidths[item.id] ?? 0
                                    let itemEnd = itemX + itemWidth
                                    
                                    let itemBeforeNotch = itemX < notchStart
                                    let itemEndAfterNotchStart = itemEnd > notchStart
                                    let shouldInsertSpacer = notchWidth > 0 && itemBeforeNotch && itemEndAfterNotchStart && index > 0
                                    
                                    let _ = debug("Item[\(index)] \(item.title): x=\(itemX), end=\(itemEnd), notchStart=\(notchStart), shouldInsert=\(shouldInsertSpacer)")
                                    
                                    if shouldInsertSpacer {
                                        Spacer().frame(width: notchWidth)
                                    }
                                    
                                    Button(item.title) {
                                        showSubMenu = true
                                        subMenuID = item.id
                                    }
                                    .fixedSize()
                                    .background(
                                        GeometryReader { geo in
                                            Color.clear.task {
                                                let x = geo.frame(in: .global).minX
                                                let w = geo.size.width
                                                if itemPositions[item.id] != x || itemWidths[item.id] != w {
                                                    itemPositions[item.id] = x
                                                    itemWidths[item.id] = w
                                                    debug("Item \(item.title): x=\(x), width=\(w)")
                                                }
                                            }
                                        }
                                    )
                                    .popover(isPresented: Binding(
                                        get: { showSubMenu && subMenuID == item.id },
                                        set: { if !$0 { showSubMenu = false } }
                                    )) {
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
                                }
                                .transition(.opacity)
                            }
                        }
                        }
                        .frame(minWidth: config.activeAppWidth)
                        .frame(height: config.widgetHeight)
                        .background(.clear)
                        .clipShape(RoundedRectangle(cornerRadius: config.widgetCornerRadius, style: .continuous))
                        .animation(.linear(duration: 0.3), value: showMenuBar)
                        .padding(.horizontal, 20)
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