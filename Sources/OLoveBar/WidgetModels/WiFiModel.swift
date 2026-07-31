import Foundation
import SwiftUI
import MacroAPI
import Network
import CoreWLAN


@MainActor
@LogFunctions(.Widgets([.wifiModel]))
final class WiFiModel: ObservableObject {
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
            let interfaceTypes = path.availableInterfaces.map(\.type)
            Task { @MainActor in
                self?.applyNetworkType(interfaceTypes: interfaceTypes)
                self?.update()
            }
        }
        monitor.start(queue: queue)
    }

    private func applyNetworkType(interfaceTypes: [NWInterface.InterfaceType]) {
        if interfaceTypes.contains(.wifi) {
            stateIcon = "wifi"
        } else if interfaceTypes.contains(.wiredEthernet) {
            stateIcon = "cable.connector"
        } else if interfaceTypes.contains(.cellular) {
            stateIcon = "personalhotspot"
        } else {
            stateIcon = "wifi.slash"
        }
        debug("Network type icon: \(stateIcon)")
    }

    func update() {
        Task.detached(priority: .utility) { [weak self] in
            // CoreWLAN gives RSSI directly. SSID may be unavailable without
            // Location Services permission on modern macOS; fall back to
            // networksetup in that case.
            let interface = CWWiFiClient.shared().interface()
            let rssi = interface?.rssiValue() ?? 0
            let wifiActive = interface?.powerOn() ?? false
            var ssid = interface?.ssid()

            if ssid == nil, wifiActive {
                ssid = Self.ssidViaNetworksetup()
            }

            let resolvedSSID = ssid
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.signalStrength = rssi
                self.ssid = resolvedSSID
                if let resolvedSSID {
                    self.idealWidth = self.calculateIdealWidth(for: resolvedSSID)
                } else {
                    self.idealWidth = 100
                }
                self.debug("WiFi update - ssid: \(resolvedSSID ?? "<none>"), rssi: \(rssi)")
            }
        }
    }

    private nonisolated static func ssidViaNetworksetup() -> String? {
        let cmd = """
        en="$(networksetup -listallhardwareports | awk '/Wi-Fi|AirPort/{getline; print $NF}')"; \
        ipconfig getsummary "$en" | grep -Fxq "  Active : FALSE" || \
        networksetup -listpreferredwirelessnetworks "$en" | sed -n '2s/^\\t//p'
        """
        let result = runShell(cmd)
        return result.isEmpty ? nil : result
    }

    /// Runs a shell command on the calling thread (must be called off MainActor).
    private nonisolated static func runShell(_ cmd: String) -> String {
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

    private func calculateIdealWidth(for text: String) -> CGFloat {
        let basePadding: CGFloat = 30
        let iconWidth: CGFloat = 20
        let spacing: CGFloat = 6
        let averageCharWidth: CGFloat = 7.5

        let textWidth = CGFloat(text.count) * averageCharWidth
        let totalWidth = basePadding + iconWidth + spacing + textWidth

        return max(100, min(totalWidth, 300))
    }
}
