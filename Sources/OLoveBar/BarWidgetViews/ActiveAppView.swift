import SwiftUI
import MacroAPI


@LogFunctions(.Widgets([.activeAppModel]))
struct ActiveAppWidgetView: View {
    @ObservedObject var config: Config


    @ObservedObject var activeAppModel = GlobalModels.shared.activeAppModel


    @State private var showMenuBar: Bool = false
    @State private var showSubMenu: Bool = false
    @State private var subMenuID: UUID!


    var body: some View {
        Button(action: {
            withAnimation {
                showMenuBar.toggle()
            }
        }) {
            HStack(spacing: 8) {
                Text(activeAppModel.appName)
                    .foregroundColor(.white)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .fixedSize()
                    .id(activeAppModel.appName)
                    .transition(.opacity)
            }
            .animation(.easeInOut(duration: 0.15), value: activeAppModel.appName)
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
    }
}
