import Foundation
import SwiftUI
import MacroAPI
import Utilities



@MainActor
@LogFunctions(.Widgets([.aerospaceModel]))
public final class AerospaceModel: ObservableObject {
    public init() {}

    @Published public var workspaces: [String] = []
    @Published public var focused: String?

    var timer: Timer?

    public func startTimer(interval: TimeInterval) {
        timer?.invalidate()
        updateData()
        timer = Timer.scheduledTimer(timeInterval: interval, target: self, selector: #selector(timerTick(_:)), userInfo: nil, repeats: true)
    }

    @objc private func timerTick(_ t: Timer) {
        updateData()
    }

    private func runCommand(_ command: String) -> String {
        let task = Process()
        let pipe = Pipe()
        task.standardError = Pipe()
        task.standardOutput = pipe
        task.arguments = ["-c", command]
        task.launchPath = "/bin/zsh"
        task.launch()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func updateData() {
        debug("Updating Data")
        let all = runCommand("aerospace list-workspaces --all")
        let focused = runCommand("aerospace list-workspaces --focused")
        DispatchQueue.main.async {
            self.workspaces = all.components(separatedBy: .newlines).filter { !$0.isEmpty }
            self.focused = focused
        }
    }

    public func focus(_ id: String) {
        DispatchQueue.main.async {
            _ = self.runCommand("aerospace workspace \(id)")
        }
    }
}
