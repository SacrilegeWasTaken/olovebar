import SwiftUI
import MacroAPI

@LogFunctions(.Widgets([.wifiModel]))
struct WiFiWidgetView: View {
    @ObservedObject var model: WiFiModel
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    var body: some View {
        Button(action: { model.update() }) {
            HStack(spacing: 8) {
                Image(systemName: model.stateIcon)
                    .foregroundColor(.white)
                    .font(.system(size: height * 0.45, weight: .medium))
                    .frame(width: height * 0.45)
                Text(model.ssid ?? "No Wi‑Fi")
                    .foregroundColor(.white)
                    .font(.system(size: height * 0.35, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(height: height)
            .glassEffect()
        }
        .buttonStyle(PlainButtonStyle())
        .background(.clear)
        .cornerRadius(cornerRadius)
        .fixedSize(horizontal: true, vertical: false)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .onAppear { model.update() }
    }
}