import SwiftUI
import MacroAPI

@LogFunctions(.Widgets([.wifiModel]))
struct WiFiWidgetView: View {
    @ObservedObject var config: Config


    @ObservedObject var model = GlobalModels.shared.wifiModel

    
    var body: some View {
        LiquidGlassBackground(
            variant: GlassVariant(rawValue: config.widgetGlassVariant)!,
            cornerRadius: config.widgetCornerRadius
        ) {
            Button(action: { model.update() }) {
                HStack(spacing: 8) {
                    Image(systemName: model.stateIcon)
                        .foregroundColor(.white)
                        .font(.system(size: 14))
                        .frame(height: config.widgetHeight)
                    if config.showWiFiName {
                        Text(model.ssid ?? "No Wi‑Fi")
                            .foregroundColor(.white)
                            .font(.system(size: 12))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                .padding(.horizontal, config.wifiWidth)
                .padding(.vertical, 6)
                .frame(height: config.widgetHeight)
            }
            .buttonStyle(PlainButtonStyle())
            .background(.clear)
            .cornerRadius(config.widgetCornerRadius)
            .fixedSize(horizontal: true, vertical: false)
            .clipShape(RoundedRectangle(cornerRadius: config.widgetCornerRadius, style: .continuous))
            .onAppear { model.update() }
        }
    }
}