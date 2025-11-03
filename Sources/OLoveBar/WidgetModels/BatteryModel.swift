import SwiftUI
import Foundation
import IOKit.ps
import MacroAPI





@MainActor
@LogFunctions(.Widgets([.batteryModel]))
final class BatteryModel: ObservableObject {
    @Published var percentage: Int!
    @Published var isCharging: Bool!
    @Published var state: String!
    @Published var timeToFullCharge: String!
    @Published var isLowPowerMode: Bool!

    nonisolated(unsafe) private var powerSourceLoop: CFRunLoopSource!
    nonisolated(unsafe) private var powerModeObserver: NSObjectProtocol!

    init() {
        update()
        setupPowerNotifications()
        setupLowPowerModeObserver()
    }

    deinit {
        if let powerSourceLoop {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), powerSourceLoop, .defaultMode)
        }
        if let powerModeObserver {
            NotificationCenter.default.removeObserver(powerModeObserver)
        }
    }

    private func setupPowerNotifications() {
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        powerSourceLoop = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let model = Unmanaged<BatteryModel>.fromOpaque(context).takeUnretainedValue()
            Task { @MainActor in
                model.update()
            }
        }, context).takeRetainedValue()
        
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