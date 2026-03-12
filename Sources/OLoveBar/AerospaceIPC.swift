import Foundation

actor AerospaceIPC {
    static let shared = AerospaceIPC()

    /// Async wrapper around the existing synchronous AerospaceClient.request.
    /// All heavy IPC work is performed on a background queue.
    func request(args: [String]) async throws -> AerospaceServerAnswer {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let answer = try AerospaceClient.request(args: args)
                    continuation.resume(returning: answer)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

