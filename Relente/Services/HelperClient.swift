//
//  HelperClient.swift
//  Relente
//
//  Talks to the system helper over XPC. The live client only talks to the Relente helper signed by
//  the team (helper rule 2); the sample one answers by itself, for previews and tests.
//  Spec: specs/008-system-helper/spec.md
//

import Foundation

nonisolated protocol HelperClient: Sendable {
    /// Whether the helper answers with this app's `HelperIdentity.protocolVersion`. If it answers
    /// with another one (an older helper still running), it reconnects once, so launchd starts the
    /// current one. Starting the helper also adds the erase right, before the app asks for it.
    func connectsToCurrentHelper() async -> Bool

    /// Asks the helper to erase the drive. `nil` if the helper didn't answer.
    func format(_ drive: Drive, authorization: Data) async -> FormatOutcome?

    /// Stops the format in progress.
    func cancel() async
}

/// Answers like a helper that formats at once. Nothing is erased.
nonisolated struct SampleHelperClient: HelperClient {
    var outcome: FormatOutcome? = .formatted
    var isCurrent = true

    func connectsToCurrentHelper() async -> Bool { isCurrent }

    func format(_ drive: Drive, authorization: Data) async -> FormatOutcome? { outcome }

    func cancel() async {}
}
