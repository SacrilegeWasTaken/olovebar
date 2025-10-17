import SwiftUI
import MacroAPI

@LogFunctions(.Widgets([.aerospaceModel]))
struct AerospaceWidgetView: View {
    @ObservedObject var model: AerospaceModel
    @ObservedObject var config: Config
    var body: some View {
        GlassEffectContainer {
            HStack(spacing: 0) {
                let _ = debug("Updating UI. Focused: \(String(describing: model.focused))")
                ForEach(model.workspaces, id: \.self) { id in
                    Button(action: { withAnimation { model.focus(id) } }) {
                        let _ = debug("Updating text UI")
                        Text(id)
                            .font(.system(size: 12, weight: .medium))
                            .frame(width: config.aerospaceWidth, height: config.widgetHeight)
                            .foregroundColor(id == model.focused ? .purple : .white)
                            .background(.clear)
                            .clipShape(RoundedRectangle(cornerRadius: config.widgetCornerRadius, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .clipShape(RoundedRectangle(cornerRadius: config.widgetCornerRadius, style: .continuous))
                    .background(.clear)
                    .frame(width: config.aerospaceWidth, height: config.widgetHeight)
                    .animation(.easeInOut(duration: 0.1), value: model.focused)
                }
            }
            .glassEffect(.regular.interactive(), in: .capsule)
            .glassEffectTransition(.matchedGeometry)
            .background(.clear)
            .clipShape(RoundedRectangle(cornerRadius: config.widgetCornerRadius, style: .continuous))
            .frame(height: config.widgetHeight)
            .onAppear { model.startTimer(interval: 0.1) }
        }
    }
}