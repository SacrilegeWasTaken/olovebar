import SwiftUI
import Foundation
import MacroAPI

@MainActor
@LogFunctions(.Widgets([.volumeModel]))
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
}