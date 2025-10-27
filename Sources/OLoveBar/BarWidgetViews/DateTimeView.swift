import SwiftUI
import MacroAPI

@LogFunctions(.Widgets([.dateTimeModel]))
struct DateTimeWidgetView: View {
    @ObservedObject var model: DateTimeModel
    @ObservedObject var config: Config
    var body: some View {
        LiquidGlassBackground(
            variant: GlassVariant(rawValue: config.widgetGlassVariant)!,
            cornerRadius: config.widgetCornerRadius
        ) {
            TimelineView(.periodic(from: .now, by: 1.0)) { timeline in
                Button(action: {
                    let url = URL(fileURLWithPath: "/System/Applications/Calendar.app")
                    NSWorkspace.shared.open(url)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .foregroundColor(.white)
                            .background(.clear)
                            .font(.system(size: 12))
                        Text(timeline.date.formatted(date: .abbreviated, time: .standard))
                            .foregroundColor(.white)
                            .background(.clear)
                            .font(.system(size: 12))
                    }
                    .frame(width: config.dateTimeWidth, height: config.widgetHeight)
                }
                .buttonStyle(.plain)
                .frame(width: config.dateTimeWidth, height: config.widgetHeight)
                .cornerRadius(config.widgetCornerRadius)
            }
        }
    }
}
