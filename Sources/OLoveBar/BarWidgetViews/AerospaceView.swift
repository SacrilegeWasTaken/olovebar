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
                    Text(id)
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: config.aerospaceWidth, height: config.widgetHeight)
                        .foregroundColor(id == self.model.focused ? .purple : .white)
                        .background(.clear)
                    
                }
                .buttonStyle(.plain)
                .clipShape(RoundedRectangle(cornerRadius: config.widgetCornerRadius, style: .continuous))
                .background(.clear)
                .frame(width: config.aerospaceWidth, height: config.widgetHeight)
                .animation(.interpolatingSpring(duration: 0.1), value: model.focused)
            }
        }
        .padding(.horizontal, 4)
        .background(.clear)
        .clipShape(RoundedRectangle(cornerRadius: config.widgetCornerRadius, style: .continuous))
        .frame(height: config.widgetHeight)
        }
    }
}