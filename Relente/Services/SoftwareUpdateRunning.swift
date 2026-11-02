//
//  SoftwareUpdateRunning.swift
//  Relente
//
//  Injectable boundary around launching Apple's softwareupdate command.
//  Spec: specs/011-installer-acquisition/spec.md
//

import Foundation

nonisolated protocol SoftwareUpdateRunning: Sendable {
    func run(executable: URL, arguments: [String]) async throws(SoftwareUpdateRunError)
        -> SoftwareUpdateCommandResult
    func stream(executable: URL, arguments: [String]) async -> AsyncStream<SoftwareUpdateCommandEvent>
    func cancel() async
}

nonisolated struct SoftwareUpdateCommandResult: Hashable, Sendable {
    let exitCode: Int32
    let output: String
}

nonisolated enum SoftwareUpdateRunError: Error, Hashable, Sendable {
    case launchFailed
}

nonisolated enum SoftwareUpdateCommandEvent: Hashable, Sendable {
    case output(String)
    case finished(exitCode: Int32, wasCancelled: Bool)
    case failed
}
