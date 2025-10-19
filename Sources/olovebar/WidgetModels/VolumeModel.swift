import SwiftUI
import Foundation
import CoreAudio
import MacroAPI

@MainActor
@LogFunctions(.Widgets([.volumeModel]))
public class VolumeModel: ObservableObject {
    @Published var level: Float!
    @Published var isPopoverPresented: Bool = false
    nonisolated(unsafe) private var timer: Timer?

    public init() {
        level = get()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.update()
            }
        }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
    }


    private func update() {
        level = get()
    }


    private func get() -> Float {
        var volume: Float32 = 0.5
        var size = UInt32(MemoryLayout<Float32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: AudioObjectPropertySelector(kAudioDevicePropertyVolumeScalar),
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = AudioDeviceID(0)
        var deviceSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var deviceAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &deviceAddress, 0, nil, &deviceSize, &deviceID)
        AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &volume)
        info("Volume get: \(volume)")
        return volume
    }

    @MainActor
    public func set(_ value: Float) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            var volume = value
            var address = AudioObjectPropertyAddress(
                mSelector: AudioObjectPropertySelector(kAudioDevicePropertyVolumeScalar),
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            var deviceID = AudioDeviceID(0)
            var deviceSize = UInt32(MemoryLayout<AudioDeviceID>.size)
            var deviceAddress = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &deviceAddress, 0, nil, &deviceSize, &deviceID)
            AudioObjectSetPropertyData(deviceID, &address, 0, nil, UInt32(MemoryLayout<Float32>.size), &volume)
            self.debug("Volume set: \(value)")
            self.level = value
        }
    }
}