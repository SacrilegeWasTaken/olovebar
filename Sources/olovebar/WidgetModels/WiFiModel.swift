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
    @Published var signalStrength: Int = 0
    
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
        let interfaces = path.availableInterfaces
        
        if let interface = interfaces.first(where: { $0.type == .wifi }) {
            updateWiFiSignal(interface: interface.name)
            info("WiFi update - type: wifi (\(interface.name)), signal: \(signalStrength)")
        } else if let interface = interfaces.first(where: { $0.type == .wiredEthernet }) {
            stateIcon = "cable.connector"
            info("WiFi update - type: ethernet (\(interface.name))")
        } else if let interface = interfaces.first(where: { $0.type == .cellular }) {
            stateIcon = "personalhotspot"
            info("WiFi update - type: cellular (\(interface.name))")
        } else {
            stateIcon = "wifi.slash"
            info("WiFi update - type: none")
        }
    }
    
    private func updateWiFiSignal(interface: String) {
        let cmd = "/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I | awk '/ agrCtlRSSI/ {print $2}'"
        let result = run(cmd)
        signalStrength = Int(result) ?? 0
        
        if signalStrength >= -50 {
            stateIcon = "wifi"
        } else if signalStrength >= -60 {
            stateIcon = "wifi"
        } else if signalStrength >= -70 {
            stateIcon = "wifi"
        } else {
            stateIcon = "wifi"
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