import Foundation
import SwiftUI
import MacroAPI

@MainActor
@LogFunctions(.Widgets([.wifiModel]))
public final class WiFiModel: ObservableObject {
    @Published var ssid: String? = nil
    @Published var stateIcon: String = "wifi.slash"
    @Published var idealWidth: CGFloat = 120 
    
    nonisolated(unsafe) private var timer: Timer?
    private let updateInterval: TimeInterval = 1.0

    init() {
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
}