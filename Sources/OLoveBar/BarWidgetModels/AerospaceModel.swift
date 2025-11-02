import Foundation
import SwiftUI
import MacroAPI
import AppKit

public struct WorkspaceInfo: Hashable, Identifiable {
    public let id: String
    public let apps: [AppInfo]
}

public struct AppInfo: Hashable, Identifiable {
    public let id: String
    public let bundleId: String
    public let icon: NSImage?
}

@LogFunctions(.Widgets([.aerospaceModel]))
public final class AerospaceModel: ObservableObject, @unchecked Sendable {
    public init() {
        startTimer(interval: 0.1)
    }

    @Published public var workspaces: [WorkspaceInfo] = []
    @Published public var focused: String?

    nonisolated(unsafe) private var timer: Timer?
    nonisolated(unsafe) private var iconCache: [String: NSImage] = [:]

    public func startTimer(interval: TimeInterval) {
        timer?.invalidate()
        updateData()
        timer = Timer.scheduledTimer(timeInterval: interval, target: self, selector: #selector(timerTick(_:)), userInfo: nil, repeats: true)
        if let timer { RunLoop.main.add(timer, forMode: .common) }
    }

    @objc private func timerTick(_ t: Timer) {
        updateData()
    }

    private static func runCommand(_ command: String) -> String {
        let task = Process()
        let pipe = Pipe()
        task.standardError = Pipe()
        task.standardOutput = pipe
        task.arguments = ["-c", command]
        task.launchPath = "/bin/zsh"
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return ""
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func updateData() {
        debug("Updating Data")
        DispatchQueue.global(qos: .userInitiated).async {
            let all = AerospaceModel.runCommand("aerospace list-workspaces --all")
            let focused = AerospaceModel.runCommand("aerospace list-workspaces --focused")
            let workspaceIds = all.components(separatedBy: .newlines).filter { !$0.isEmpty }
            
            var workspaceInfos: [WorkspaceInfo] = []
            
            for workspaceId in workspaceIds {
                let windowsOutput = AerospaceModel.runCommand("aerospace list-windows --workspace \(workspaceId) --format '%{app-name}|%{app-bundle-id}'")
                let windows = windowsOutput.components(separatedBy: .newlines).filter { !$0.isEmpty }
                
                var apps: [AppInfo] = []
                var seenBundleIds = Set<String>()
                
                for window in windows {
                    let parts = window.components(separatedBy: "|")
                    guard parts.count == 2 else { continue }
                    let _ = parts[0] // appName
                    let bundleId = parts[1]
                    
                    // Skip duplicates
                    if seenBundleIds.contains(bundleId) {
                        continue
                    }
                    seenBundleIds.insert(bundleId)
                    
                    // Get app icon
                    let icon = self.getAppIcon(bundleId: bundleId)
                    
                    apps.append(AppInfo(id: bundleId, bundleId: bundleId, icon: icon))
                }
                
                workspaceInfos.append(WorkspaceInfo(id: workspaceId, apps: apps))
            }
            
            Task { @MainActor [workspaceInfos, focused] in
                self.workspaces = workspaceInfos
                self.focused = focused
            }
        }
    }
    
    private func getAppIcon(bundleId: String) -> NSImage? {
        // Check cache first
        if let cachedIcon = iconCache[bundleId] {
            return cachedIcon
        }
        
        // Get icon and cache it
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            return nil
        }
        let icon = NSWorkspace.shared.icon(forFile: appURL.path)
        iconCache[bundleId] = icon
        return icon
    }

    public func focus(_ id: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            _ = AerospaceModel.runCommand("aerospace workspace \(id)")
        }
    }

    deinit {
        timer?.invalidate()
    }
}

