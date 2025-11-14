import SwiftUI
import MacroAPI

@LogFunctions(.Widgets([.dateTimeModel]))
struct DateTimeWidgetView: View {
    @ObservedObject var config: Config


    @ObservedObject var model = GlobalModels.shared.dateTimeModel

    
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { timeline in
            Button(action: {
                let url = URL(fileURLWithPath: "/System/Applications/Calendar.app")
                NSWorkspace.shared.open(url)
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .foregroundColor(.white)
                        .font(.system(size: 12))
                    Text(timeline.date.formatted(date: .abbreviated, time: .standard))
                        .foregroundColor(.white)
                        .font(.system(size: 12))
                }
                .frame(width: config.dateTimeWidth, height: config.widgetHeight)
                .background(
                    LiquidGlassBackground(
                        variant: GlassVariant(rawValue: config.widgetGlassVariant)!,
                        cornerRadius: config.widgetCornerRadius
                    ) {}
                )
                .cornerRadius(config.widgetCornerRadius)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}
