import SwiftUI
import Foundation
import MacroAPI

@MainActor
@LogFunctions(.Widgets([.batteryModel]))
public class BatteryModel: ObservableObject {
    @Published var percentage: Int = 100
    @Published var isCharging: Bool = false

    nonisolated(unsafe) private var timer: Timer?

    public init() {
        startTimer()
    }

    deinit {
        timer?.invalidate()
    }



    func startTimer() {
        timer?.invalidate()
        update()
        timer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.update()
            }
        }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
    }

    private func run(_ cmd: String) -> String {
        let task = Process()
        let pipe = Pipe()
        task.standardError = Pipe()
        task.standardOutput = pipe
        task.arguments = ["-c", cmd]
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

    func update() {
        let out = self.run("pmset -g batt")
        if let percentMatch = out.split(separator: "\n").first(where: { $0.contains("%") }) {
            let s = String(percentMatch)
            var newPercent = self.percentage
            if let pRange = s.range(of: "\\d+%", options: .regularExpression) {
                let pStr = s[pRange].replacingOccurrences(of: "%", with: "")
                newPercent = Int(pStr) ?? self.percentage
            }
            let charging = s.contains("charging") || s.contains("AC attached") || s.contains("charged")
            self.percentage = newPercent
            self.isCharging = charging
        }
    }

    public func batteryWidget(width: CGFloat, height: CGFloat, cornerRadius: CGFloat) -> some View {
        Button(action: {
            // open battery preferences
            let url = URL(fileURLWithPath: "/System/Applications/System Settings.app")
            NSWorkspace.shared.open(url)
        }) {
            HStack(spacing: 6) {
                Image(systemName: self.isCharging ? "battery.100.bolt" : "battery.100")
                    .foregroundColor(.white)
                Text("\(self.percentage)%")
                    .foregroundColor(.white)
                    .font(.system(size: 12))
            }
            .frame(width: width, height: height)
            .glassEffect()
        }
        .background(.clear)
        .cornerRadius(cornerRadius)
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .onAppear {
            self.startTimer()
        }
    }
}