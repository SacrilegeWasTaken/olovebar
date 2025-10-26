import SwiftUI
import MacroAPI

@LogFunctions(.Widgets([.languageModel]))
struct LanguageWidgetView: View {
    @ObservedObject var model: LanguageModel
    @ObservedObject var config: Config
    var body: some View {
        LiquidGlassBackground(
            variant: GlassVariant(rawValue: config.widgetGlassVariant)!,
            cornerRadius: config.widgetCornerRadius
        ) {
            Button(action: { model.toggle() }) {
                Text(model.current)
                    .foregroundColor(.white)
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 8)
                    .frame(height: config.widgetHeight)
                    .frame(minWidth: config.languageWidth)
            }
            .buttonStyle(.plain)
            .cornerRadius(config.widgetCornerRadius)
            .frame(minWidth: config.languageWidth)
            .frame(height: config.widgetHeight)
            .clipShape(RoundedRectangle(cornerRadius: config.widgetCornerRadius, style: .continuous))
        }
    }
}
