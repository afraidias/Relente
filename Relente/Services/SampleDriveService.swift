//
//  SampleDriveService.swift
//  Relente
//
//  Drives for previews, tests and `-sampleData YES`: never touches a disk. Tests plug and unplug
//  drives with `send(_:)` and choose what ejecting does.
//  Spec: specs/007-real-detection/spec.md
//

import Foundation

nonisolated final class SampleDriveService: DriveService {
    /// What `eject` does: succeed, or throw this error.
    private let ejectError: EjectError?
    private let stream: AsyncStream<[Drive]>
    private let continuation: AsyncStream<[Drive]>.Continuation

    init(drives: [Drive] = Drive.samples, ejectError: EjectError? = nil) {
        self.ejectError = ejectError
        (stream, continuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(1))
        continuation.yield(drives)
    }

    /// One stream for the app's one assistant.
    func updates() -> AsyncStream<[Drive]> {
        stream
    }

    func eject(_ drive: Drive, force: Bool) async throws(EjectError) {
        if let ejectError, !force { throw ejectError }
    }

    /// Replaces the list, as if drives were plugged in or out.
    func send(_ drives: [Drive]) {
        continuation.yield(drives)
    }
}
