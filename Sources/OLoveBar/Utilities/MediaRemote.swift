import Foundation
import os
import Utilities

/// Thin wrapper for MediaRemote.framework private APIs.
/// On macOS 15.4+, only Apple-entitled processes can READ now-playing info.
/// Reading is handled via a helper Swift script run through `swift-frontend`.
/// Write operations (sendCommand) still work directly.
public enum MediaRemote {
    nonisolated(unsafe) private static let bundle: CFBundle? = {
        let url = NSURL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework")
        return CFBundleCreate(kCFAllocatorDefault, url)
    }()

    private static func sym<T>(_ name: String) -> T? {
        guard let bundle = bundle,
              let ptr = CFBundleGetFunctionPointerForName(bundle, name as CFString) else {
            return nil
        }
        return unsafeBitCast(ptr, to: T.self)
    }

    // MARK: - Send Command (works directly from compiled binaries)

    private typealias MRMediaRemoteSendCommandFn = @convention(c) (Int32, CFDictionary?) -> Bool
    private static let _sendCommand: MRMediaRemoteSendCommandFn? = sym("MRMediaRemoteSendCommand")

    public enum Command: Int32 {
        case play = 0
        case pause = 1
        case togglePlayPause = 2
        case stop = 3
        case nextTrack = 4
        case previousTrack = 5
    }

    @discardableResult
    public static func sendCommand(_ command: Command) -> Bool {
        guard let fn = _sendCommand else { return false }
        return fn(command.rawValue, nil)
    }

    // MARK: - Helper Script for Reading Now-Playing Info

    /// Swift script that runs inside `swift-frontend` (Apple-entitled process).
    /// Outputs JSON lines to stdout when now-playing state changes.
    static let helperScript = #"""
    import Foundation

    let bundle = CFBundleCreate(kCFAllocatorDefault,
        NSURL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework"))!

    func sym<T>(_ name: String) -> T? {
        guard let ptr = CFBundleGetFunctionPointerForName(bundle, name as CFString) else { return nil }
        return unsafeBitCast(ptr, to: T.self)
    }
    func dataPtr(_ name: String) -> String? {
        guard let ptr = CFBundleGetDataPointerForName(bundle, name as CFString) else { return nil }
        let cfStr = ptr.assumingMemoryBound(to: CFString?.self).pointee
        return cfStr as String?
    }

    typealias RegisterFn = @convention(c) (DispatchQueue) -> Void
    typealias SetWantsFn = @convention(c) (Bool) -> Void
    typealias GetInfoFn = @convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void
    typealias GetIsPlayingFn = @convention(c) (DispatchQueue, @escaping (Bool) -> Void) -> Void

    let register: RegisterFn? = sym("MRMediaRemoteRegisterForNowPlayingNotifications")
    let setWants: SetWantsFn? = sym("MRMediaRemoteSetWantsNowPlayingNotifications")
    let getInfo: GetInfoFn? = sym("MRMediaRemoteGetNowPlayingInfo")
    let getIsPlaying: GetIsPlayingFn? = sym("MRMediaRemoteGetNowPlayingApplicationIsPlaying")

    let kTitle = dataPtr("kMRMediaRemoteNowPlayingInfoTitle") ?? "kMRMediaRemoteNowPlayingInfoTitle"
    let kArtist = dataPtr("kMRMediaRemoteNowPlayingInfoArtist") ?? "kMRMediaRemoteNowPlayingInfoArtist"
    let kAlbum = dataPtr("kMRMediaRemoteNowPlayingInfoAlbum") ?? "kMRMediaRemoteNowPlayingInfoAlbum"
    let kDuration = dataPtr("kMRMediaRemoteNowPlayingInfoDuration") ?? "kMRMediaRemoteNowPlayingInfoDuration"
    let kElapsed = dataPtr("kMRMediaRemoteNowPlayingInfoElapsedTime") ?? "kMRMediaRemoteNowPlayingInfoElapsedTime"
    let kArtwork = dataPtr("kMRMediaRemoteNowPlayingInfoArtworkData") ?? "kMRMediaRemoteNowPlayingInfoArtworkData"
    let kPlaybackRate = dataPtr("kMRMediaRemoteNowPlayingInfoPlaybackRate") ?? "kMRMediaRemoteNowPlayingInfoPlaybackRate"

    func notifName(_ key: String) -> NSNotification.Name {
        NSNotification.Name(dataPtr(key) ?? key)
    }

    let infoChanged = notifName("kMRMediaRemoteNowPlayingInfoDidChangeNotification")
    let stateChanged = notifName("kMRMediaRemotePlaybackStateDidChangeNotification")
    let appChanged = notifName("kMRMediaRemoteNowPlayingApplicationDidChangeNotification")

    func outputJSON(_ dict: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let str = String(data: data, encoding: .utf8) else { return }
        print(str)
        fflush(stdout)
    }

    func fetchAndOutput() {
        getInfo?(.main) { info in
            var out: [String: Any] = [:]
            out["title"] = info[kTitle] as? String ?? ""
            out["artist"] = info[kArtist] as? String ?? ""
            out["album"] = info[kAlbum] as? String ?? ""
            out["duration"] = info[kDuration] as? Double ?? 0
            out["elapsedTime"] = info[kElapsed] as? Double ?? 0
            out["playbackRate"] = info[kPlaybackRate] as? Double ?? 0

            if let artData = info[kArtwork] as? Data {
                out["artworkBase64"] = artData.base64EncodedString()
            }

            getIsPlaying?(.main) { playing in
                out["isPlaying"] = playing
                outputJSON(out)
            }
        }
    }

    register?(.main)
    setWants?(true)

    for name in [infoChanged, stateChanged, appChanged] {
        NotificationCenter.default.addObserver(
            forName: name, object: nil, queue: .main
        ) { _ in fetchAndOutput() }
    }

    let parentPID = getppid()
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { fetchAndOutput() }

    Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
        if getppid() != parentPID { exit(0) }
    }

    signal(SIGTERM, SIG_IGN)
    let termSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
    termSource.setEventHandler { exit(0) }
    termSource.resume()

    RunLoop.main.run()
    """#
}
