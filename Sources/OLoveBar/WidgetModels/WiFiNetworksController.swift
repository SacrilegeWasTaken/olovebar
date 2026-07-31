import Foundation
import CoreWLAN
import CoreLocation
import SwiftUI
import MacroAPI

struct ScannedNetwork: Identifiable, @unchecked Sendable {
    let id: String
    let ssid: String
    /// nil when the network is known from a saved profile but not currently in range.
    let rssi: Int?
    let isSecure: Bool
    let isHotspot: Bool
    let isKnown: Bool
    /// The scan result object required by `associate(to:password:)`.
    /// nil for profile-only entries; connecting re-scans by name first.
    let network: CWNetwork?

    /// 0...1 fraction for the variable-value wifi symbol; nil when not in range.
    var signalFraction: Double? {
        rssi.map { min(1, max(0, (Double($0) + 90) / 40)) }
    }
}

private struct WiFiSnapshot: @unchecked Sendable {
    var isPowerOn = false
    var currentSSID: String?
    var currentNetwork: ScannedNetwork?
    var hotspots: [ScannedNetwork] = []
    var known: [ScannedNetwork] = []
    var others: [ScannedNetwork] = []
}

/// Scanning, connecting and power control for the macOS-style Wi-Fi menu.
/// All CoreWLAN calls (scan/associate block for seconds) run off the main thread.
@MainActor
@LogFunctions(.Widgets([.wifiModel]))
final class WiFiNetworksController: ObservableObject {
    static let shared = WiFiNetworksController()

    @Published var isPowerOn = false
    @Published var currentSSID: String?
    /// Full scan entry for the connected network (kept even though it is
    /// excluded from the other lists), so its row shows the lock/signal.
    @Published var currentNetwork: ScannedNetwork?
    @Published var hotspots: [ScannedNetwork] = []
    @Published var known: [ScannedNetwork] = []
    @Published var others: [ScannedNetwork] = []
    @Published var isScanning = false
    @Published var connectingSSID: String?
    /// SSID whose row is expanded into an inline password prompt.
    @Published var passwordPromptSSID: String?
    @Published var lastError: String?

    private var scanTask: Task<Void, Never>?
    private var refreshTimer: Timer?
    /// Reading Wi-Fi SSIDs from a scan requires Location Services authorization;
    /// without it CWNetwork.ssid returns nil for every scanned network.
    private let locationManager = CLLocationManager()

    func requestLocationIfNeeded() {
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
    }

    func menuOpened() {
        lastError = nil
        passwordPromptSSID = nil
        requestLocationIfNeeded()
        refresh()
        // .common mode so periodic rescans keep firing while the NSMenu is
        // tracking (default-mode timers are starved during menu tracking).
        let timer = Timer(timeInterval: 6.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }

    func menuClosed() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
    }

    func refresh() {
        guard scanTask == nil else { return }
        isScanning = true
        scanTask = Task { [weak self] in
            let snapshot = await Self.performScan()
            guard let self, !Task.isCancelled else { return }
            self.isPowerOn = snapshot.isPowerOn
            self.currentSSID = snapshot.currentSSID
            self.currentNetwork = snapshot.currentNetwork
            self.hotspots = snapshot.hotspots
            self.known = snapshot.known
            self.others = snapshot.others
            self.isScanning = false
            self.scanTask = nil
        }
    }

    func setPower(_ on: Bool) {
        isPowerOn = on
        if !on {
            hotspots = []
            known = []
            others = []
            currentSSID = nil
        }
        Task { [weak self] in
            await Self.onBackground {
                try? CWWiFiClient.shared().interface()?.setPower(on)
            }
            if on {
                // Give the interface a moment to come up before the first scan.
                try? await Task.sleep(for: .seconds(1))
                self?.refresh()
            }
        }
    }

    func connect(to network: ScannedNetwork, password: String? = nil) {
        guard connectingSSID == nil else { return }
        connectingSSID = network.ssid
        lastError = nil

        Task { [weak self] in
            let error: String? = await Self.onBackground {
                guard let interface = CWWiFiClient.shared().interface() else {
                    return "Wi-Fi interface unavailable"
                }

                // Profile-only entries (e.g. a hotspot that was not broadcasting
                // during the last scan) need a live scan result to associate to.
                var target = network.network
                if target == nil {
                    target = (try? interface.scanForNetworks(withName: network.ssid))?
                        .max { $0.rssiValue < $1.rssiValue }
                }
                guard let target else {
                    return "\"\(network.ssid)\" is not in range"
                }

                do {
                    try interface.associate(to: target, password: password)
                    return nil
                } catch {
                    return error.localizedDescription
                }
            }

            guard let self else { return }
            self.connectingSSID = nil

            if let error {
                // A secured network we have no keychain entry for: ask for a password.
                if password == nil, network.isSecure, !network.isKnown {
                    self.passwordPromptSSID = network.ssid
                } else {
                    self.lastError = error
                    self.warn("Wi-Fi connect to \(network.ssid) failed: \(error)")
                }
            } else {
                self.passwordPromptSSID = nil
                self.currentSSID = network.ssid
                self.refresh()
                GlobalModels.shared.wifiModel.update()
            }
        }
    }

