import SwiftUI
import Foundation

@MainActor
public class VolumeModel: ObservableObject {
    @Published var level: Double = 50
    @Published var isPopoverPresented: Bool = false

    public init() {
        update()
    }

    private func run(_ cmd: String) -> String {
        let task = Process()
        let pipe = Pipe()
        task.standardOutput = pipe
        task.arguments = ["-c", cmd]
        task.launchPath = "/bin/zsh"
        do { try task.run(); task.waitUntilExit() } catch { return "" }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func update() {
        let out = self.run("osascript -e 'output volume of (get volume settings)'")
        if let v = Double(out) { self.level = v }
    }

    @MainActor
    func set(_ value: Double) {
        let v = Int(value)
        // run applescript to set system volume
        _ = run("osascript -e 'set volume output volume \(v)'")
        // Also update cached value
        self.level = value
    }

    public func volumeWidget(width: CGFloat, height: CGFloat, cornerRadius: CGFloat) -> some View {
        Button(action: {
            withAnimation { self.isPopoverPresented.toggle() }
        }) {
            Image(systemName: "speaker.wave.2.fill")
                .frame(width: width, height: height)
                .foregroundColor(.white)
                .cornerRadius(cornerRadius)
                .glassEffect()
        }
        .background(.clear)
        .cornerRadius(cornerRadius)
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .popover(isPresented: Binding(get: { self.isPopoverPresented }, set: { self.isPopoverPresented = $0 })) {
            VStack(spacing: 12) {
                Slider(value: Binding(get: { self.level }, set: { new in
                    self.level = new
                    // set system volume
                    DispatchQueue.global(qos: .userInitiated).async {
                        let cmd = "osascript -e 'set volume output volume \(Int(new))'"
                        // run inline to avoid calling main-actor isolated helper
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