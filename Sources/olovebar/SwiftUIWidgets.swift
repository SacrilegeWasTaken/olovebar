import SwiftUI

let clearColor = NSColor.init(Color.init(cgColor: CGColor.init(red: 0, green: 0, blue: 0, alpha: 0)))

struct BarContentView: View {
    @State private var toggle = false
    @StateObject private var aerospaceModel = AerospaceModel() // ObservableObject для спейсов
    @Namespace private var aerospaceNamespace    
    @State private var isSingleShape: Bool = true
    // New widget models
    @StateObject private var wifiModel = WiFiModel()
    @StateObject private var batteryModel = BatteryModel()
    @StateObject private var languageModel = LanguageModel()
    @StateObject private var volumeModel = VolumeModel()
    @StateObject private var activeAppModel = ActiveAppModel()

    var body: some View {
        let appleButtonWidth: CGFloat = 45
        let timeButtonWidth: CGFloat = 190
        let widgetHeight: CGFloat = 33
        let cornerRadius: CGFloat = 16

        GlassEffectContainer() {
            let view = HStack(spacing: 0) {
                // Left: Apple logo
                appleButton(width: appleButtonWidth, height: widgetHeight, cornerRadius: cornerRadius)

                // Aerospace widget
                aerospaceWidget(width: widgetHeight, height: widgetHeight, cornerRadius: cornerRadius)

                activeApp(width: 70, height: widgetHeight, cornerRadius: cornerRadius)

                Spacer()

                // Right-side widgets: wifi, battery, language, volume
                HStack(spacing: 8) {
                    wifiWidget(width: 90, height: widgetHeight, cornerRadius: cornerRadius)
                    batteryWidget(width: 70, height: widgetHeight, cornerRadius: cornerRadius)
                    languageWidget(width: 48, height: widgetHeight, cornerRadius: cornerRadius)
                    volumeWidget(width: 48, height: widgetHeight, cornerRadius: cornerRadius)
                    timeButton(width: timeButtonWidth, height: widgetHeight, cornerRadius: cornerRadius)
                }

                // Right: live-updating clock
            }
            if self.toggle {
                view.glassEffect()
            } else {
                view
            }
        }
    }


