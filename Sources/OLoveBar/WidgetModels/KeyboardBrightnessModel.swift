import Foundation
import SwiftUI
import MacroAPI
import KeyboardWrapper

@MainActor
public final class KeyboardBrightnessModel: ObservableObject {
    public static let shared = KeyboardBrightnessModel()
    
    @Published var level: Float = 0.0
    private var timer: Timer?
    
    public init() {
        self.level = KeyboardWrapper.getBrightness()
        update()
        
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.update() }
        }
    }
    
    func update() {
        self.level = min(1.0, max(0.0, KeyboardWrapper.getBrightness()))
    }
    
    func setBrightness(_ value: Float) {
        self.level = max(0.0, min(1.0, value))
        KeyboardWrapper.setBrightness(self.level)
    }
}
