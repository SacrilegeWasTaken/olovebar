import SwiftUI
import MacroAPI
import AVFoundation

@LogFunctions(.Widgets([.volumeModel]))
struct VolumeWidgetView: View {
    @ObservedObject var model: VolumeModel
    @ObservedObject var config: Config
    var body: some View {
        LiquidGlassBackground(
            variant: GlassVariant(rawValue: config.widgetGlassVariant)!,
            cornerRadius: config.widgetCornerRadius
        ) {
            Button(action: { withAnimation { model.isPopoverPresented.toggle() } }) {
                Image(systemName: "speaker.wave.2.fill")
                    .frame(width: config.volumeWidth, height: config.widgetHeight)
                    .foregroundColor(.white)
                    .cornerRadius(config.widgetCornerRadius)
            }
            .background(.clear)
            .buttonStyle(.plain)
            .cornerRadius(config.widgetCornerRadius)
            .frame(width: config.volumeWidth, height: config.widgetHeight)
            .clipShape(RoundedRectangle(cornerRadius: config.widgetCornerRadius, style: .continuous))
            .popover(isPresented: Binding(get: { model.isPopoverPresented }, set: { model.isPopoverPresented = $0 })) {
                VStack(spacing: 12) {
                    Slider(value: Binding(get: { model.level }, set: { val in model.set(val) }), in: 0...1)
                    .frame(width: 200)
                    .padding()
                }
                .frame(width: 240, height: 40)
            }
        }
    }
}