import SwiftUI
import MacroAPI

@LogFunctions(.Widgets([.languageModel]))
struct LanguageWidgetView: View {
    @ObservedObject var model: LanguageModel
    @ObservedObject var config: Config
    var body: some View {
        Button(action: { model.toggle() }) {
            Text(model.current)
                .foregroundColor(.white)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: config.languageWidth, height: config.widgetHeight)
                .glassEffect()
        }
        .buttonStyle(.plain)
        .cornerRadius(config.widgetCornerRadius)
        .frame(width: config.languageWidth, height: config.widgetHeight)
        .clipShape(RoundedRectangle(cornerRadius: config.widgetCornerRadius, style: .continuous))
        .onAppear { model.update() }
    }
}