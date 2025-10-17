import SwiftUI
import MacroAPI

@LogFunctions(.Widgets([.aerospaceModel]))
struct AerospaceWidgetView: View {
    @ObservedObject var model: AerospaceModel
    @ObservedObject var config: Config
    var body: some View {
        LiquidGlassBackground(
            variant: GlassVariant(rawValue: config.widgetGlassVariant)!,
            cornerRadius: config.widgetCornerRadius
        ) {
        HStack(spacing: 0) {
            let _ = debug("Updating UI. Focused: \(String(describing: model.focused))")
            ForEach(model.workspaces, id: \.self) { id in
                Button(action: { withAnimation { model.focus(id) } }) {
                    let _ = debug("Updating text UI")
                    ZStack {
                        Text(id)
                            .font(.system(size: 12, weight: .medium))
                            .frame(width: config.aerospaceWidth, height: config.widgetHeight)
                            .foregroundColor(.white)
                            .background(.clear)
                        if self.model.focused == id {
                            LiquidGlassBackground(
                                variant: .v11,
                                cornerRadius: config.widgetCornerRadius
                            ) {
                                // Color.clear
                                // // НЕ Color.clear - нужен реальный контент
                                Rectangle()
                                    .fill(.clear)
                                    .frame(width: config.aerospaceWidth * 2, height: config.widgetHeight)
                            }
                            .frame(width: config.aerospaceWidth * 2, height: config.widgetHeight)
                        }
                    }
                }
                .buttonStyle(.plain)
                .clipShape(RoundedRectangle(cornerRadius: config.widgetCornerRadius, style: .continuous))
                .background(.clear)
                .frame(width: config.aerospaceWidth, height: config.widgetHeight)
                .animation(.interpolatingSpring(duration: 0.2), value: model.focused)
            }
        }
        .background(.clear)
        .clipShape(RoundedRectangle(cornerRadius: config.widgetCornerRadius, style: .continuous))
        .frame(height: config.widgetHeight)
        .onAppear { model.startTimer(interval: 0.1) }
        }
    }
}