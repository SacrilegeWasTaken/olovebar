import SwiftUI
import MacroAPI



@LogFunctions(.OLoveBar)
struct BarContentView: View {
    @StateObject var config = Config()


    @State private var theme_toggle: Theme = .trueBgRegularFront


    @StateObject private var appleLogoModel = AppleLogoModel()
    @StateObject private var aerospaceModel = AerospaceModel()
    @StateObject private var wifiModel = WiFiModel()
    @StateObject private var batteryModel = BatteryModel()
    @StateObject private var languageModel = LanguageModel()
    @StateObject private var volumeModel = VolumeModel()
    @StateObject private var activeAppModel = ActiveAppModel()
    @StateObject private var dateTimeModel = DateTimeModel()
      

    var body: some View {

        let appleLogoWidth = config.appleLogoWidth
        let aerospaceWidth = config.aerospaceWidth
        let activeAppWidth = config.activeAppWidth
        let dateTimeWidth = config.dateTimeWidth
        let widgetHeight = config.widgetHeight
        let cornerRadius = config.widgetCornerRadius
        let wifiWidth = config.wifiWidth
        let batteryWidth = config.batteryWidth
        let languageWidth = config.languageWidth
        let volumeWidth = config.volumeWidth
        let glassVariant = config.glassVariant
        let rightSpacing = config.rightSpacing
        let leftSpacing = config.leftSpacing

        ZStack {
            if self.theme_toggle == .trueBgRegularFront {
                LiquidGlassBackground(
                    variant: GlassVariant(rawValue: glassVariant) ?? .v11,
                    cornerRadius: cornerRadius
                ) {
                    Color.clear
                }
            }

            let view = HStack(spacing: 0) {
                HStack(spacing: rightSpacing) {
                    AppleLogoWidgetView(model: appleLogoModel, config: config, controller: ConfigWindowController(config: config), theme_toggle: $theme_toggle, width: appleLogoWidth, height: widgetHeight, cornerRadius: cornerRadius)
                    AerospaceWidgetView(model: aerospaceModel, width: aerospaceWidth, height: widgetHeight, cornerRadius: cornerRadius)
                    ActiveAppWidgetView(model: activeAppModel, width: activeAppWidth, height: widgetHeight, cornerRadius: cornerRadius)
                }

                Spacer()

                HStack(spacing: leftSpacing) {
                    WiFiWidgetView(model: wifiModel, width: wifiWidth, height: widgetHeight, cornerRadius: cornerRadius)
                    BatteryWidgetView(model: batteryModel, width: batteryWidth, height: widgetHeight, cornerRadius: cornerRadius)
                    LanguageWidgetView(model: languageModel, width: languageWidth, height: widgetHeight, cornerRadius: cornerRadius)
                    VolumeWidgetView(model: volumeModel, width: volumeWidth, height: widgetHeight, cornerRadius: cornerRadius)
                    DateTimeWidgetView(model: dateTimeModel, width: dateTimeWidth, height: widgetHeight, cornerRadius: cornerRadius)
                }
            }

            switch self.theme_toggle {
                case .regularBgRegularFront:
                    view.glassEffect()
                default:
                    view
            }
        }
    }
}




