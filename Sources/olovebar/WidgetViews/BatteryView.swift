import SwiftUI
import MacroAPI

@LogFunctions(.Widgets([.batteryModel]))
struct BatteryWidgetView: View {
    @ObservedObject var model: BatteryModel
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    var body: some View {
        Button(action: {
            let url = URL(fileURLWithPath: "/System/Applications/System Settings.app")
            NSWorkspace.shared.open(url)
        }) {
            HStack(spacing: 6) {
                Image(systemName: model.isCharging ? "battery.100.bolt" : "battery.100")
                    .foregroundColor(.white)
                Text("\(model.percentage)%")
                    .foregroundColor(.white)
                    .font(.system(size: 12))
            }
            .frame(width: width, height: height)
            .glassEffect()
        }
        .background(.clear)
        .cornerRadius(cornerRadius)
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .onAppear { model.startTimer() }
    }
}