import SwiftUI
import Utilities

@MainActor
public final class PlayerModel: ObservableObject {
    public static let shared = PlayerModel()

    @Published public var title: String = "Not Playing"
    @Published public var artist: String = ""
    @Published public var album: String = ""
    @Published public var artwork: NSImage? = nil
    @Published public var isPlaying: Bool = false
    @Published public var duration: Double = 0
    @Published public var elapsedTime: Double = 0

    private var helperProcess: Process?
    private var progressTimer: Timer?
    private var scriptURL: URL?
    nonisolated(unsafe) private var lineBuffer = ""

    private init() {
        startHelper()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateProgress()
            }
        }
    }

    deinit {
        helperProcess?.terminate()
        if let url = scriptURL { try? FileManager.default.removeItem(at: url) }
    }

    // MARK: - Helper Process

    private func startHelper() {
        let tempDir = FileManager.default.temporaryDirectory
        let scriptPath = tempDir.appendingPathComponent("olovebar_mr_helper.swift")
        do {
            try MediaRemote.helperScript.write(to: scriptPath, atomically: true, encoding: .utf8)
        } catch {
            print("[error]:[PlayerModel] Failed to write helper script: \(error)")
            return
        }
        self.scriptURL = scriptPath

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
        process.arguments = [scriptPath.path]
        process.standardError = FileHandle.nullDevice

        let pipe = Pipe()
        process.standardOutput = pipe

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                handle.readabilityHandler = nil
                return
            }
            guard let self = self, let chunk = String(data: data, encoding: .utf8) else { return }
            self.lineBuffer.append(chunk)

            while let newlineRange = self.lineBuffer.range(of: "\n") {
                let line = String(self.lineBuffer[self.lineBuffer.startIndex..<newlineRange.lowerBound])
                self.lineBuffer = String(self.lineBuffer[newlineRange.upperBound...])
                if !line.isEmpty {
                    Task { @MainActor [weak self] in
                        self?.parseLine(line)
                    }
                }
            }
        }

        process.terminationHandler = { [weak self] proc in
            print("[warn]:[PlayerModel] Helper exited with code \(proc.terminationStatus), restarting...")
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    Task { @MainActor in
                        self.startHelper()
                    }
                }
            }
        }

        do {
            try process.run()
            self.helperProcess = process
            print("[info]:[PlayerModel] Helper process started (PID: \(process.processIdentifier))")
        } catch {
            print("[error]:[PlayerModel] Failed to start helper: \(error)")
        }
    }

    private func parseLine(_ line: String) {
        guard let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }
        applyUpdate(json)
    }

    private func applyUpdate(_ info: [String: Any]) {
        let newTitle = info["title"] as? String ?? ""
        self.title = newTitle.isEmpty ? "Not Playing" : newTitle
        self.artist = info["artist"] as? String ?? ""
        self.album = info["album"] as? String ?? ""
        self.duration = info["duration"] as? Double ?? 0
        self.elapsedTime = info["elapsedTime"] as? Double ?? 0
        self.isPlaying = info["isPlaying"] as? Bool ?? false

        if let b64 = info["artworkBase64"] as? String,
           let artData = Data(base64Encoded: b64) {
            self.artwork = NSImage(data: artData)
        } else {
            self.artwork = nil
        }
    }

    private func updateProgress() {
        guard isPlaying && duration > 0 else { return }
        if elapsedTime < duration {
            elapsedTime += 1
        }
    }

    // MARK: - Controls (direct — works from compiled binaries)

    public func playPause() {
        MediaRemote.sendCommand(.togglePlayPause)
    }

    public func next() {
        MediaRemote.sendCommand(.nextTrack)
    }

    public func previous() {
        MediaRemote.sendCommand(.previousTrack)
    }
}
