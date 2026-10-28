//
//  LiveHelperClient.swift
//  Relente
//
//  One XPC connection to the helper's privileged Mach service, which launchd starts on demand.
//  The connection requires the helper's code signature (helper rule 2); if it's interrupted or
//  invalidated, the next call opens a new one.
//  Spec: specs/008-system-helper/spec.md
//

import Foundation
import os

actor LiveHelperClient: HelperClient {

    private static let logger = Logger(subsystem: "com.afraidias.Relente", category: "helper")
    private static let protocolTimeout = Duration.seconds(10)
    private static let formatTimeout = Duration.seconds(5 * 60)
    private static let writeAccessTimeout = Duration.seconds(60)
    private static let creationTimeout = Duration.seconds(90 * 60)
    private var connection: NSXPCConnection?
    private let progressReceiver = HelperProgressReceiver()

    // MARK: - HelperClient

    func connectsToCurrentHelper() async -> Bool {
        for attempt in 1...2 {
            let version = await protocolVersion()
            if HelperIdentity.supports(version) { return true }
            Self.logger.error(
                "Helper answered version \(version.map(String.init) ?? "nothing", privacy: .public) (attempt \(attempt, privacy: .public))"
            )
            dropConnection()
        }
        return false
    }

    func format(_ drive: Drive, authorization: Data) async -> FormatOutcome? {
        let fingerprint = drive.fingerprint
        let raw: Int? = await call(timeout: Self.formatTimeout, operation: "format") { helper, reply in
            helper.format(
                bsdName: drive.bsdName, mediaUUID: fingerprint.mediaUUID, serialNumber: fingerprint.serialNumber,
                size: fingerprint.size, authorization: authorization, reply: reply)
        }
        return raw.flatMap(FormatOutcome.init(rawValue:))
    }

    func checkVolumeWriteAccess(_ drive: Drive, authorization: Data) async -> CreateInstallMediaOutcome? {
        let fingerprint = drive.fingerprint
        let raw: Int? = await call(timeout: Self.writeAccessTimeout, operation: "USB write check") { helper, reply in
            helper.checkVolumeWriteAccess(
                bsdName: drive.bsdName, mediaUUID: fingerprint.mediaUUID, serialNumber: fingerprint.serialNumber,
                size: fingerprint.size, volumePath: drive.volumeURL?.path(percentEncoded: false) ?? "",
                authorization: authorization, reply: reply)
        }
        return raw.flatMap(CreateInstallMediaOutcome.init(rawValue:))
    }

    func createInstallMedia(installerURL: URL, installerPackageURL: URL?, drive: Drive, authorization: Data)
        async -> AsyncStream<HelperCreateEvent>
    {
        let stream = AsyncStream.makeStream(of: HelperCreateEvent.self)
        progressReceiver.set(stream.continuation)
        let task = Task { [weak self] in
            guard let self else {
                stream.continuation.finish()
                return
            }
            let fingerprint = drive.fingerprint
            let raw: Int? = await call(timeout: Self.creationTimeout, operation: "installer creation") {
                helper, reply in
                helper.createInstallMedia(
                    bsdName: drive.bsdName, mediaUUID: fingerprint.mediaUUID, serialNumber: fingerprint.serialNumber,
                    size: fingerprint.size, installerPath: installerURL.path(percentEncoded: false),
                    installerPackagePath: installerPackageURL?.path(percentEncoded: false),
                    volumePath: drive.volumeURL?.path(percentEncoded: false) ?? "", authorization: authorization,
                    reply: reply)
            }
            stream.continuation.yield(.finished(raw.flatMap(CreateInstallMediaOutcome.init(rawValue:))))
            stream.continuation.finish()
            progressReceiver.set(nil)
        }
        stream.continuation.onTermination = { [weak self] termination in
            guard case .cancelled = termination else { return }
            task.cancel()
            Task { await self?.cancel() }
        }
        return stream.stream
    }

    func cancel() async {
        guard let helper = connection?.remoteObjectProxy as? HelperProtocol else { return }
        helper.cancel()
    }

    // MARK: - Connection

    private func protocolVersion() async -> Int? {
        await call(timeout: Self.protocolTimeout, operation: "protocol negotiation") { helper, reply in
            helper.protocolVersion(reply: reply)
        }
    }

    private func currentConnection() -> NSXPCConnection {
        if let connection { return connection }
        let connection = NSXPCConnection(machServiceName: HelperIdentity.machServiceName, options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: HelperProtocol.self)
        connection.exportedInterface = NSXPCInterface(with: HelperProgressProtocol.self)
        connection.exportedObject = progressReceiver
        // Only the Relente helper signed by the team (helper rule 2).
        connection.setCodeSigningRequirement(CodeSigningRequirement.helper)
        connection.invalidationHandler = { [weak self] in
            Task { await self?.connectionEnded() }
        }
        connection.resume()
        self.connection = connection
        return connection
    }

    private func connectionEnded() {
        connection = nil
    }

    private func dropConnection() {
        connection?.invalidate()
        connection = nil
    }

    /// Sends one call and waits only as long as that operation reasonably needs.
    private func call(
        timeout: Duration,
        operation: String,
        _ send: (HelperProtocol, @escaping @Sendable (Int) -> Void) -> Void
    ) async -> Int? {
        let connection = currentConnection()
        let response = await withCheckedContinuation { continuation in
            let reply = HelperRequestReply(continuation)
            let timeoutTask = reply.startTimeout(after: timeout, operation: operation)
            let finish: @Sendable (Int?) -> Void = { value in
                if reply.finish(value) {
                    timeoutTask.cancel()
                }
            }
            let proxy = connection.remoteObjectProxyWithErrorHandler { error in
                Self.logger.error("Helper connection failed: \(error.localizedDescription, privacy: .public)")
                finish(nil)
            }
            guard let helper = proxy as? HelperProtocol else {
                finish(nil)
                return
            }
            send(helper) { finish($0) }
        }
        if response == nil { dropConnection() }
        return response
    }
}
