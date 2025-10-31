import SwiftUI
import MacroAPI


@LogFunctions(.Widgets([.activeAppModel]))
struct ActiveAppWidgetView: View {
    @ObservedObject var activeAppModel = GlobalModels.shared.activeAppModel
    @ObservedObject var aerospaceAppModel = GlobalModels.shared.aerospaceModel
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
            HStack(spacing: 8) {
                Text(aerospaceAppModel.focused ?? "N")
                    .foregroundColor(.white)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .fixedSize()
                    .id(aerospaceAppModel.focused)
                    .transition(.opacity)

                Image(systemName: "chevron.right")
                    .foregroundColor(.white)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .fixedSize()

                Text(activeAppModel.appName)
                    .foregroundColor(.white)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .fixedSize()
                    .id(activeAppModel.appName)
                    .transition(.opacity)
            }
            .animation(.easeInOut(duration: 0.15), value: aerospaceAppModel.focused)
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
