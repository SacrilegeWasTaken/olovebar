import SwiftUI
import MacroAPI

@LogFunctions(.Widgets([.activeAppModel]))
struct ActiveAppWidgetView: View {
    @ObservedObject var model: ActiveAppModel
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    var body: some View {
        Button(action: {}) {
            HStack(spacing: 0) {
                Text(model.appName)
                    .foregroundColor(.white)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .fixedSize()
            }
            .frame(minWidth: width)
            .frame(height: height)
            .background(.clear)
            .padding(.horizontal, 16)
            .glassEffect()
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}