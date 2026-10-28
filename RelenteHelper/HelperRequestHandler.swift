//
//  HelperRequestHandler.swift
//  RelenteHelper
//
//  The object the app talks to over one XPC connection. It handles typed erase/create requests,
//  and stops the active operation if the app goes away.
//  Spec: specs/008-system-helper/spec.md
//

import Foundation
import os
#if RELENTE_TESTS
    @testable import Relente
#endif

nonisolated final class HelperRequestHandler: NSObject, HelperProtocol, Sendable {

    private static let logger = Logger(subsystem: "com.afraidias.Relente", category: "helper")
    private static let operationGate = HelperOperationGate()
    private let connectionID = UUID()
    private let pipeline: FormatPipeline
    private let creationPipeline: CreateInstallMediaPipeline
    private let progress: OSAllocatedUnfairLock<ProgressProxy?>

    init(
        pipeline: FormatPipeline, creationPipeline: CreateInstallMediaPipeline,
        progress: HelperProgressProtocol?
    ) {
        self.pipeline = pipeline
        self.creationPipeline = creationPipeline
        self.progress = OSAllocatedUnfairLock(initialState: progress.map(ProgressProxy.init))
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
        guard Self.operationGate.begin(owner: connectionID) else {
            reply(FormatOutcome.busy.rawValue)
            return
        }
        Task {
            let outcome = await pipeline.format(request)
            Self.operationGate.end(owner: connectionID)
            Self.logger.info(
                "Format of \(bsdName, privacy: .public) ended: \(String(describing: outcome), privacy: .public)")
            reply(outcome.rawValue)
        }
    }

    func createInstallMedia(
        bsdName: String, mediaUUID: String?, serialNumber: String?, size: Int64,
        installerPath: String, installerPackagePath: String?, volumePath: String, authorization: Data,
        reply: @escaping @Sendable (Int) -> Void
    ) {
        let request = CreateInstallMediaRequest(
            bsdName: bsdName,
            fingerprint: DiskFingerprint(mediaUUID: mediaUUID, serialNumber: serialNumber, size: size),
            installerURL: URL(filePath: installerPath),
            installerPackageURL: installerPackagePath.map { URL(filePath: $0) },
            volumeURL: URL(filePath: volumePath),
            authorization: authorization)
        Self.logger.info("createinstallmedia requested for \(bsdName, privacy: .public)")
        guard Self.operationGate.begin(owner: connectionID) else {
            reply(CreateInstallMediaOutcome.busy.rawValue)
            return
        }
        Task {
            defer { Self.operationGate.end(owner: connectionID) }
            let outcome = await creationPipeline.create(request) { update in
                self.progress.withLock { wrapper in
                    wrapper?.proxy.report(
                        phase: update.progress?.phase.rawValue ?? -1,
                        fraction: update.progress?.fraction ?? -1,
                        output: update.outputLine ?? "", timestamp: update.timestamp,
                        copiedBytes: update.copyMeasurement?.copiedBytes ?? -1,
                        totalBytes: update.copyMeasurement?.totalBytes ?? -1,
                        bytesPerSecond: update.copyBytesPerSecond ?? -1)
                }
            }
            Self.logger.info("createinstallmedia ended: \(outcome.rawValue, privacy: .public)")
            reply(outcome.rawValue)
        }
    }

    func checkVolumeWriteAccess(
        bsdName: String, mediaUUID: String?, serialNumber: String?, size: Int64,
        volumePath: String, authorization: Data, reply: @escaping @Sendable (Int) -> Void
    ) {
        guard Self.operationGate.begin(owner: connectionID) else {
            reply(CreateInstallMediaOutcome.busy.rawValue)
            return
        }
        let request = CreateInstallMediaRequest(
            bsdName: bsdName,
            fingerprint: DiskFingerprint(mediaUUID: mediaUUID, serialNumber: serialNumber, size: size),
            installerURL: URL(filePath: "/"), installerPackageURL: nil,
            volumeURL: URL(filePath: volumePath), authorization: authorization)
        Task {
            defer { Self.operationGate.end(owner: connectionID) }
            let outcome = await creationPipeline.checkWriteAccess(request)
            Self.logger.info("Volume access preflight ended: \(outcome.rawValue, privacy: .public)")
            reply(outcome.rawValue)
        }
    }

    func cancel() {
        guard Self.operationGate.owns(connectionID) else { return }
        Self.logger.info("Cancel requested")
        Task {
            async let formatting: Void = pipeline.cancel()
            async let creating: Void = creationPipeline.cancel()
            _ = await (formatting, creating)
        }
    }

    /// The app closed the connection or quit: stop its format, if one is running.
    func connectionEnded() {
        guard Self.operationGate.owns(connectionID) else { return }
        Self.logger.info("Connection ended during an operation")
        cancel()
    }
}

private nonisolated final class ProgressProxy: @unchecked Sendable {
    let proxy: HelperProgressProtocol

    init(_ proxy: HelperProgressProtocol) {
        self.proxy = proxy
    }
}
