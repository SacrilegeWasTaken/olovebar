import SwiftUI
import MacroAPI

@LogFunctions(.Widgets([.batteryModel]))
struct BatteryWidgetView: View {
    @ObservedObject var model: BatteryModel
    @ObservedObject var config: Config
    var body: some View {
        LiquidGlassBackground(
            variant: GlassVariant(rawValue: config.widgetGlassVariant)!,
            cornerRadius: config.widgetCornerRadius
        ) {
            Button(action: {
                let url = URL(fileURLWithPath: "/System/Applications/System Settings.app")
                NSWorkspace.shared.open(url)
            }) {
                HStack(spacing: 6) {
                    Image(systemName: model.isCharging ? "battery.100.bolt" : "battery.100")
                        .foregroundColor(.white)
                    Text("\(model.percentage)%")
                        .foregroundColor(.white)
                        .font(.system(size: 12))
                }
                .frame(width: config.batteryWidth, height: config.widgetHeight)
            }
            .buttonStyle(.plain)
            .background(.clear)
            .cornerRadius(config.widgetCornerRadius)
            .frame(width: config.batteryWidth, height: config.widgetHeight)
            .clipShape(RoundedRectangle(cornerRadius: config.widgetCornerRadius, style: .continuous))
        }
    }
}