import Foundation
import os

/// A single owned transfer. Cancellation resolves only from the terminal URLSession callback.
nonisolated final class InstallerDownload: NSObject, URLSessionDownloadDelegate, Sendable {
    enum Failure: Error, Equatable {
        case invalidRequest, alreadyStarted, unexpectedResponse, sizeMismatch, unsafeRedirect, cleanupFailed
        case networkInterrupted
    }

    private struct State {
        var started = false
        var terminal = false
        var cancellationRequested = false
        var redirects = 0
        var ownedDestination = false
        var rate = InstallerTransferRate()
        var failure: Failure?
        var continuation: CheckedContinuation<URL, any Error>?
        var task: URLSessionDownloadTask?
        var session: URLSession?
    }

    private let state = OSAllocatedUnfairLock(initialState: State())
    private let origin: AppleInstallerOrigin
    private let destination: URL
    private let maximumBytes: Int64
    private let expectedBytes: Int64?
    private let progress: @Sendable (Int64, Int64?, Double?) -> Void

    init(
        origin: AppleInstallerOrigin, destination: URL, maximumBytes: Int64, expectedBytes: Int64? = nil,
        progress: @escaping @Sendable (Int64, Int64?, Double?) -> Void = { _, _, _ in }
    ) {
        self.origin = origin
        self.destination = destination
        self.maximumBytes = maximumBytes
        self.expectedBytes = expectedBytes
        self.progress = progress
    }

    func start(_ url: URL, configuration: URLSessionConfiguration = .ephemeral) async throws -> URL {
        guard origin.allows(url), maximumBytes > 0,
            expectedBytes.map({ $0 > 0 && $0 <= maximumBytes }) ?? true,
            destination.isFileURL, !FileManager.default.fileExists(atPath: destination.path)
        else { throw Failure.invalidRequest }
        guard
            state.withLock({ value in
                guard !value.started else { return false }
                value.started = true
                return true
            })
        else { throw Failure.alreadyStarted }
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                configuration.timeoutIntervalForRequest = min(configuration.timeoutIntervalForRequest, 60)
                configuration.timeoutIntervalForResource = min(
                    configuration.timeoutIntervalForResource, origin == .package ? 14_400 : 300)
                configuration.urlCache = nil
                let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
                let task = session.downloadTask(with: url)
                let cancelled = state.withLock { value in
                    value.continuation = continuation
                    value.session = session
                    value.task = task
                    return value.cancellationRequested
                }
                if cancelled { task.cancel() }
                task.resume()
            }
        } onCancel: {
            self.cancel()
        }
    }

    var hasTerminated: Bool { state.withLock { $0.terminal } }

    func cancel() {
        let task = state.withLock { value -> URLSessionDownloadTask? in
            guard !value.terminal else { return nil }
            value.cancellationRequested = true
            return value.task
        }
        task?.cancel()
    }

    func urlSession(
        _ session: URLSession, downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64
    ) {
        if totalBytesWritten > maximumBytes || totalBytesExpectedToWrite > maximumBytes {
            state.withLock { $0.failure = .sizeMismatch }
            downloadTask.cancel()
            return
        }
        guard let response = downloadTask.response as? HTTPURLResponse, response.statusCode == 200,
            let url = response.url, origin.allows(url)
        else {
            state.withLock { $0.failure = .unexpectedResponse }
            downloadTask.cancel()
            return
        }
        let sample = state.withLock { value -> (Bool, Double?) in
            guard !value.cancellationRequested, !value.terminal, value.failure == nil else { return (false, nil) }
            return (true, value.rate.record(bytes: totalBytesWritten, at: ProcessInfo.processInfo.systemUptime))
        }
        guard sample.0 else { return }
        progress(totalBytesWritten, totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : nil, sample.1)
    }

    func urlSession(
        _ session: URLSession, task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        let permitted = state.withLock { value in
            value.redirects += 1
            guard !value.cancellationRequested, value.redirects <= 3,
                let url = request.url, origin.allows(url)
            else {
                value.failure = .unsafeRedirect
                return false
            }
            return true
        }
        completionHandler(permitted ? request : nil)
        if !permitted { task.cancel() }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard !state.withLock({ $0.cancellationRequested || $0.failure != nil }) else { return }
        guard let response = downloadTask.response as? HTTPURLResponse, response.statusCode == 200,
            let url = response.url, origin.allows(url)
        else {
            state.withLock { $0.failure = .unexpectedResponse }
            return
        }
        do {
            let size = try location.resourceValues(forKeys: [.fileSizeKey]).fileSize.map(Int64.init)
            guard let size, size > 0, size <= maximumBytes, expectedBytes.map({ $0 == size }) ?? true else {
                state.withLock { $0.failure = .sizeMismatch }
                return
            }
            // This location expires when the callback returns. Never overwrite a retained item.
            try FileManager.default.moveItem(at: location, to: destination)
            state.withLock { $0.ownedDestination = true }
        } catch {
            state.withLock { $0.failure = .unexpectedResponse }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        let finished = state.withLock { value -> State? in
            guard !value.terminal else { return nil }
            value.terminal = true
            let result = value
            value.continuation = nil
            value.task = nil
            value.session = nil
            return result
        }
        guard let finished, let continuation = finished.continuation else { return }
        var failure: (any Error)? = finished.failure ?? error.map { _ in Failure.networkInterrupted }
        if finished.cancellationRequested { failure = CancellationError() }
        if !finished.ownedDestination && failure == nil { failure = Failure.unexpectedResponse }
        if failure != nil && finished.ownedDestination {
            do { try FileManager.default.removeItem(at: destination) } catch { failure = Failure.cleanupFailed }
        }
        session.finishTasksAndInvalidate()
        if let failure { continuation.resume(throwing: failure) } else { continuation.resume(returning: destination) }
    }
}

/// Rates use monotonic elapsed time and are withheld until there is a measurable interval.
nonisolated struct InstallerTransferRate: Sendable {
    private var previousBytes: Int64 = 0
    private var previousTime: TimeInterval?
    private var lastRate: Double?

    mutating func record(bytes: Int64, at time: TimeInterval) -> Double? {
        guard bytes >= 0, time.isFinite else { return nil }
        guard let previousTime else {
            self.previousTime = time
            previousBytes = bytes
            return nil
        }
        guard time > previousTime, bytes >= previousBytes else { return nil }
        guard time - previousTime >= 0.5 else { return lastRate }
        let result = Double(bytes - previousBytes) / (time - previousTime)
        self.previousTime = time
        previousBytes = bytes
        lastRate = result
        return result
    }
}
