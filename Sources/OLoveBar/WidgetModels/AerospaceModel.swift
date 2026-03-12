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
    private let cacheQueue = DispatchQueue(label: "AerospaceModel.iconCache")
    private let updateQueue = DispatchQueue(label: "AerospaceModel.update", qos: .userInitiated)
    private var isUpdating: Bool = false
    private var pendingUpdateRequested: Bool = false
    private let ipc = AerospaceIPC.shared
    
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
                    self?.updateFocusedOnly()
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
                DispatchQueue.main.async { [weak self] in
                    self?.updateData()
                }
            }
        }
    }

    private func updateData() {
        updateQueue.async { [weak self] in
            guard let self else { return }

            if self.isUpdating {
                self.pendingUpdateRequested = true
                return
            }

            self.isUpdating = true
            self.pendingUpdateRequested = false

            defer {
                self.isUpdating = false
                if self.pendingUpdateRequested {
                    self.pendingUpdateRequested = false
                    self.updateData()
                }
            }

            do {
                // Run independent AeroSpace queries in parallel to minimise latency.
                let windowsAns = try AerospaceClient.request(
                    args: ["list-windows", "--all", "--format", "%{workspace}|%{app-bundle-id}"]
                )
                let windowsOutput = windowsAns.stdout

                let allAns = try AerospaceClient.request(
                    args: ["list-workspaces", "--all"]
                )
                let allWorkspacesOutput = allAns.stdout

                let focusedAns = try AerospaceClient.request(
                    args: ["list-workspaces", "--focused"]
                )
                let focused = focusedAns.stdout
                    .components(separatedBy: .newlines)
                    .first?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                self.info("Focused workspace: \(focused)")

                let lines = windowsOutput
                    .components(separatedBy: .newlines)
                    .filter { !$0.isEmpty }

                var workspaceMap: [String: Set<String>] = [:]

                for line in lines {
                    let lineParts = line.components(separatedBy: "|")
                    guard lineParts.count == 2 else { continue }
                    let workspaceId = lineParts[0]
                    let bundleId = lineParts[1]
                    workspaceMap[workspaceId, default: []].insert(bundleId)
                }

                let workspaceIds = allWorkspacesOutput
                    .components(separatedBy: .newlines)
                    .filter { !$0.isEmpty }

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
            } catch {
                fputs("[aerospace socket error] \(error)\n", stderr)
            }
        }
    }
    
    private func updateFocusedOnly() {
        Task.detached { [weak self] in
            guard let self else { return }
            do {
                let ans = try await self.ipc.request(args: ["list-workspaces", "--focused"])
                let focused = ans.stdout
                    .components(separatedBy: .newlines)
                    .first?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                
                await MainActor.run {
                    self.focused = focused
                }
            } catch {
                fputs("[aerospace focused error] \(error)\n", stderr)
            }
        }
    }

    private func getAppIcon(bundleId: String) -> NSImage? {
        cacheQueue.sync {
            if let cachedIcon = iconCache[bundleId] {
                return cachedIcon
            }

            guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
                return nil
            }
            let icon = NSWorkspace.shared.icon(forFile: appURL.path)
            iconCache[bundleId] = icon
            return icon
        }
    }

    func focus(_ id: String) {
        // Optimistically update focused to feel instant, then confirm via IPC.
        focused = id
        Task.detached { [weak self] in
            guard let self else { return }
            _ = try? await self.ipc.request(args: ["workspace", id])
            self.updateFocusedOnly()
        }
    }

    deinit {
        if serverSocket >= 0 {
            close(serverSocket)
        }
    }
}

