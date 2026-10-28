import Foundation
import os

nonisolated final class HelperProgressReceiver: NSObject, HelperProgressProtocol, @unchecked Sendable {
    private let continuation = OSAllocatedUnfairLock<AsyncStream<HelperCreateEvent>.Continuation?>(initialState: nil)

    func set(_ continuation: AsyncStream<HelperCreateEvent>.Continuation?) {
        self.continuation.withLock { $0 = continuation }
    }

    func report(
        phase: Int, fraction: Double, output: String, timestamp: Date,
        copiedBytes: Int64, totalBytes: Int64, bytesPerSecond: Int64
    ) {
        let progress = CreateInstallMediaPhase(rawValue: phase).map {
            CreateInstallMediaProgress(phase: $0, fraction: (0...1).contains(fraction) ? fraction : nil)
        }
        let line = output.isEmpty ? nil : output
        let measurement = InstallerCopyMeasurement(copiedBytes: copiedBytes, totalBytes: totalBytes)
        let update = CreateInstallMediaUpdate(
            progress: progress, outputLine: line, timestamp: timestamp,
            copyMeasurement: measurement, copyBytesPerSecond: bytesPerSecond >= 0 ? bytesPerSecond : nil)
        _ = continuation.withLock { $0?.yield(.update(update)) }
    }
}
