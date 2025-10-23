import Foundation
import SwiftUI
import MacroAPI
import Network

@MainActor
@LogFunctions(.Widgets([.wifiModel]))
public final class WiFiModel: ObservableObject {
    @Published var ssid: String? = nil
    @Published var stateIcon: String = "wifi.slash"
    @Published var idealWidth: CGFloat = 120
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "WiFiMonitor")

    init() {
        setupNetworkMonitoring()
        update()
    }
    
    deinit {
        monitor.cancel()
    }
    
    private func setupNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.update()
                self?.updateNetworkType(path: path)
            }
        }
        monitor.start(queue: queue)
    }
    
    private func updateNetworkType(path: NWPath) {
        if path.usesInterfaceType(.wifi) {
            stateIcon = "wifi"
        } else if path.usesInterfaceType(.wiredEthernet) {
            stateIcon = "cable.connector"
        } else if path.usesInterfaceType(.cellular) {
            stateIcon = "personalhotspot"
        } else {
            stateIcon = "wifi.slash"
        }
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
            self.idealWidth = 100
        } else {
            self.ssid = result
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