    func activeApp(width: CGFloat, height: CGFloat, cornerRadius: CGFloat) -> some View {
        Button(action: {
            // lol
        }) {
            HStack(spacing: 0) {
                Text(activeAppModel.appName)
                    .foregroundColor(.white)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .fixedSize() // текст задаёт ширину HStack
            }
            .frame(minWidth: width) // минимальная ширина
            .frame(height: height)
            .background(.clear)
            .padding(.horizontal, 16)
            .glassEffect() // применяем к HStack
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }




    // MARK: - Apple Logo Button
    func appleButton(width: CGFloat, height: CGFloat, cornerRadius: CGFloat) -> some View {
        Button(action: {
            self.toggle.toggle()
        }) {
            Image(systemName: "apple.logo")
                .frame(width: width, height: height)
                .foregroundColor(.white)
                .background(.clear)
                .font(.system(size: 15, weight: .semibold))
                .cornerRadius(cornerRadius)
                .glassEffect()
        }
        .background(.clear)
        .frame(width: width, height: height)
        .cornerRadius(cornerRadius)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    // MARK: - Time Button
    func timeButton(width: CGFloat, height: CGFloat, cornerRadius: CGFloat) -> some View {
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

    // MARK: - Aerospace Widget
    func aerospaceWidget(width: CGFloat, height: CGFloat, cornerRadius: CGFloat) -> some View {
        GlassEffectContainer {            
            HStack(spacing: 4) { 
                ForEach(aerospaceModel.workspaces, id: \.self) { id in
                    Button(action: {
                        withAnimation {
                            isSingleShape.toggle()
                            aerospaceModel.focus(id)
                        }
                    }) {
                        Text(id)
                            .font(.system(size: 12, weight: .medium))
                            .frame(width: width, height: height)
                            .foregroundColor(.white)
                            .background(.clear)
                            .glassEffect(id == aerospaceModel.focused ? .clear.tint(.orange) : .clear)
                            .glassEffectID(id, in: aerospaceNamespace)
                    }
                    .background(.clear)
                    .cornerRadius(cornerRadius)
                    .frame(width: width, height: height)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .animation(.easeInOut(duration: 0.15), value: aerospaceModel.focused)
                }
            }
            .padding(.horizontal, 26)
            .frame(height: height)
            .onAppear {
                aerospaceModel.startTimer(interval: 0.1) // запускаем обновление каждые 0.1 сек
            }
        }
    }
}

// MARK: - Aerospace Model

@MainActor
final class AerospaceModel: ObservableObject {
    @Published var workspaces: [String] = []
    @Published var focused: String?

    private var timer: Timer?

    func startTimer(interval: TimeInterval) {
        timer?.invalidate()
        updateData()
        // Use selector-based timer to avoid Sendable capture issues
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

    func updateData() {
        let all = runCommand("aerospace list-workspaces --all")
        let focused = runCommand("aerospace list-workspaces --focused")
        DispatchQueue.main.async {
            self.workspaces = all.components(separatedBy: .newlines).filter { !$0.isEmpty }
            self.focused = focused
        }
    }

    func focus(_ id: String) {
        DispatchQueue.main.async {
            _ = self.runCommand("aerospace workspace \(id)")
        }
    }
}

// MARK: - WiFi, Battery, Language, Volume Models and Widget Views

@MainActor
final class WiFiModel: ObservableObject {
    @Published var ssid: String? = nil
    @Published var stateIcon: String = "wifi.slash"

    init() {
        update()
    }

    private func run(_ cmd: String) -> String {
        let task = Process()
        let pipe = Pipe()
        task.standardError = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        task.arguments = ["-c", cmd]
        task.launchPath = "/bin/zsh"
        task.launch()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func update() {
        // Try to read Wi‑Fi SSID via airport if present, otherwise fallback to networksetup
        let airportPath = "/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport"
        var ssidOut = ""
        if FileManager.default.fileExists(atPath: airportPath) {
            let cmd = "\(airportPath) -I | awk -F': ' '/ SSID/ {print $2}'"
            ssidOut = run(cmd)
        } else {
            // find Wi‑Fi device (en0/en1...) and query networksetup
            let devCmd = "networksetup -listallhardwareports | awk '/Wi-?Fi|AirPort/{getline; print $2; exit}'"
            let dev = run(devCmd)
            if !dev.isEmpty {
                let cmd = "networksetup -getairportnetwork \(dev)"
                ssidOut = run(cmd).replacingOccurrences(of: "Current Wi-Fi Network: ", with: "").replacingOccurrences(of: "You are not associated with an AirPort network.", with: "")
            }
        }
        if ssidOut.isEmpty {
            ssid = nil
            stateIcon = "wifi.slash"
        } else {
            ssid = ssidOut
            stateIcon = "wifi"
        }
    }
}

@MainActor
final class BatteryModel: ObservableObject {
    @Published var percentage: Int = 100
    @Published var isCharging: Bool = false

    private var timer: Timer?

    init() {
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
}

@MainActor
final class LanguageModel: ObservableObject {
    @Published var current: String = "EN"

    init() {
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
        // Try to get current input source using AppleScript
        let script = "osascript -e 'tell application \"System Events\" to get name of first input source whose selected is true'"
        let out = run(script)
        self.current = out.isEmpty ? "EN" : out
    }

    func toggle() {
        // Switch to the next input source using AppleScript
        let script = "osascript -e 'tell application \"System Events\" to select (first input source whose selected is false)'"
        // run synchronously (quick) and update
        let task = Process()
        let pipe = Pipe()
        task.standardError = Pipe()
        task.standardOutput = pipe
        task.arguments = ["-c", script]
        task.launchPath = "/bin/zsh"
        task.launch()
        _ = pipe.fileHandleForReading.readDataToEndOfFile()
        Thread.sleep(forTimeInterval: 0.2)
        update()
    }
}

@MainActor
final class VolumeModel: ObservableObject {
    @Published var level: Double = 50
    @Published var isPopoverPresented: Bool = false

    init() {
        update()
    }

    private func run(_ cmd: String) -> String {
        let task = Process()
        let pipe = Pipe()
        task.standardOutput = pipe
        task.arguments = ["-c", cmd]
        task.launchPath = "/bin/zsh"
        task.launch()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func update() {
        // Get output volume using AppleScript
        let out = run("osascript -e 'output volume of (get volume settings)'")
        if let v = Double(out) { level = v }
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

@MainActor
final class ActiveAppModel: ObservableObject {
    @Published var bundleID: String = ""
    @Published var appName: String = ""

    private var timer: Timer?

    init() {
        startTimer()
    }

    func startTimer() {
        timer?.invalidate()
        update()
        timer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(tick(_:)), userInfo: nil, repeats: true)
    }

    @objc private func tick(_ t: Timer) {
        update()
    }

    func update() {
        if let app = NSWorkspace.shared.frontmostApplication {
            let name = app.localizedName ?? ""
            let bid = app.bundleIdentifier ?? ""
            self.appName = name
            self.bundleID = bid
        } else {
            self.appName = "None"
            self.bundleID = ""
        }
    }
}

extension BarContentView {
    // WiFi widget (read-only)
    func wifiWidget(width: CGFloat, height: CGFloat, cornerRadius: CGFloat) -> some View {
        Button(action: {}) {
            HStack(spacing: 6) {
                Image(systemName: wifiModel.stateIcon)
                    .foregroundColor(.white)
                Text(wifiModel.ssid ?? "No Wi‑Fi")
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
            wifiModel.update()
        }
    }

    // Battery widget
    func batteryWidget(width: CGFloat, height: CGFloat, cornerRadius: CGFloat) -> some View {
        Button(action: {
            // open battery preferences
            let url = URL(fileURLWithPath: "/System/Applications/System Settings.app")
            NSWorkspace.shared.open(url)
        }) {
            HStack(spacing: 6) {
                Image(systemName: batteryModel.isCharging ? "battery.100.bolt" : "battery.100")
                    .foregroundColor(.white)
                Text("\(batteryModel.percentage)%")
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
            batteryModel.startTimer()
        }
    }

    // Language widget
    func languageWidget(width: CGFloat, height: CGFloat, cornerRadius: CGFloat) -> some View {
        Button(action: {
            languageModel.toggle()
        }) {
            Text(languageModel.current)
                .foregroundColor(.white)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: width, height: height)
                .glassEffect()
        }
        .background(.clear)
        .cornerRadius(cornerRadius)
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .onAppear { languageModel.update() }
    }

    // Volume widget with popover slider
    func volumeWidget(width: CGFloat, height: CGFloat, cornerRadius: CGFloat) -> some View {
        Button(action: {
            withAnimation { volumeModel.isPopoverPresented.toggle() }
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
        .popover(isPresented: $volumeModel.isPopoverPresented) {
            VStack(spacing: 12) {
                Slider(value: Binding(get: { volumeModel.level }, set: { new in
                    volumeModel.level = new
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


    static func runShell(_ cmd: String) -> String {
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
}
