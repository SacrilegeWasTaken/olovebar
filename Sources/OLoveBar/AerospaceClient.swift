import Foundation
import Network
import os

/// AeroSpace socket protocol version this client implements (AeroSpace 0.21+).
private let aerospaceProtocolVersion: UInt32 = 1

private struct AerospaceClientRequest: Encodable {
    let args: [String]
    let stdin: String

    private enum CodingKeys: String, CodingKey {
        case args, stdin, windowId, workspace
    }

    // The server rejects requests where windowId/workspace keys are absent;
    // they must be present as explicit JSON nulls.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(args, forKey: .args)
        try container.encode(stdin, forKey: .stdin)
        try container.encodeNil(forKey: .windowId)
        try container.encodeNil(forKey: .workspace)
    }
}

struct AerospaceServerAnswer: Codable, Sendable {
    let stdout: String
    let stderr: String
    let exitCode: Int32
    let serverVersionAndHash: String
}

enum AerospaceClientError: Error, CustomStringConvertible {
    case cannotConnect(String)
    case invalidResponse(String)

    var description: String {
        switch self {
        case .cannotConnect(let details): "cannot connect to AeroSpace: \(details)"
        case .invalidResponse(let details): "invalid AeroSpace response: \(details)"
        }
    }
}

private func resolveAerospaceSocketPath() -> String? {
    let fm = FileManager.default
    let env = ProcessInfo.processInfo.environment

    if let envPath = env["AEROSPACESOCK"], !envPath.isEmpty, fm.fileExists(atPath: envPath) {
        return envPath
    }

    let user = env["USER"] ?? NSUserName()
    let candidates = [
        "/tmp/bobko.aerospace-\(user).sock",
        "/tmp/bobko.aerospace.sock"
    ]

    for path in candidates where fm.fileExists(atPath: path) {
        return path
    }

    return nil
}

// The AeroSpace protocol uses native byte order for all UInt32 values.
private func uint32Data(_ value: UInt32) -> Data {
    withUnsafeBytes(of: value) { Data($0) }
}

/// Client for the AeroSpace server socket that keeps one persistent connection:
/// the version handshake happens once, subsequent requests are single round-trips.
/// Requests are serialized; a broken connection is re-established transparently.
actor AerospaceClient {
    static let shared = AerospaceClient()

    private let queue = DispatchQueue(label: "AerospaceClient.connection")
    private var connection: NWConnection?
    private var tail: Task<AerospaceServerAnswer, Error>?

    func request(args: [String]) async throws -> AerospaceServerAnswer {
        let previous = tail
        let task = Task { [previous] () throws -> AerospaceServerAnswer in
            _ = try? await previous?.value
            return try await self.perform(args: args)
        }
        tail = task
        return try await task.value
    }

    private func perform(args: [String]) async throws -> AerospaceServerAnswer {
        do {
            let connection = try await ensureConnection()
            return try await roundTrip(args: args, over: connection)
        } catch {
            // The connection may be stale (AeroSpace restarted): reconnect once and retry.
            teardown()
            let connection = try await ensureConnection()
            return try await roundTrip(args: args, over: connection)
        }
    }

    private func teardown() {
        connection?.cancel()
        connection = nil
    }

    private func ensureConnection() async throws -> NWConnection {
        if let connection {
            return connection
        }

        guard let socketPath = resolveAerospaceSocketPath() else {
            throw AerospaceClientError.cannotConnect("socket not found in /tmp (check that AeroSpace is running)")
        }

        let connection = NWConnection(to: .unix(path: socketPath), using: .tcp)
        do {
            try await withDeadline(2.0, on: connection) {
                try await Self.awaitReady(connection, queue: self.queue)
                try await Self.send(connection, uint32Data(aerospaceProtocolVersion))
                let serverVersion = try await Self.readUInt32(connection)
                guard serverVersion == aerospaceProtocolVersion else {
                    throw AerospaceClientError.invalidResponse(
                        "incompatible socket protocol version: server \(serverVersion), client \(aerospaceProtocolVersion)"
                    )
                }
            }
        } catch {
            connection.cancel()
            throw error
        }

        self.connection = connection
        return connection
    }

    private func roundTrip(args: [String], over connection: NWConnection) async throws -> AerospaceServerAnswer {
        let payload = try JSONEncoder().encode(AerospaceClientRequest(args: args, stdin: ""))

        let answerData = try await withDeadline(3.0, on: connection) {
            try await Self.send(connection, uint32Data(UInt32(payload.count)) + payload)
            let answerLength = try await Self.readUInt32(connection)
            return try await Self.receive(connection, exactly: Int(answerLength))
        }

        let answer: AerospaceServerAnswer
        do {
            answer = try JSONDecoder().decode(AerospaceServerAnswer.self, from: answerData)
        } catch {
            throw AerospaceClientError.invalidResponse(
                "cannot decode: \(String(data: answerData, encoding: .utf8) ?? "<non-utf8>")"
            )
        }

        if answer.exitCode != 0 {
            fputs("[aerospace socket] exit=\(answer.exitCode) stderr=\(answer.stderr)\n", stderr)
        }

        return answer
    }

    /// Runs `body`; if it does not finish within `seconds`, cancels the connection,
    /// which makes any pending send/receive fail and `body` throw.
    private func withDeadline<T: Sendable>(
        _ seconds: TimeInterval,
        on connection: NWConnection,
        _ body: () async throws -> T
    ) async throws -> T {
        let watchdog = DispatchWorkItem { connection.cancel() }
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + seconds, execute: watchdog)
        defer { watchdog.cancel() }
        return try await body()
    }

    private static func awaitReady(_ connection: NWConnection, queue: DispatchQueue) async throws {
        let resumed = OSAllocatedUnfairLock(initialState: false)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.stateUpdateHandler = { state in
                let error: Error?
                switch state {
                case .ready:
                    error = nil
                case .failed(let e):
                    error = AerospaceClientError.cannotConnect(e.localizedDescription)
                case .cancelled:
                    error = AerospaceClientError.cannotConnect("connection cancelled")
                default:
                    return
                }

                let isFirst = resumed.withLock { alreadyResumed in
                    if alreadyResumed { return false }
                    alreadyResumed = true
                    return true
                }
                guard isFirst else { return }

                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
            connection.start(queue: queue)
        }
        connection.stateUpdateHandler = nil
    }

    private static func send(_ connection: NWConnection, _ data: Data) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: AerospaceClientError.cannotConnect("write failed: \(error.localizedDescription)"))
                } else {
                    continuation.resume()
                }
            })
        }
    }

    private static func receive(_ connection: NWConnection, exactly count: Int) async throws -> Data {
        var buffer = Data()
        while buffer.count < count {
            let remaining = count - buffer.count
            let chunk: Data = try await withCheckedThrowingContinuation { continuation in
                connection.receive(minimumIncompleteLength: remaining, maximumLength: remaining) { content, _, _, error in
                    if let error {
                        continuation.resume(throwing: AerospaceClientError.invalidResponse(error.localizedDescription))
                    } else if let content, !content.isEmpty {
                        continuation.resume(returning: content)
                    } else {
                        continuation.resume(throwing: AerospaceClientError.invalidResponse("connection closed by AeroSpace"))
                    }
                }
            }
            buffer.append(chunk)
        }
        return buffer
    }

    private static func readUInt32(_ connection: NWConnection) async throws -> UInt32 {
        let data = try await receive(connection, exactly: 4)
        return data.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
    }
}
