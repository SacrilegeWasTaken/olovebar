import SwiftUI
import MacroAPI

@LogFunctions(.Widgets([.batteryModel]))
struct BatteryWidgetView: View {
    @ObservedObject var model: BatteryModel
    @ObservedObject var config: Config
    
    var batteryColor: Color {
        if model.isLowPowerMode { return .yellow.opacity(0.9) }
        if model.percentage <= 20 { return .red }
        return .white
    }
    
    var body: some View {
        LiquidGlassBackground(
            variant: GlassVariant(rawValue: config.widgetGlassVariant)!,
            cornerRadius: config.widgetCornerRadius
        ) {
            Button(action: {
                let url = URL(fileURLWithPath: "/System/Applications/System Settings.app")
                NSWorkspace.shared.open(url)
            }) {
                HStack(spacing: 6) {
                    ZStack {
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(.white.opacity(0.8), lineWidth: 0.85)
                                .frame(width: 22, height: 11)
                                .mask(Rectangle().frame(width: .infinity, height: .infinity).cornerRadius(3).blendMode(.overlay))
                            
                            RoundedRectangle(cornerRadius: 2.5)
                                .fill(batteryColor)
                                .frame(width: max(2.5, CGFloat(model.percentage) / 100 * 19), height: 8)
                                .padding(.leading, 1.5)
                                .animation(.easeInOut(duration: 0.3), value: model.percentage)
                        }
                        .mask(
                            ZStack {
                                Rectangle().frame(width: .infinity, height: .infinity).cornerRadius(3).blendMode(.overlay)
                                if model.isCharging {
                                    let shadow_size: CGFloat = 0.2
                                    Image(systemName: "bolt.fill")
                                        .font(.system(size: 11, weight: .regular))
                                        .shadow(color: .black, radius: 0, x: shadow_size, y: 0)
                                        .shadow(color: .black, radius: 0, x: -shadow_size, y: 0)
                                        .shadow(color: .black, radius: 0, x: 0, y: shadow_size)
                                        .shadow(color: .black, radius: 0, x: 0, y: -shadow_size)
                                        .shadow(color: .black, radius: 0, x: shadow_size, y: shadow_size)
                                        .shadow(color: .black, radius: 0, x: -shadow_size, y: -shadow_size)
                                        .shadow(color: .black, radius: 0, x: shadow_size, y: -shadow_size)
                                        .shadow(color: .black, radius: 0, x: -shadow_size, y: shadow_size)
                                        .blendMode(.destinationOut)
                                }
                            }
                        )
                        
                        RoundedRectangle(cornerRadius: 1)
                            .fill(batteryColor.opacity(0.6))
                            .frame(width: 1.5, height: 4)
                            .offset(x: 12)
                        
                        if model.isCharging {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 11, weight: .regular))
                        }
                    }
                    
                    Text("\(model.percentage!)%")
                        .foregroundColor(.white)
                        .font(.system(size: 12))
                }
                .frame(width: config.batteryWidth, height: config.widgetHeight)
            }
            .buttonStyle(.plain)
            .background(.clear)
            .cornerRadius(config.widgetCornerRadius)
            .frame(width: config.batteryWidth, height: config.widgetHeight)
            .clipShape(RoundedRectangle(cornerRadius: config.widgetCornerRadius, style: .continuous))
        }
    }
}