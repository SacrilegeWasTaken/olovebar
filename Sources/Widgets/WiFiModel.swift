import Foundation
import SwiftUI

@MainActor
public class WiFiModel: ObservableObject {
    @Published var ssid: String? = nil
    @Published var stateIcon: String = "wifi.slash"

    public init() {
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

    public func wifiWidget(width: CGFloat, height: CGFloat, cornerRadius: CGFloat) -> some View {
        Button(action: {}) {
            HStack(spacing: 6) {
                Image(systemName: stateIcon)
                    .foregroundColor(.white)
                Text(ssid ?? "No Wi‑Fi")
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
            self.update()
        }
    }
}