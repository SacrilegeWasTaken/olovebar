import SwiftUI
import MacroAPI

@LogFunctions(.Widgets([.dateTimeModel]))
struct DateTimeWidgetView: View {
    @ObservedObject var model: DateTimeModel
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
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
                .frame(width: width, height: height)
                .glassEffect()
            }
            .frame(width: width, height: height)
            .cornerRadius(cornerRadius)
        }
    }
}
