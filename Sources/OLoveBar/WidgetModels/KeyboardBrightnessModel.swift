import Foundation
import SwiftUI
import MacroAPI
import IOKit

@MainActor
public final class KeyboardBrightnessModel: ObservableObject {
    public static let shared = KeyboardBrightnessModel()
    
    @Published var level: Float = 0.0
    private var service: io_service_t = 0
    private var timer: Timer?
    
    public init() {
        self.service = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("AppleLMUController"))
        update()
        
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.update() }
        }
    }
    
    deinit {
        if service != 0 {
            IOObjectRelease(service)
        }
    }
    
    func update() {
        guard service != 0 else { return }
        
        // Use standard CoreFoundation property bridging for IOKit
        if let valueRef = IORegistryEntryCreateCFProperty(service, "KeyboardBacklightLevel" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? NSNumber {
            // LMU Controller values typically max out much higher than 1.0 (e.g. 0xfff). 
            // We approximate it to 0.0 - 1.0 based on a known max like 0xfff (4095) or 0x100 (256).
            // Actually, newer Macs usually accept and return 0-16 or 0-255. 
            // We'll normalize against 255.
            let raw = valueRef.floatValue
            self.level = min(1.0, max(0.0, raw / 255.0))
        }
    }
    
    func setBrightness(_ value: Float) {
        self.level = max(0.0, min(1.0, value))
        // Re-scale to 0-255
        let rawValue = UInt64(self.level * 255.0)
        
        guard service != 0 else { return }
        let num = NSNumber(value: rawValue)
        IORegistryEntrySetCFProperty(service, "KeyboardBacklightLevel" as CFString, num)
    }
}
