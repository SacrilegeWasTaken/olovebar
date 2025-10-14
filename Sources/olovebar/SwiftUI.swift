import SwiftUI
import MacroAPI

let clearColor = NSColor.init(Color.init(cgColor: CGColor.init(red: 0, green: 0, blue: 0, alpha: 0)))

@LogFunctions(.OLoveBar)
struct BarContentView: View {
    @State private var theme_toggle = false

    @StateObject private var aerospaceModel = AerospaceModel()
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
        let wifiWidth: CGFloat = 90
        let batteryWidth: CGFloat = 70
        let languageWidth: CGFloat = 48
        let volumeWidth: CGFloat = 48

        GlassEffectContainer() {
            let view = HStack(spacing: 0) {
                // Left: Apple logo
                appleButton(width: appleButtonWidth, height: widgetHeight, cornerRadius: cornerRadius)

                // Aerospace widget
                aerospaceWidget(width: widgetHeight, height: widgetHeight, cornerRadius: cornerRadius)

                self.activeAppModel.activeApp(width: 70, height: widgetHeight, cornerRadius: cornerRadius)

                Spacer()

                // Right-side  wifi, battery, language, volume
                HStack(spacing: 8) {
                    self.wifiModel.wifiWidget(width: wifiWidth, height: widgetHeight, cornerRadius: cornerRadius)
                    self.batteryModel.batteryWidget(width: batteryWidth, height: widgetHeight, cornerRadius: cornerRadius)
                    self.languageModel.languageWidget(width: languageWidth, height: widgetHeight, cornerRadius: cornerRadius)
                    self.volumeModel.volumeWidget(width: volumeWidth, height: widgetHeight, cornerRadius: cornerRadius)
                    timeButton(width: timeButtonWidth, height: widgetHeight, cornerRadius: cornerRadius)
                }

                // Right: live-updating clock
            }
            if self.theme_toggle {
                view.glassEffect()
            } else {
                view
            }
        }
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

    func aerospaceWidget(width: CGFloat, height: CGFloat, cornerRadius: CGFloat) -> some View {
        GlassEffectContainer { 
            HStack(spacing: 4) { 
                let _ = debug("Updating UI. Focused: \(String(describing: self.focused))")
                ForEach(aerospaceModel.workspaces, id: \.self) { id in
                    Button(action: {
                        withAnimation {
                            self.aerospaceModel.focus(id)
                        }
                    }) {
                        let _ = self.debug("Drawing text UI")
                        Text(id)
                            .font(.system(size: 12, weight: .medium))
                            .frame(width: width, height: height)
                            .foregroundColor(.white)
                            .background(.clear)
                            .glassEffect(id == self.aerospaceModel.focused ? .clear.tint(.orange) : .clear)
                    }
                    .background(.clear)
                    .cornerRadius(cornerRadius)
                    .frame(width: width, height: height)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .animation(.easeInOut(duration: 0.15), value: self.aerospaceModel.focused)
                }
            }
            .padding(.horizontal, 26)
            .frame(height: height)
            .onAppear {
                self.aerospaceModel.startTimer(interval: 0.1) // запускаем обновление каждые 0.1 сек
            }
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