    private nonisolated static func onBackground<T: Sendable>(_ work: @escaping @Sendable () -> T) async -> T {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: work())
            }
        }
    }

    private nonisolated static func performScan() async -> WiFiSnapshot {
        await onBackground {
            var snapshot = WiFiSnapshot()
            guard let interface = CWWiFiClient.shared().interface() else { return snapshot }

            snapshot.isPowerOn = interface.powerOn()
            guard snapshot.isPowerOn else { return snapshot }

            // interface.ssid() needs Location Services; fall back to networksetup.
            snapshot.currentSSID = interface.ssid() ?? currentSSIDViaNetworksetup()

            let profiles = (interface.configuration()?.networkProfiles.array as? [CWNetworkProfile]) ?? []
            let knownSSIDs = Set(profiles.compactMap(\.ssid))
            let hotspotProfileSSIDs = Set(
                profiles.filter { isPersonalHotspot($0) }.compactMap(\.ssid)
            )

            let scanned = (try? interface.scanForNetworks(withName: nil, includeHidden: false)) ?? []

            // Deduplicate by SSID keeping the strongest signal.
            var bestBySSID: [String: CWNetwork] = [:]
            for network in scanned {
                guard let ssid = network.ssid, !ssid.isEmpty else { continue }
                if let existing = bestBySSID[ssid], existing.rssiValue >= network.rssiValue { continue }
                bestBySSID[ssid] = network
            }

            var entries: [ScannedNetwork] = bestBySSID.map { ssid, network in
                ScannedNetwork(
                    id: ssid,
                    ssid: ssid,
                    rssi: network.rssiValue,
                    isSecure: !network.supportsSecurity(.none),
                    isHotspot: isPersonalHotspot(network) || hotspotProfileSSIDs.contains(ssid),
                    isKnown: knownSSIDs.contains(ssid),
                    network: network
                )
            }
            entries.sort { lhs, rhs in
                lhs.rssi == rhs.rssi ? lhs.ssid < rhs.ssid : (lhs.rssi ?? .min) > (rhs.rssi ?? .min)
            }

            snapshot.currentNetwork = entries.first { $0.ssid == snapshot.currentSSID }

            // Only hotspots that are actually broadcasting right now: the list
            // is about what can be joined this moment.
            snapshot.hotspots = entries.filter { $0.isHotspot && $0.ssid != snapshot.currentSSID }
            snapshot.known = entries.filter { !$0.isHotspot && $0.isKnown && $0.ssid != snapshot.currentSSID }
            snapshot.others = entries.filter { !$0.isHotspot && !$0.isKnown && $0.ssid != snapshot.currentSSID }
            return snapshot
        }
    }

    /// See `isPersonalHotspot(_ network:)`; the same private flag exists on
    /// saved network profiles.
    private nonisolated static func isPersonalHotspot(_ profile: CWNetworkProfile) -> Bool {
        guard profile.responds(to: NSSelectorFromString("isPersonalHotspot")) else { return false }
        return (profile.value(forKey: "isPersonalHotspot") as? Bool) ?? false
    }

    /// The personal-hotspot flag has no public accessor; read it via KVC only
    /// when the runtime confirms the getter exists.
    private nonisolated static func isPersonalHotspot(_ network: CWNetwork) -> Bool {
        guard network.responds(to: NSSelectorFromString("isPersonalHotspot")) else { return false }
        return (network.value(forKey: "isPersonalHotspot") as? Bool) ?? false
    }

    private nonisolated static func currentSSIDViaNetworksetup() -> String? {
        let cmd = """
        en="$(networksetup -listallhardwareports | awk '/Wi-Fi|AirPort/{getline; print $NF}')"; \
        ipconfig getsummary "$en" | grep -Fxq "  Active : FALSE" || \
        networksetup -listpreferredwirelessnetworks "$en" | sed -n '2s/^\\t//p'
        """
        let task = Process()
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        task.arguments = ["-c", cmd]
        task.launchPath = "/bin/zsh"
        guard (try? task.run()) != nil else { return nil }
        task.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let result = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? nil : result
    }
}
