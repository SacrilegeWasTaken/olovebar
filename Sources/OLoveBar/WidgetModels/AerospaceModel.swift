import Foundation
import SwiftUI
import MacroAPI
import AppKit
import os

struct WorkspaceInfo: Hashable, Identifiable {
    let id: String
    let apps: [AppInfo]
}

struct AppInfo: Hashable, Identifiable {
    let id: String
    let bundleId: String
    let icon: NSImage?
}

/// Resolves and caches app icons off the main thread, pre-scaled to display size
/// so SwiftUI does not resample full-resolution icons on every frame.
private actor AppIconCache {
    private var cache: [String: NSImage?] = [:]

    func icon(for bundleId: String) -> NSImage? {
        if let cached = cache[bundleId] {
            return cached
        }

        var resolved: NSImage?
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            let icon = NSWorkspace.shared.icon(forFile: appURL.path)
            resolved = Self.downscale(icon, to: 32)
        }
        cache[bundleId] = resolved
        return resolved
    }

    private static func downscale(_ image: NSImage, to side: CGFloat) -> NSImage {
        var proposedRect = CGRect(origin: .zero, size: CGSize(width: side, height: side))
        guard let cgImage = image.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil) else {
            return image
        }

        let pixelSide = Int(side * 2)
        guard let context = CGContext(
            data: nil,
            width: pixelSide,
            height: pixelSide,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return image
        }

        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: pixelSide, height: pixelSide))
        guard let scaled = context.makeImage() else {
            return image
        }

        return NSImage(cgImage: scaled, size: NSSize(width: side, height: side))
    }
}

/// Minimal localhost HTTP endpoint that AeroSpace's exec-on-workspace-change pings.
/// An optional `focused=<workspace>` query parameter delivers the new focused
/// workspace with the ping itself, ahead of any IPC round-trip.
private final class WorkspaceChangeListener: @unchecked Sendable {
    var onPing: (@Sendable (_ focused: String?) -> Void)?

    private let port: in_port_t
    private var serverSocket: Int32 = -1

    init(port: in_port_t) {
        self.port = port
    }

    func start() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.run()
        }
    }

    func stop() {
        if serverSocket >= 0 {
            close(serverSocket)
            serverSocket = -1
        }
    }

    private func run() {
        let sock = socket(AF_INET, SOCK_STREAM, 0)
        guard sock >= 0 else {
            fputs("[aerospace listener] failed to create socket: errno=\(errno)\n", stderr)
            return
        }

        var yes: Int32 = 1
        setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")

        let bindResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else {
            fputs("[aerospace listener] cannot bind localhost:\(port) (errno=\(errno)); workspace-change pings disabled\n", stderr)
            close(sock)
            return
        }

        guard listen(sock, 5) == 0 else {
            fputs("[aerospace listener] listen failed: errno=\(errno)\n", stderr)
            close(sock)
            return
        }

        serverSocket = sock

        while true {
            let client = accept(sock, nil, nil)
            if client < 0 {
                if errno == EINTR { continue }
                // Socket closed (stop()) or unrecoverable error: end the thread
                // instead of spinning on a failing accept.
                break
            }

            let focused = Self.readFocusedParameter(client)
            let response = "HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nOK"
            _ = response.withCString { write(client, $0, strlen($0)) }
            close(client)

            onPing?(focused)
        }

        close(sock)
    }

    private static func readFocusedParameter(_ fd: Int32) -> String? {
        var timeout = timeval(tv_sec: 0, tv_usec: 200_000)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

        var buffer = [UInt8](repeating: 0, count: 1024)
        let bytesRead = read(fd, &buffer, buffer.count)
        guard bytesRead > 0,
              let text = String(bytes: buffer[0..<bytesRead], encoding: .utf8),
              let requestLine = text.components(separatedBy: "\r\n").first,
              let paramRange = requestLine.range(of: "focused=") else {
            return nil
        }

        let rawValue = requestLine[paramRange.upperBound...].prefix { $0 != " " && $0 != "&" }
        guard !rawValue.isEmpty else { return nil }
        return String(rawValue).removingPercentEncoding ?? String(rawValue)
    }
}

@MainActor
@LogFunctions(.Widgets([.aerospaceModel]))
final class AerospaceModel: ObservableObject {
    @Published var workspaces: [WorkspaceInfo] = []
    @Published var focused: String?

    private let client = AerospaceClient.shared
    private let iconCache = AppIconCache()
    private let listener = WorkspaceChangeListener(port: 43551) // TODO: make configurable
    private var updateTask: Task<Void, Never>?
    private var pendingUpdateRequested = false

    init() {
        listener.onPing = { [weak self] focused in
            Task { @MainActor in
                guard let self else { return }
                if let focused {
                    self.focused = focused
                }
                self.requestUpdate()
            }
        }
        listener.start()
        setupWorkspaceNotifications()
        requestUpdate()
    }

    deinit {
        listener.stop()
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
                    self?.requestUpdate()
                }
            }
        }
    }

    /// Coalesces concurrent refresh requests: at most one update runs at a time,
    /// and at most one more is queued behind it.
    func requestUpdate() {
        if updateTask != nil {
            pendingUpdateRequested = true
            return
        }

        updateTask = Task { [weak self] in
            await self?.performUpdate()
            guard let self else { return }
            self.updateTask = nil
            if self.pendingUpdateRequested {
                self.pendingUpdateRequested = false
                self.requestUpdate()
            }
        }
    }

    private func performUpdate() async {
        do {
            let windowsAnswer = try await client.request(
                args: ["list-windows", "--all", "--format", "%{workspace}|%{app-bundle-id}"]
            )
            let workspacesAnswer = try await client.request(
                args: ["list-workspaces", "--all", "--format", "%{workspace}|%{workspace-is-focused}"]
            )

            var workspaceMap: [String: Set<String>] = [:]
            for line in windowsAnswer.stdout.components(separatedBy: .newlines) where !line.isEmpty {
                let parts = line.components(separatedBy: "|")
                guard parts.count == 2 else { continue }
                workspaceMap[parts[0], default: []].insert(parts[1])
            }

            var workspaceInfos: [WorkspaceInfo] = []
            var focusedWorkspace: String?
            for line in workspacesAnswer.stdout.components(separatedBy: .newlines) where !line.isEmpty {
                let parts = line.components(separatedBy: "|")
                guard let workspaceId = parts.first else { continue }
                if parts.count == 2, parts[1] == "true" {
                    focusedWorkspace = workspaceId
                }

                let bundleIds = workspaceMap[workspaceId] ?? []
                var apps: [AppInfo] = []
                for bundleId in bundleIds.sorted() {
                    let icon = await iconCache.icon(for: bundleId)
                    apps.append(AppInfo(id: bundleId, bundleId: bundleId, icon: icon))
                }
                workspaceInfos.append(WorkspaceInfo(id: workspaceId, apps: apps))
            }

            self.workspaces = workspaceInfos
            if let focusedWorkspace {
                self.focused = focusedWorkspace
            }
            debug("Focused workspace: \(String(describing: focusedWorkspace))")
        } catch {
            fputs("[aerospace socket error] \(error)\n", stderr)
        }
    }

    func focus(_ id: String) {
        // Optimistically update focused to feel instant, then confirm via IPC.
        focused = id
        Task { [weak self] in
            guard let self else { return }
            _ = try? await self.client.request(args: ["workspace", id])
            self.requestUpdate()
        }
    }
}
