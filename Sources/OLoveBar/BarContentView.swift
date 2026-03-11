import SwiftUI
import MacroAPI


@LogFunctions(.OLoveBar)
struct BarContentView: View {
    @StateObject var config: Config
    @State private var themeToggle: Bool = true
    @State private var settingsController: ConfigWindowController?


    var body: some View {
        ZStack {
            if self.themeToggle {
                LiquidGlassBackground(
                    variant: GlassVariant.safe(from: config.windowGlassVariant, default: .v12),
                    cornerRadius: config.widgetCornerRadius
                ) {
                    Color.clear
                }
            }

            HStack(spacing: 0) {
                HStack(spacing: config.rightSpacing) {
                    AppleLogoWidgetView(config: config, controller: settingsController, themeToggle: $themeToggle)
                    AerospaceWidgetView(config: config)
                    ActiveAppWidgetView(config: config)
                }

                Spacer()
                
                HStack(spacing: config.leftSpacing) {
                    NotesWidgetView(config: config)
                    WiFiWidgetView(config: config)
                    BatteryWidgetView(config: config)
                    LanguageWidgetView(config: config)
                    VolumeWidgetView(config: config)
                    DateTimeWidgetView(config: config)
                }
            }
        }
        .onAppear {
            if settingsController == nil {
                settingsController = ConfigWindowController(config: config)
            }
        }
    }
}
