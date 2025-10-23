import SwiftUI
import Foundation
import IOKit.ps
import MacroAPI

@MainActor
@LogFunctions(.Widgets([.batteryModel]))
public class BatteryModel: ObservableObject {
    @Published var percentage: Int = 100
    @Published var isCharging: Bool = false

    nonisolated(unsafe) private var powerSourceLoop: CFRunLoopSource?

    public init() {
        update()
        setupPowerNotifications()
    }

    deinit {
        if let powerSourceLoop {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), powerSourceLoop, .defaultMode)
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

    func update() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let source = sources.first,
              let info = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any]
        else { return }
        
        if let capacity = info[kIOPSCurrentCapacityKey] as? Int {
            self.percentage = capacity
        }
        
        if let state = info[kIOPSPowerSourceStateKey] as? String {
            self.isCharging = (state == kIOPSACPowerValue)
        }
    }
}