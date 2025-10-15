import Foundation
import SwiftUI
import MacroAPI

@LogFunctions(.Widgets([.wifiModel]))
@MainActor
public class WiFiModel: ObservableObject {
    @Published var ssid: String? = nil
    @Published var stateIcon: String = "wifi.slash"
    @Published var idealWidth: CGFloat = 120 // Начальная ширина
    
    nonisolated(unsafe) private var timer: Timer?
    private let updateInterval: TimeInterval = 1.0 // 1 секунда

    public init() {
        startAutoUpdate()
    }
    deinit {
        timer?.invalidate()
    }
    
    private func startAutoUpdate() {
        timer?.invalidate()
        update()
        timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
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
        task.standardOutput = pipe
        task.standardError = Pipe()
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
        let cmd = """
        en="$(networksetup -listallhardwareports | awk '/Wi-Fi|AirPort/{getline; print $NF}')"; \
        ipconfig getsummary "$en" | grep -Fxq "  Active : FALSE" || \
        networksetup -listpreferredwirelessnetworks "$en" | sed -n '2s/^\\t//p'
        """
        let result = self.run(cmd)
        info("WiFi update - raw: '\(result)'")
        if result.isEmpty {
            self.ssid = nil
            self.stateIcon = "wifi.slash"
            self.idealWidth = 100
        } else {
            self.ssid = result
            self.stateIcon = "wifi"
            self.idealWidth = self.calculateIdealWidth(for: result)
        }
    }
    
    private func calculateIdealWidth(for text: String) -> CGFloat {
        // Базовые отступы и иконка
        let basePadding: CGFloat = 30
        let iconWidth: CGFloat = 20
        let spacing: CGFloat = 6
        
        // Ориентировочная ширина символа
        let averageCharWidth: CGFloat = 7.5
        
        // Рассчитываем ширину текста
        let textWidth = CGFloat(text.count) * averageCharWidth
        
        // Итоговая ширина с отступами и иконкой
        let totalWidth = basePadding + iconWidth + spacing + textWidth
        
        // Ограничиваем минимальную и максимальную ширину
        return max(100, min(totalWidth, 300))
    }
    
    private func isError(_ result: String) -> Bool {
        return result.contains("You are not associated with an AirPort network") ||
               result.contains("not associated") ||
               result.contains("802.11") || // Это тип Wi-Fi, а не SSID
               result.contains("Active : FALSE") ||
               result.contains("Error:")
    }

    
    // Альтернативная версия с фиксированной высотой но адаптивной шириной
    public func wifiWidget(width: CGFloat, height: CGFloat, cornerRadius: CGFloat) -> some View {
        Button(action: {
            Task { @MainActor in
                self.update()
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: stateIcon)
                    .foregroundColor(.white)
                    .font(.system(size: height * 0.45, weight: .medium))
                    .frame(width: height * 0.45)
                
                Text(ssid ?? "No Wi‑Fi")
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
        .onAppear {
            Task { @MainActor in
                self.update()
            }
        }
    }
}