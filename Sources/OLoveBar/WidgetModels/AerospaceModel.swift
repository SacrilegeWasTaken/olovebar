import Foundation
import SwiftUI
import MacroAPI
import AppKit

struct WorkspaceInfo: Hashable, Identifiable {
    let id: String
    let apps: [AppInfo]
}

struct AppInfo: Hashable, Identifiable {
    let id: String
    let bundleId: String
    let icon: NSImage?
}

@LogFunctions(.Widgets([.aerospaceModel]))
final class AerospaceModel: ObservableObject, @unchecked Sendable {
    init() {
        startTimer(interval: 0.2)
    }

    @Published var workspaces: [WorkspaceInfo] = []
    @Published var focused: String?

    nonisolated(unsafe) private var timer: Timer?
    nonisolated(unsafe) private var iconCache: [String: NSImage] = [:]
    nonisolated(unsafe) private var lastOutput: String = ""
    nonisolated(unsafe) private var lastFocused: String = ""

    func startTimer(interval: TimeInterval) {
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
        DispatchQueue.global(qos: .userInitiated).async {
            let output = AerospaceModel.runCommand("aerospace list-windows --all --format '%{workspace}|%{app-bundle-id}'")
            let focused = AerospaceModel.runCommand("aerospace list-workspaces --focused")
            
            // Skip update if nothing changed
            if output == self.lastOutput && focused == self.lastFocused {
                return
            }
            self.lastOutput = output
            self.lastFocused = focused
            
            let lines = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
            var workspaceMap: [String: Set<String>] = [:]
            
            for line in lines {
                let parts = line.components(separatedBy: "|")
                guard parts.count == 2 else { continue }
                let workspaceId = parts[0]
                let bundleId = parts[1]
                workspaceMap[workspaceId, default: []].insert(bundleId)
            }
            
            let allWorkspaces = AerospaceModel.runCommand("aerospace list-workspaces --all")
            let workspaceIds = allWorkspaces.components(separatedBy: .newlines).filter { !$0.isEmpty }
            
            var workspaceInfos: [WorkspaceInfo] = []
            for workspaceId in workspaceIds {
                let bundleIds = workspaceMap[workspaceId] ?? []
                let apps = bundleIds.map { bundleId in
                    AppInfo(id: bundleId, bundleId: bundleId, icon: self.getAppIcon(bundleId: bundleId))
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

    func focus(_ id: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            _ = AerospaceModel.runCommand("aerospace workspace \(id)")
        }
    }

    deinit {
        timer?.invalidate()
    }
}

