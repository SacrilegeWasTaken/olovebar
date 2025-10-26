import SwiftUI
import MacroAPI



@LogFunctions(.OLoveBar)
struct BarContentView: View {
    @StateObject var config = Config()


    @State private var theme_toggle: Bool = true


    @StateObject private var appleLogoModel = AppleLogoModel()
    @StateObject private var aerospaceModel = AerospaceModel()
    @StateObject private var wifiModel = WiFiModel()
    @StateObject private var batteryModel = BatteryModel()
    @StateObject private var languageModel = LanguageModel()
    @StateObject private var volumeModel = VolumeModel()
    @StateObject private var activeAppModel = ActiveAppModel()
    @StateObject private var dateTimeModel = DateTimeModel()


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
                    AppleLogoWidgetView(model: appleLogoModel, config: config, controller: ConfigWindowController(config: config), theme_toggle: $theme_toggle)
                    AerospaceWidgetView(model: aerospaceModel, config: config)
                    ActiveAppWidgetView(model: activeAppModel, config: config)
                }

                Spacer()
                
                HStack(spacing: config.leftSpacing) {
                    WiFiWidgetView(model: wifiModel, config: config)
                    BatteryWidgetView(model: batteryModel, config: config)
                    LanguageWidgetView(model: languageModel, config: config)
                    VolumeWidgetView(model: volumeModel, config: config)
                    DateTimeWidgetView(model: dateTimeModel, config: config)
                }
            }
        }
    }
}
