import SwiftUI
import MacroAPI

@LogFunctions(.Widgets([.activeAppModel]))
struct ActiveAppWidgetView: View {
    @ObservedObject var model: ActiveAppModel
    @ObservedObject var config: Config
    @State var showMenuBar: Bool = false    
    @State var showSubMenu: Bool = false
    @State var subMenuID: UUID!
    var body: some View {
        ZStack(alignment: .topLeading) {
            LiquidGlassBackground(
                variant: GlassVariant(rawValue: config.widgetGlassVariant)!,
                cornerRadius: config.widgetCornerRadius
            ) {
                Button(action: { withAnimation{ showMenuBar.toggle() } }) {
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
                        HStack(spacing: 2) {
                            let _ = debug("Menu items: \(model.menuItems.count)")
                            ForEach(model.menuItems, id: \.self) { item in
                                Button(item.title) {
                                    showSubMenu = true
                                    subMenuID = item.id
                                }
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
            }
        }
    }
}