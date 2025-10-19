import SwiftUI
import Foundation
import CoreAudio
import MacroAPI

public struct AudioDevice: Identifiable, Equatable {
    public let id: AudioDeviceID
    public let name: String
}

@MainActor
@LogFunctions(.Widgets([.volumeModel]))
public class VolumeModel: ObservableObject {
    @Published var level: Float!
    @Published var isPopoverPresented: Bool = false
    @Published var outputDevices: [AudioDevice] = []
    @Published var currentDeviceID: AudioDeviceID = 0
    nonisolated(unsafe) private var timer: Timer?

    public init() {
        currentDeviceID = getDefaultOutputDevice()
        level = get()
        outputDevices = getOutputDevices()
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
        outputDevices = getOutputDevices()
        currentDeviceID = getDefaultOutputDevice()
    }

    private func getDefaultOutputDevice() -> AudioDeviceID {
        var deviceID = AudioDeviceID(0)
        var deviceSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var deviceAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &deviceAddress, 0, nil, &deviceSize, &deviceID)
        info("Default output device: \(deviceID)")
        return deviceID
    }

    private func getOutputDevices() -> [AudioDevice] {
        var propertySize: UInt32 = 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propertySize)
        let deviceCount = Int(propertySize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propertySize, &deviceIDs)
        
        let audioDevices: [AudioDevice] = deviceIDs.compactMap { deviceID in
            var streamAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            var streamSize: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(deviceID, &streamAddress, 0, nil, &streamSize) == noErr, streamSize > 0 else {
                return nil
            }
            
            var nameSize: UInt32 = 256
            // var name = [CChar](repeating: 0, count: 256)
            var nameAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceNameCFString,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var cfName: Unmanaged<CFString>?
            nameSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
            AudioObjectGetPropertyData(deviceID, &nameAddress, 0, nil, &nameSize, &cfName)

            return AudioDevice(id: deviceID, name: cfName?.takeRetainedValue() as String? ?? "Unknown")
        }

        info("Output devices: \(audioDevices)")
        return audioDevices
    }

    private func get() -> Float {
        var volume: Float32 = 0.5
        var size = UInt32(MemoryLayout<Float32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: AudioObjectPropertySelector(kAudioDevicePropertyVolumeScalar),
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        let deviceID = getDefaultOutputDevice()
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
            let deviceID = self.getDefaultOutputDevice()
            AudioObjectSetPropertyData(deviceID, &address, 0, nil, UInt32(MemoryLayout<Float32>.size), &volume)
            self.debug("Volume set: \(value)")
            self.level = value
        }
    }

    public func setOutputDevice(_ deviceID: AudioDeviceID) {
        var id = deviceID
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, UInt32(MemoryLayout<AudioDeviceID>.size), &id)
        currentDeviceID = deviceID
        info("Output device set: \(deviceID)")
        level = get()
    }
}
