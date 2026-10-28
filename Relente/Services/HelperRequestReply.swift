import Foundation
import os

/// Completes an XPC request once, even when the helper never calls back.
nonisolated final class HelperRequestReply: Sendable {

    private static let logger = Logger(subsystem: "com.afraidias.Relente", category: "helper")
    private let continuation: OSAllocatedUnfairLock<CheckedContinuation<Int?, Never>?>

    init(_ continuation: CheckedContinuation<Int?, Never>) {
        self.continuation = OSAllocatedUnfairLock(initialState: continuation)
    }

    func finish(_ value: Int?) -> Bool {
        let pending = continuation.withLock { pending in
            defer { pending = nil }
            return pending
        }
        guard let pending else { return false }
        pending.resume(returning: value)
        return true
    }

    func startTimeout(after duration: Duration, operation: String) -> Task<Void, Never> {
        Task {
            do {
                try await Task.sleep(for: duration)
            } catch {
                return
            }
            guard finish(nil) else { return }
            Self.logger.error("Helper XPC \(operation, privacy: .public) timed out")
        }
    }
}
