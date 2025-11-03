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
                    AppleLogoWidgetView(config: config, controller: ConfigWindowController(config: config), theme_toggle: $theme_toggle)
                    AerospaceWidgetView(config: config)
                    ActiveAppWidgetView(config: config)
                }

                Spacer()
                
                HStack(spacing: config.leftSpacing) {
                    WiFiWidgetView(config: config)
                    BatteryWidgetView(config: config)
                    LanguageWidgetView(config: config)
                    VolumeWidgetView(config: config)
                    DateTimeWidgetView(config: config)
                }
            }
        }
    }
}
