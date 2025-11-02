import SwiftUI
import MacroAPI


@LogFunctions(.OLoveBar)
struct BarContentView: View {
    @StateObject var config: Config
    @State private var theme_toggle: Bool = true


    var body: some View {
        ZStack {
            if self.theme_toggle {
                LiquidGlassBackground(
                    variant: GlassVariant(rawValue: config.windowGlassVariant)!,
                    cornerRadius: config.widgetCornerRadius
                ) {
                    Color.clear
                }
            }

            HStack(spacing: 0) {
                HStack(spacing: config.rightSpacing) {
                    AppleLogoWidgetView(model: GlobalModels.shared.appleLogoModel, config: config, controller: ConfigWindowController(config: config), theme_toggle: $theme_toggle)
                    AerospaceWidgetView(model: GlobalModels.shared.aerospaceModel, config: config)
                    ActiveAppWidgetView(config: config)
                }

                Spacer()
                
                HStack(spacing: config.leftSpacing) {
                    WiFiWidgetView(model: GlobalModels.shared.wifiModel, config: config)
                    BatteryWidgetView(model: GlobalModels.shared.batteryModel, config: config)
                    LanguageWidgetView(model: GlobalModels.shared.languageModel, config: config)
                    VolumeWidgetView(model: GlobalModels.shared.volumeModel, config: config)
                    DateTimeWidgetView(model: GlobalModels.shared.dateTimeModel, config: config)
                }
            }
        }
    }
}
