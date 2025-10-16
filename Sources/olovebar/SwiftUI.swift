import SwiftUI
import MacroAPI


@LogFunctions(.OLoveBar)
struct BarContentView: View {
    @State private var theme_toggle = true

    @StateObject private var aerospaceModel = AerospaceModel()
    @StateObject private var wifiModel = WiFiModel()
    @StateObject private var batteryModel = BatteryModel()
    @StateObject private var languageModel = LanguageModel()
    @StateObject private var volumeModel = VolumeModel()
    @StateObject private var activeAppModel = ActiveAppModel()

    @Namespace private var namespace
    @State var variant = 11
    @State var cornerRadius: Double = 30
      
    var body: some View {
        let appleButtonWidth: CGFloat = 45
        let timeButtonWidth: CGFloat = 190
        let widgetHeight: CGFloat = 33
        let cornerRadius: CGFloat = 16
        let wifiWidth: CGFloat = 90
        let batteryWidth: CGFloat = 70
        let languageWidth: CGFloat = 48
        let volumeWidth: CGFloat = 48
        ZStack {
            if self.theme_toggle {
                LiquidGlassBackground(
                    variant: GlassVariant(rawValue: variant) ?? .v11,
                    cornerRadius: cornerRadius
                ) {
                    Color.clear
                }
            }

            HStack(spacing: 0) {
                // Left: Apple logo
                appleButton(width: appleButtonWidth, height: widgetHeight, cornerRadius: cornerRadius)

                // Aerospace widget
                AerospaceView(model: aerospaceModel, width: widgetHeight, height: widgetHeight, cornerRadius: cornerRadius)

                ActiveAppView(model: activeAppModel, width: 70, height: widgetHeight, cornerRadius: cornerRadius)

                Spacer()

                // Right-side  wifi, battery, language, volume
                HStack(spacing: 8) {
                    WiFiView(model: wifiModel, width: wifiWidth, height: widgetHeight, cornerRadius: cornerRadius)
                    BatteryView(model: batteryModel, width: batteryWidth, height: widgetHeight, cornerRadius: cornerRadius)
                    LanguageView(model: languageModel, width: languageWidth, height: widgetHeight, cornerRadius: cornerRadius)
                    VolumeView(model: volumeModel, width: volumeWidth, height: widgetHeight, cornerRadius: cornerRadius)
                    timeButton(width: timeButtonWidth, height: widgetHeight, cornerRadius: cornerRadius)
                }
            }
            
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }





    // MARK: - Apple Logo Button
    func appleButton(width: CGFloat, height: CGFloat, cornerRadius: CGFloat) -> some View {
       Button(action: {
            self.theme_toggle.toggle()
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

// MARK: - Separated UI Views

struct ActiveAppView: View {
    @ObservedObject var model: ActiveAppModel
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    var body: some View {
        Button(action: {}) {
            HStack(spacing: 0) {
                Text(model.appName)
                    .foregroundColor(.white)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .fixedSize()
            }
            .frame(minWidth: width)
            .frame(height: height)
            .background(.clear)
            .padding(.horizontal, 16)
            .glassEffect()
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct WiFiView: View {
    @ObservedObject var model: WiFiModel
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    var body: some View {
        Button(action: { model.update() }) {
            HStack(spacing: 8) {
                Image(systemName: model.stateIcon)
                    .foregroundColor(.white)
                    .font(.system(size: height * 0.45, weight: .medium))
                    .frame(width: height * 0.45)
                Text(model.ssid ?? "No Wi‑Fi")
                    .foregroundColor(.white)
                    .font(.system(size: height * 0.35, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(height: height)
            .glassEffect()
        }
        .buttonStyle(PlainButtonStyle())
        .background(.clear)
        .cornerRadius(cornerRadius)
        .fixedSize(horizontal: true, vertical: false)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .onAppear { model.update() }
    }
}

struct BatteryView: View {
    @ObservedObject var model: BatteryModel
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    var body: some View {
        Button(action: {
            let url = URL(fileURLWithPath: "/System/Applications/System Settings.app")
            NSWorkspace.shared.open(url)
        }) {
            HStack(spacing: 6) {
                Image(systemName: model.isCharging ? "battery.100.bolt" : "battery.100")
                    .foregroundColor(.white)
                Text("\(model.percentage)%")
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
        .onAppear { model.startTimer() }
    }
}

struct LanguageView: View {
    @ObservedObject var model: LanguageModel
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    var body: some View {
        Button(action: { model.toggle() }) {
            Text(model.current)
                .foregroundColor(.white)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: width, height: height)
                .glassEffect()
        }
        .background(.clear)
        .cornerRadius(cornerRadius)
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .onAppear { model.update() }
    }
}

struct VolumeView: View {
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

struct AerospaceView: View {
    @ObservedObject var model: AerospaceModel
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    var body: some View {
        GlassEffectContainer {
            HStack(spacing: 0) {
                let _ = debug("Updating UI. Focused: \(String(describing: model.focused))", module: .Widgets([.aerospaceModel]), file: #file, function: #function, line: #line)
                ForEach(model.workspaces, id: \.self) { id in
                    Button(action: { withAnimation { model.focus(id) } }) {
                        let _ = debug("Drawing text UI", module: .Widgets([.aerospaceModel]), file: #file, function: #function, line: #line)
                        Text(id)
                            .font(.system(size: 12, weight: .medium))
                            .frame(width: width, height: height)
                            .foregroundColor(id == model.focused ? .purple : .white)
                            .background(.clear)
                            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .background(.clear)
                    .frame(width: width, height: height)
                    .animation(.easeInOut(duration: 0.1), value: model.focused)
                }
            }
            .glassEffect(.regular.interactive(), in: .capsule)
            .glassEffectTransition(.matchedGeometry)
            .background(.clear)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .padding(.horizontal, 26)
            .frame(height: height)
            .onAppear { model.startTimer(interval: 0.1) }
        }
    }
}