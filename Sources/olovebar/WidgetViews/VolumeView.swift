import SwiftUI
import MacroAPI

@LogFunctions(.Widgets([.volumeModel]))
struct VolumeWidgetView: View {
    @ObservedObject var model: VolumeModel
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    var body: some View {
        Button(action: { withAnimation { model.isPopoverPresented.toggle() } }) {
            Image(systemName: "speaker.wave.2.fill")
                .frame(width: width, height: height)
                .foregroundColor(.white)
                .cornerRadius(cornerRadius)
                .glassEffect()
        }
        .background(.clear)
        .buttonStyle(.plain)
        .cornerRadius(cornerRadius)
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
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