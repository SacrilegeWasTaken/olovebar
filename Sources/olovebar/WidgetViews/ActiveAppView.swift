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
}