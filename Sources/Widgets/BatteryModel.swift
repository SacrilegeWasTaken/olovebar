import SwiftUI
import Foundation
import MacroAPI

@MainActor
public class BatteryModel: ObservableObject {
    @Published var percentage: Int = 100
    @Published var isCharging: Bool = false

    var timer: Timer?

    public init() {
        startTimer()
    }



    func startTimer() {
        timer?.invalidate()
        update()
        timer = Timer.scheduledTimer(timeInterval: 15.0, target: self, selector: #selector(batteryTimerTick(_:)), userInfo: nil, repeats: true)
    }
    @objc private func batteryTimerTick(_ t: Timer) {
        update()
    }

    private func run(_ cmd: String) -> String {
        let task = Process()
        let pipe = Pipe()
        task.standardError = Pipe()
        task.standardOutput = pipe
        task.arguments = ["-c", cmd]
        task.launchPath = "/bin/zsh"
        task.launch()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func update() {
        // Use pmset -g batt to get battery percentage and charging state
        let out = run("pmset -g batt")
        // Example line: ' -InternalBattery-0 (id=1234567) 85%; discharging; ...'
        if let percentMatch = out.split(separator: "\n").first(where: { $0.contains("%") }) {
            let s = String(percentMatch)
            var newPercent = percentage
            if let pRange = s.range(of: "\\d+%", options: .regularExpression) {
                let pStr = s[pRange].replacingOccurrences(of: "%", with: "")
                newPercent = Int(pStr) ?? percentage
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