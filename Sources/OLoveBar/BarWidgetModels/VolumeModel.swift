import SwiftUI
import Foundation
import CoreAudio
import MacroAPI

public struct AudioDevice: Identifiable, Equatable {
    public let id: AudioDeviceID
    public let name: String
}

private func audioPropertyListener(_ objectID: AudioObjectID, _ numAddresses: UInt32, _ addresses: UnsafePointer<AudioObjectPropertyAddress>, _ clientData: UnsafeMutableRawPointer?) -> OSStatus {
    guard let clientData else { return 0 }
    let model = Unmanaged<VolumeModel>.fromOpaque(clientData).takeUnretainedValue()
    Task { @MainActor in
        model.update()
    }
    return 0
}

@MainActor
@LogFunctions(.Widgets([.volumeModel]))
public final class VolumeModel: ObservableObject {
    var prevLevel: Float!
    @Published var level: Float!
    @Published var isPopoverPresented: Bool = false
    @Published var isMuted: Bool = false
    @Published var outputDevices: [AudioDevice] = []
    @Published var currentDeviceID: AudioDeviceID = 0
    nonisolated(unsafe) private var storedDeviceID: AudioDeviceID = 0

    public init() {
        currentDeviceID = getDefaultOutputDevice()
        storedDeviceID = currentDeviceID
        level = getVolume()
        outputDevices = getOutputDevices()
        setupListeners()
    }

    nonisolated deinit {
        let deviceID = storedDeviceID
        var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyVolumeScalar, mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)
        AudioObjectRemovePropertyListener(deviceID, &address, audioPropertyListener, Unmanaged.passUnretained(self).toOpaque())
        address.mSelector = kAudioDevicePropertyMute
        AudioObjectRemovePropertyListener(deviceID, &address, audioPropertyListener, Unmanaged.passUnretained(self).toOpaque())
        address.mSelector = kAudioHardwarePropertyDefaultOutputDevice
        address.mScope = kAudioObjectPropertyScopeGlobal
        AudioObjectRemovePropertyListener(AudioObjectID(kAudioObjectSystemObject), &address, audioPropertyListener, Unmanaged.passUnretained(self).toOpaque())
        address.mSelector = kAudioHardwarePropertyDevices
        AudioObjectRemovePropertyListener(AudioObjectID(kAudioObjectSystemObject), &address, audioPropertyListener, Unmanaged.passUnretained(self).toOpaque())
    }

    private func setupListeners() {
        let deviceID = getDefaultOutputDevice()
        addListener(deviceID: deviceID, selector: kAudioDevicePropertyVolumeScalar)
        addListener(deviceID: deviceID, selector: kAudioDevicePropertyMute)
        addListener(deviceID: AudioObjectID(kAudioObjectSystemObject), selector: kAudioHardwarePropertyDefaultOutputDevice)
        addListener(deviceID: AudioObjectID(kAudioObjectSystemObject), selector: kAudioHardwarePropertyDevices)
    }



    private func addListener(deviceID: AudioDeviceID, selector: AudioObjectPropertySelector) {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: selector == kAudioHardwarePropertyDefaultOutputDevice || selector == kAudioHardwarePropertyDevices ? kAudioObjectPropertyScopeGlobal : kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListener(deviceID, &address, audioPropertyListener, Unmanaged.passUnretained(self).toOpaque())
    }

    fileprivate func update() {
        prevLevel = level
        let newLevel = getVolume()
        let newMuted = getMuted()

        isMuted = newMuted

        if newMuted {
            level = 0
        } else {
            level = newLevel
        }

        outputDevices = getOutputDevices()
        currentDeviceID = getDefaultOutputDevice()
        storedDeviceID = currentDeviceID
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

    private func getVolume() -> Float {
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


    private func getMuted() -> Bool {
        var muted: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let deviceID = getDefaultOutputDevice()
        
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &muted)
        
        if status != noErr {
            return false
        }
    
        return muted != 0
    }


    @MainActor
    public func setVolume(_ value: Float) {
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

    public func setMuted(_ muted: Bool) {
        var muteValue: UInt32 = muted ? 1 : 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let deviceID = getDefaultOutputDevice()
        let status = AudioObjectSetPropertyData(deviceID, &address, 0, nil, UInt32(MemoryLayout.size(ofValue: muteValue)), &muteValue)
        
        if status != noErr {
            self.error("Error setting mute: \(status)")
        } else {
            self.debug("Mute set to: \(muted)")
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
        level = getVolume()
    }
}
