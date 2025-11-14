import Foundation
import SwiftUI
import MacroAPI
import AppKit

struct WorkspaceInfo: Hashable, Identifiable {
    let id: String
    let apps: [AppInfo]
    let updateId = UUID() 
    
    static func == (lhs: WorkspaceInfo, rhs: WorkspaceInfo) -> Bool {
        lhs.id == rhs.id && lhs.apps == rhs.apps
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(apps)
        hasher.combine(updateId) 
    }
}

struct AppInfo: Hashable, Identifiable {
    let id: String
    let bundleId: String
    let icon: NSImage?
}

@LogFunctions(.Widgets([.aerospaceModel]))
final class AerospaceModel: ObservableObject, @unchecked Sendable {
    @Published var workspaces: [WorkspaceInfo] = []
    @Published var focused: String?

    nonisolated(unsafe) private var iconCache: [String: NSImage] = [:]
    nonisolated(unsafe) private var serverSocket: Int32 = -1
    
    init() {
        startHTTPServer()
        setupWorkspaceNotifications()
        updateData()
    }
    
    private func setupWorkspaceNotifications() {
        let notifications: [Notification.Name] = [
            NSWorkspace.didActivateApplicationNotification,
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didUnhideApplicationNotification,
            NSWorkspace.didHideApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification
        ]
        
        notifications.forEach { name in
            NSWorkspace.shared.notificationCenter.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.updateData()
                }
            }
        }
    }
    
    private func startHTTPServer() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            self.serverSocket = socket(AF_INET, SOCK_STREAM, 0)
            print("Socket created: \(self.serverSocket)")
            
            var addr = sockaddr_in()
            addr.sin_family = sa_family_t(AF_INET)
            let portNumber: in_port_t = 43551 // TODO: make configurable
            addr.sin_port = portNumber.bigEndian
            addr.sin_addr.s_addr = inet_addr("127.0.0.1")
            
            var yes: Int32 = 1
            setsockopt(self.serverSocket, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))
            
            let bindResult = withUnsafePointer(to: &addr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    bind(self.serverSocket, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
            self.info("Bind result: \(bindResult)")
            
            let listenResult = listen(self.serverSocket, 5)
            self.info("Listen result: \(listenResult)")
            self.info("HTTP server started on localhost:\(portNumber)")
            
            while true {
                let client = accept(self.serverSocket, nil, nil)
                if client < 0 {
                    self.info("Accept failed: \(client)")
                    continue
                }
                
                let response = "HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nOK"
                write(client, response, response.utf8.count)
                close(client)
                
                self.info("Triggering updateData()")
                self.updateData()
            }
        }
    }

    private static func runCommand(_ command: String) -> String {
        // Ensure we resolve the aerospace CLI to an absolute path when possible
        if command.hasPrefix("aerospace ") || command == "aerospace" {
            if let path = resolveAerospacePath() {
                // replace only the first occurrence (the command)
                let remainder = command.dropFirst("aerospace".count)
                return runCommand(String(path) + String(remainder))
            }
        }

        let task = Process()
        let outPipe = Pipe()
        let errPipe = Pipe()
        task.standardOutput = outPipe
        task.standardError = errPipe
        task.arguments = ["-c", command]
        task.launchPath = "/bin/zsh"

        // Ensure PATH includes common locations (Homebrew, /usr/local) so external tools are found when running inside a .app bundle
        var env = ProcessInfo.processInfo.environment
        let extraPaths = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin", "/usr/sbin", "/sbin"]
        let existingPATH = env["PATH"] ?? ""
        let combined = (extraPaths + [existingPATH]).joined(separator: ":")
        env["PATH"] = combined
        task.environment = env

        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return ""
        }

        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        let out = String(decoding: outData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        let err = String(decoding: errData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        if !err.isEmpty {
            // Print stderr to aid debugging when app is launched from Finder
            fputs("[aerospace stderr] \(err)\n", stderr)
        }
        return out
    }

    nonisolated(unsafe) private static var cachedAerospacePath: String?

    private static func resolveAerospacePath() -> String? {
        if let cached = cachedAerospacePath, FileManager.default.fileExists(atPath: cached) {
            return cached
        }

        // Check common locations first
        let candidates = [
            "/opt/homebrew/bin/aerospace",
            "/usr/local/bin/aerospace",
            "/usr/bin/aerospace",
            "/bin/aerospace"
        ]
        for c in candidates {
            if FileManager.default.isExecutableFile(atPath: c) {
                cachedAerospacePath = c
                return c
            }
        }

        // Fallback: check PATH environment
        if let pathEnv = ProcessInfo.processInfo.environment["PATH"] {
            for dir in pathEnv.split(separator: ":") {
                let p = String(dir) + "/aerospace"
                if FileManager.default.isExecutableFile(atPath: p) {
                    cachedAerospacePath = p
                    return p
                }
            }
        }

        return nil
    }

    private func updateData() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let output = AerospaceModel.runCommand("aerospace list-windows --all --format '%{workspace}|%{app-bundle-id}'")
            let focused = AerospaceModel.runCommand("aerospace list-workspaces --focused")
            self.info("Focused workspace: \(focused)")
            
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
                let apps = bundleIds.sorted().map { bundleId in
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
        if serverSocket >= 0 {
            close(serverSocket)
        }
    }
}

