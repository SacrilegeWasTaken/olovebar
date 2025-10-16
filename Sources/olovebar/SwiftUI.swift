import SwiftUI
import MacroAPI



@LogFunctions(.OLoveBar)
struct BarContentView: View {
    @State private var theme_toggle: Theme = .trueBgRegularFront

    @StateObject private var appleLogoModel = AppleLogoModel()
    @StateObject private var aerospaceModel = AerospaceModel()
    @StateObject private var wifiModel = WiFiModel()
    @StateObject private var batteryModel = BatteryModel()
    @StateObject private var languageModel = LanguageModel()
    @StateObject private var volumeModel = VolumeModel()
    @StateObject private var activeAppModel = ActiveAppModel()
    @StateObject private var dateTimeModel = DateTimeModel()

    var glass_variant = 11
      
    var body: some View {

        let appleButtonWidth: CGFloat = 45
        let timeButtonWidth: CGFloat = 190
        let widgetHeight: CGFloat = 33
        let cornerRadius: CGFloat = 16
        let wifiWidth: CGFloat = 90
        let batteryWidth: CGFloat = 70
        let languageWidth: CGFloat = 48
        let volumeWidth: CGFloat = 48

        ZStack {
            if self.theme_toggle == .trueBgRegularFront {
                LiquidGlassBackground(
                    variant: GlassVariant(rawValue: glass_variant) ?? .v11,
                    cornerRadius: cornerRadius
                ) {
                    Color.clear
                }
            }

            let view = HStack(spacing: 0) {
                HStack(spacing: 16) {
                    AppleLogoWidgetView(model: appleLogoModel, theme_toggle: $theme_toggle, width: appleButtonWidth, height: widgetHeight, cornerRadius: cornerRadius)
                    AerospaceWidgetView(model: aerospaceModel, width: widgetHeight, height: widgetHeight, cornerRadius: cornerRadius)
                    ActiveAppWidgetView(model: activeAppModel, width: 70, height: widgetHeight, cornerRadius: cornerRadius)
                }

                Spacer()

                HStack(spacing: 8) {
                    WiFiWidgetView(model: wifiModel, width: wifiWidth, height: widgetHeight, cornerRadius: cornerRadius)
                    BatteryWidgetView(model: batteryModel, width: batteryWidth, height: widgetHeight, cornerRadius: cornerRadius)
                    LanguageWidgetView(model: languageModel, width: languageWidth, height: widgetHeight, cornerRadius: cornerRadius)
                    VolumeWidgetView(model: volumeModel, width: volumeWidth, height: widgetHeight, cornerRadius: cornerRadius)
                    DateTimeWidgetView(model: dateTimeModel, width: timeButtonWidth, height: widgetHeight, cornerRadius: cornerRadius)
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




