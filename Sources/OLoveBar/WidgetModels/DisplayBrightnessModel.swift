import Foundation
import CoreGraphics
import SwiftUI
import MacroAPI
#if canImport(Darwin)
import Darwin
#endif

// Function pointers
typealias DisplayServicesGetBrightnessFunc = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
typealias DisplayServicesSetBrightnessFunc = @convention(c) (CGDirectDisplayID, Float) -> Int32

@MainActor
@LogFunctions(.Widgets([.volumeModel])) // Reusing volume model logs category for simplicity
public final class DisplayBrightnessModel: ObservableObject {
    public static let shared = DisplayBrightnessModel()
    
    @Published var level: Float = 0.5
    private var timer: Timer?
    
    private var getBrightnessFunc: DisplayServicesGetBrightnessFunc?
    private var setBrightnessFunc: DisplayServicesSetBrightnessFunc?
    
    public init() {
        // Load CoreDisplay or DisplayServices dynamically to avoid linker errors
        let paths = [
            "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices",
            "/System/Library/PrivateFrameworks/CoreDisplay.framework/CoreDisplay"
        ]
        
        var handle: UnsafeMutableRawPointer?
        for path in paths {
            handle = dlopen(path, RTLD_LAZY)
            if handle != nil {
                break
            }
        }
        
        if let handle = handle {
            if let getPtr = dlsym(handle, "DisplayServicesGetBrightness") {
                getBrightnessFunc = unsafeBitCast(getPtr, to: DisplayServicesGetBrightnessFunc.self)
            }
            if let setPtr = dlsym(handle, "DisplayServicesSetBrightness") {
                setBrightnessFunc = unsafeBitCast(setPtr, to: DisplayServicesSetBrightnessFunc.self)
            }
        }
        
        update()
        // Poll for external changes
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.update() }
        }
    }
    
    func update() {
        guard let getFunc = getBrightnessFunc else { return }
        var brightness: Float = 0.0
        let err = getFunc(CGMainDisplayID(), &brightness)
        if err == 0 {
            self.level = brightness
        }
    }
    
    func setBrightness(_ value: Float) {
        self.level = max(0.0, min(1.0, value))
        guard let setFunc = setBrightnessFunc else { return }
        _ = setFunc(CGMainDisplayID(), self.level)
    }
}
