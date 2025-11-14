import SwiftUI
import MacroAPI

@LogFunctions(.Widgets([.languageModel]))
struct LanguageWidgetView: View {
    @ObservedObject var config: Config


    @ObservedObject var model = GlobalModels.shared.languageModel


    var body: some View {
        Button(action: { model.toggle() }) {
            Text(model.current)
                .foregroundColor(.white)
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 8)
                .frame(minWidth: config.languageWidth)
                .frame(height: config.widgetHeight)
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
    }
}
