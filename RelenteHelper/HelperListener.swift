//
//  HelperListener.swift
//  RelenteHelper
//
//  Accepts the app's XPC connections. The listener only lets in the Relente app signed by the
//  team (helper rule 2, set in `main.swift`); each connection gets its own
//  `HelperRequestHandler`, sharing its format and creation pipelines across connections.
//  With no connection for a minute, the helper quits; launchd starts it again on the next one.
//  Spec: specs/008-system-helper/spec.md
//

import Foundation
import os

nonisolated final class HelperListener: NSObject, NSXPCListenerDelegate, Sendable {

    private static let logger = Logger(subsystem: "com.afraidias.Relente", category: "helper")
    private static let idleTime = Duration.seconds(60)

    private let pipeline: FormatPipeline
    private let creationPipeline: CreateInstallMediaPipeline
    /// Open connections, and the countdown to quitting while there are none.
    private let state = OSAllocatedUnfairLock<(connections: Int, quitting: Task<Void, Never>?)>(
        initialState: (0, nil))

    init(pipeline: FormatPipeline, creationPipeline: CreateInstallMediaPipeline) {
        self.pipeline = pipeline
        self.creationPipeline = creationPipeline
        super.init()
        startIdleCountdown()
    }

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        connection.remoteObjectInterface = NSXPCInterface(with: HelperProgressProtocol.self)
        let progress = connection.remoteObjectProxy as? HelperProgressProtocol
        let handler = HelperRequestHandler(pipeline: pipeline, creationPipeline: creationPipeline, progress: progress)
        connection.exportedInterface = NSXPCInterface(with: HelperProtocol.self)
        connection.exportedObject = handler
        connection.invalidationHandler = { [weak self] in
            handler.connectionEnded()
            self?.connectionClosed()
        }
        state.withLock { state in
            state.connections += 1
            state.quitting?.cancel()
            state.quitting = nil
        }
        Self.logger.info("Connection accepted from process \(connection.processIdentifier, privacy: .public)")
        connection.resume()
        return true
    }

    private func connectionClosed() {
        let isIdle = state.withLock { state in
            state.connections -= 1
            return state.connections == 0
        }
        if isIdle { startIdleCountdown() }
    }

    private func startIdleCountdown() {
        let countdown = Task {
            try? await Task.sleep(for: Self.idleTime)
            guard !Task.isCancelled else { return }
            Self.logger.info("Idle, quitting")
            exit(0)
        }
        state.withLock { state in
            state.quitting?.cancel()
            state.quitting = countdown
        }
    }
}
