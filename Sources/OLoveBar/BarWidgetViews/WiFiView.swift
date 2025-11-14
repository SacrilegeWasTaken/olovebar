import SwiftUI
import MacroAPI

@LogFunctions(.Widgets([.wifiModel]))
struct WiFiWidgetView: View {
    @ObservedObject var config: Config


    @ObservedObject var model = GlobalModels.shared.wifiModel

    
    var body: some View {
        Button(action: { model.update() }) {
            HStack(spacing: 8) {
                Image(systemName: model.stateIcon)
                    .foregroundColor(.white)
                    .font(.system(size: 14))
                if config.showWiFiName {
                    Text(model.ssid ?? "No Wi‑Fi")
                        .foregroundColor(.white)
                        .font(.system(size: 12))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(height: config.widgetHeight)
            .fixedSize(horizontal: true, vertical: false)
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
        .onAppear { model.update() }
    }
}