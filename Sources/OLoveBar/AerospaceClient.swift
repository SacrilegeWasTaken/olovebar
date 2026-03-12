import Foundation
import Network

private struct AerospaceClientRequest: Codable {
    let args: [String]
    let stdin: String
    let windowId: UInt32?
    let workspace: String?
}

struct AerospaceServerAnswer: Codable {
    let stdout: String
    let stderr: String
    let exitCode: Int32
    let serverVersionAndHash: String?
}

private enum AerospaceClientError: Error {
    case cannotConnect(String)
    case invalidResponse(String)
}

private final class AerospaceBox<T>: @unchecked Sendable {
    var value: T
    init(_ value: T) {
        self.value = value
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

enum AerospaceClient {
    static func request(args: [String]) throws -> AerospaceServerAnswer {
        guard let socketPath = resolveAerospaceSocketPath() else {
            throw AerospaceClientError.cannotConnect("AeroSpace socket not found in /tmp (check that AeroSpace is running)")
        }

        let connection = NWConnection(
            to: .unix(path: socketPath),
            using: .tcp
        )

        let queue = DispatchQueue(label: "AerospaceClient.connection")
        let readySemaphore = DispatchSemaphore(value: 0)
        let lastErrorBox = AerospaceBox<Error?>(nil)

        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                readySemaphore.signal()
            case .failed(let err):
                lastErrorBox.value = err
                readySemaphore.signal()
            case .cancelled:
                readySemaphore.signal()
            default:
                break
            }
        }

        connection.start(queue: queue)

        // Wait for ready / failed
        readySemaphore.wait()
        if let error = lastErrorBox.value {
            throw AerospaceClientError.cannotConnect(error.localizedDescription)
        }

        let request = AerospaceClientRequest(
            args: args,
            stdin: "",
            windowId: nil,
            workspace: nil
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(request)

        let sendErrorBox = AerospaceBox<Error?>(nil)
        let writeSemaphore = DispatchSemaphore(value: 0)
        connection.send(content: data, completion: .contentProcessed { sendResultError in
            sendErrorBox.value = sendResultError
            writeSemaphore.signal()
        })
        writeSemaphore.wait()
        if let error = sendErrorBox.value {
            throw AerospaceClientError.cannotConnect("write failed: \(error.localizedDescription)")
        }

        let receiveErrorBox = AerospaceBox<Error?>(nil)
        let readSemaphore = DispatchSemaphore(value: 0)
        let bufferBox = AerospaceBox<Data>(Data())
        let answerBox = AerospaceBox<AerospaceServerAnswer?>(nil)

        @Sendable
        func receiveLoop() {
            connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { content, _, isComplete, receiveResultError in
                if let receiveResultError {
                    receiveErrorBox.value = receiveResultError
                    readSemaphore.signal()
                    return
                }

                if let content {
                    bufferBox.value.append(content)
                }

                // Try to decode as soon as we have some data
                if let decoded = try? JSONDecoder().decode(AerospaceServerAnswer.self, from: bufferBox.value) {
                    answerBox.value = decoded
                    readSemaphore.signal()
                    return
                }

                if isComplete {
                    // Connection closed but we still couldn't decode valid JSON
                    readSemaphore.signal()
                    return
                }

                // Keep reading
                receiveLoop()
            }
        }

        receiveLoop()
        readSemaphore.wait()
        connection.cancel()

        if let error = receiveErrorBox.value {
            throw AerospaceClientError.invalidResponse(error.localizedDescription)
        }

        guard let answer = answerBox.value else {
            if bufferBox.value.isEmpty {
                throw AerospaceClientError.invalidResponse("empty response from AeroSpace")
            } else {
                throw AerospaceClientError.invalidResponse("cannot decode AeroSpace response: \(String(data: bufferBox.value, encoding: .utf8) ?? "<non-utf8>")")
            }
        }

        // Normal case: exitCode == 0 and stderr is empty -> молчим.
        // Если AeroSpace вернул ошибку - логируем один лаконичный рядок.
        if answer.exitCode != 0 {
            fputs("[aerospace socket] exit=\(answer.exitCode) stderr=\(answer.stderr)\n", stderr)
        }

        return answer
    }
}

