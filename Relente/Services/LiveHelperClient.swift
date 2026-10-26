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
    private var connection: NSXPCConnection?

    // MARK: - HelperClient

    func connectsToCurrentHelper() async -> Bool {
        for attempt in 1...2 {
            let version = await protocolVersion()
            if version == HelperIdentity.protocolVersion { return true }
            Self.logger.error(
                "Helper answered version \(version.map(String.init) ?? "nothing", privacy: .public) (attempt \(attempt, privacy: .public))"
            )
            dropConnection()
        }
        return false
    }

    func format(_ drive: Drive, authorization: Data) async -> FormatOutcome? {
        let fingerprint = drive.fingerprint
        let raw: Int? = await call { helper, reply in
            helper.format(
                bsdName: drive.bsdName, mediaUUID: fingerprint.mediaUUID, serialNumber: fingerprint.serialNumber,
                size: fingerprint.size, authorization: authorization, reply: reply)
        }
        return raw.flatMap(FormatOutcome.init(rawValue:))
    }

    func cancel() async {
        guard let helper = connection?.remoteObjectProxy as? HelperProtocol else { return }
        helper.cancel()
    }

    // MARK: - Connection

    private func protocolVersion() async -> Int? {
        await call { helper, reply in helper.protocolVersion(reply: reply) }
    }

    private func currentConnection() -> NSXPCConnection {
        if let connection { return connection }
        let connection = NSXPCConnection(machServiceName: HelperIdentity.machServiceName, options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: HelperProtocol.self)
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

    /// Sends one call and waits for its reply, or `nil` if the connection fails first.
    private func call(_ send: (HelperProtocol, @escaping @Sendable (Int) -> Void) -> Void) async -> Int? {
        let connection = currentConnection()
        return await withCheckedContinuation { continuation in
            let once = ResumeOnce(continuation)
            let proxy = connection.remoteObjectProxyWithErrorHandler { error in
                Self.logger.error("Helper connection failed: \(error.localizedDescription, privacy: .public)")
                once.resume(nil)
            }
            guard let helper = proxy as? HelperProtocol else {
                once.resume(nil)
                return
            }
            send(helper) { once.resume($0) }
        }
    }
}

/// Resumes a continuation once, whichever comes first: the reply or the connection's error.
private nonisolated final class ResumeOnce: Sendable {
    private let continuation: OSAllocatedUnfairLock<CheckedContinuation<Int?, Never>?>

    init(_ continuation: CheckedContinuation<Int?, Never>) {
        self.continuation = OSAllocatedUnfairLock(initialState: continuation)
    }

    func resume(_ value: Int?) {
        let pending = continuation.withLock { pending in
            defer { pending = nil }
            return pending
        }
        pending?.resume(returning: value)
    }
}
