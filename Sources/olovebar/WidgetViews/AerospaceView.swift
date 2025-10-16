import SwiftUI
import MacroAPI

@LogFunctions(.Widgets([.aerospaceModel]))
struct AerospaceWidgetView: View {
    @ObservedObject var model: AerospaceModel
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    var body: some View {
        GlassEffectContainer {
            HStack(spacing: 0) {
                let _ = debug("Updating UI. Focused: \(String(describing: model.focused))")
                ForEach(model.workspaces, id: \.self) { id in
                    Button(action: { withAnimation { model.focus(id) } }) {
                        let _ = debug("Updating text UI")
                        Text(id)
                            .font(.system(size: 12, weight: .medium))
                            .frame(width: width, height: height)
                            .foregroundColor(id == model.focused ? .purple : .white)
                            .background(.clear)
                            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .background(.clear)
                    .frame(width: width, height: height)
                    .animation(.easeInOut(duration: 0.1), value: model.focused)
                }
            }
            .glassEffect(.regular.interactive(), in: .capsule)
            .glassEffectTransition(.matchedGeometry)
            .background(.clear)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .frame(height: height)
            .onAppear { model.startTimer(interval: 0.1) }
        }
    }
}