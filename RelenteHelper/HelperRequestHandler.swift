//
//  HelperRequestHandler.swift
//  RelenteHelper
//
//  The object the app talks to over one XPC connection: answers the three calls of
//  `HelperProtocol` and hands format requests to the shared `FormatPipeline`. If the app goes
//  away while its format runs, the format is stopped.
//  Spec: specs/008-system-helper/spec.md
//

import Foundation
import os

nonisolated final class HelperRequestHandler: NSObject, HelperProtocol, Sendable {

    private static let logger = Logger(subsystem: "com.afraidias.Relente", category: "helper")
    private let pipeline: FormatPipeline
    /// Whether this connection's format is running.
    private let isFormatting = OSAllocatedUnfairLock(initialState: false)

    init(pipeline: FormatPipeline) {
        self.pipeline = pipeline
    }

    func protocolVersion(reply: @escaping @Sendable (Int) -> Void) {
        Self.logger.info("Version requested")
        reply(HelperIdentity.protocolVersion)
    }

    func format(
        bsdName: String, mediaUUID: String?, serialNumber: String?, size: Int64, authorization: Data,
        reply: @escaping @Sendable (Int) -> Void
    ) {
        let request = FormatRequest(
            bsdName: bsdName,
            fingerprint: DiskFingerprint(mediaUUID: mediaUUID, serialNumber: serialNumber, size: size),
            authorization: authorization)
        Self.logger.info("Format requested for \(bsdName, privacy: .public)")
        isFormatting.withLock { $0 = true }
        Task {
            let outcome = await pipeline.format(request)
            isFormatting.withLock { $0 = false }
            Self.logger.info(
                "Format of \(bsdName, privacy: .public) ended: \(String(describing: outcome), privacy: .public)")
            reply(outcome.rawValue)
        }
    }

    func cancel() {
        Self.logger.info("Cancel requested")
        Task { await pipeline.cancel() }
    }

    /// The app closed the connection or quit: stop its format, if one is running.
    func connectionEnded() {
        guard isFormatting.withLock({ $0 }) else { return }
        Self.logger.info("Connection ended during a format")
        Task { await pipeline.cancel() }
    }
}
