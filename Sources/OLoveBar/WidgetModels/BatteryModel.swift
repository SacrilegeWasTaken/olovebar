import SwiftUI
import Foundation
import IOKit.ps
import MacroAPI





@MainActor
@LogFunctions(.Widgets([.batteryModel]))
final class BatteryModel: ObservableObject {
    static let shared = BatteryModel()

    @Published var percentage: Int = 0
    @Published var isCharging: Bool = false
    @Published var state: String = ""
    @Published var timeToFullCharge: String = ""
    @Published var isLowPowerMode: Bool = false

    nonisolated(unsafe) private var powerSourceLoop: CFRunLoopSource?
    nonisolated(unsafe) private var powerModeObserver: NSObjectProtocol?

    private init() {
        update()
        setupPowerNotifications()
        setupLowPowerModeObserver()
    }

    deinit {
        if let loop = powerSourceLoop {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), loop, .defaultMode)
        }
        if let powerModeObserver {
            NotificationCenter.default.removeObserver(powerModeObserver)
        }
    }

    private func setupPowerNotifications() {
        powerSourceLoop = IOPSNotificationCreateRunLoopSource({ _ in
            guard let model = BatteryModel.shared as BatteryModel? else { return }
            Task { @MainActor in
                model.update()
            }
        }, nil).takeRetainedValue()
        
        if let powerSourceLoop {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), powerSourceLoop, .defaultMode)
        }
    }
    
    private func setupLowPowerModeObserver() {
        powerModeObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name.NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
            }
        }
    }

    func update() {
        info("Updating battery state")
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let source = sources.first,
              let info = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any]
        else { return }
        
        isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled

        if let capacity = info[kIOPSCurrentCapacityKey] as? Int {
            self.percentage = capacity
        }
        
        if let state = info[kIOPSPowerSourceStateKey] as? String {
            self.isCharging = (state == kIOPSACPowerValue)
            self.state = state
        }
        
        if let timeToFullCharge = info[kIOPSTimeToFullChargeKey] as? String {
            self.timeToFullCharge = timeToFullCharge
        }
    }
}