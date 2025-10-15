import Foundation
import SwiftUI
import MacroAPI
import Utilities



@LogFunctions(.Widgets([.aerospaceModel]))
public final class AerospaceModel: ObservableObject, @unchecked Sendable {
    public init() {}

    @Published public var workspaces: [String] = []
    @Published public var focused: String?

    nonisolated(unsafe) private var timer: Timer?

    public func startTimer(interval: TimeInterval) {
        timer?.invalidate()
        updateData()
        timer = Timer.scheduledTimer(timeInterval: interval, target: self, selector: #selector(timerTick(_:)), userInfo: nil, repeats: true)
        if let timer { RunLoop.main.add(timer, forMode: .common) }
    }

    @objc private func timerTick(_ t: Timer) {
        updateData()
    }

    private static func runCommand(_ command: String) -> String {
        let task = Process()
        let pipe = Pipe()
        task.standardError = Pipe()
        task.standardOutput = pipe
        task.arguments = ["-c", command]
        task.launchPath = "/bin/zsh"
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return ""
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func updateData() {
        debug("Updating Data")
        DispatchQueue.global(qos: .userInitiated).async {
            let all = AerospaceModel.runCommand("aerospace list-workspaces --all")
            let focused = AerospaceModel.runCommand("aerospace list-workspaces --focused")
            let parsed = all.components(separatedBy: .newlines).filter { !$0.isEmpty }
            Task { @MainActor [parsed, focused] in
                self.workspaces = parsed
                self.focused = focused
            }
        }
    }

    public func focus(_ id: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            _ = AerospaceModel.runCommand("aerospace workspace \(id)")
        }
    }

    deinit {
        timer?.invalidate()
    }
}

