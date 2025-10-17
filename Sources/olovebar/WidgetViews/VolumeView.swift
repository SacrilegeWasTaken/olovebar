import SwiftUI
import MacroAPI

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
                    Slider(value: Binding(get: { model.level }, set: { new in
                        model.level = new
                        DispatchQueue.global(qos: .userInitiated).async {
                            let cmd = "osascript -e 'set volume output volume \(Int(new))'"
                            let task = Process()
                            let pipe = Pipe()
                            task.standardError = Pipe()
                            task.standardOutput = pipe
                            task.arguments = ["-c", cmd]
                            task.launchPath = "/bin/zsh"
                            task.launch()
                            _ = pipe.fileHandleForReading.readDataToEndOfFile()
                        }
                    }), in: 0...100)
                    .frame(width: 200)
                    .padding()
                }
                .frame(width: 240, height: 40)
            }
        }
    }
}