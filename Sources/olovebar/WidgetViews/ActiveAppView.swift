import SwiftUI
import MacroAPI

@LogFunctions(.Widgets([.activeAppModel]))
struct ActiveAppWidgetView: View {
    @ObservedObject var model: ActiveAppModel
    @ObservedObject var config: Config
    var body: some View {
        Button(action: {}) {
            HStack(spacing: 0) {
                Text(model.appName)
                    .foregroundColor(.white)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .fixedSize()
            }
            .frame(minWidth: config.activeAppWidth)
            .frame(height: config.widgetHeight)
            .background(.clear)
            .glassEffect()
            .clipShape(RoundedRectangle(cornerRadius: config.widgetCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}