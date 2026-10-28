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

    /// Runs the validated installer on a drive and streams real progress/output before the outcome.
    func createInstallMedia(installerURL: URL, installerPackageURL: URL?, drive: Drive, authorization: Data)
        async -> AsyncStream<HelperCreateEvent>

    /// Checks selected-volume write access from the helper without formatting or erasing.
    func checkVolumeWriteAccess(_ drive: Drive, authorization: Data) async -> CreateInstallMediaOutcome?

    /// Stops the format in progress.
    func cancel() async
}

nonisolated enum HelperCreateEvent: Sendable {
    case update(CreateInstallMediaUpdate)
    case finished(CreateInstallMediaOutcome?)
}

nonisolated extension HelperClient {
    func createInstallMedia(installerURL: URL, installerPackageURL: URL? = nil, drive: Drive, authorization: Data)
        async -> AsyncStream<HelperCreateEvent>
    {
        AsyncStream {
            $0.yield(.finished(nil))
            $0.finish()
        }
    }

    func checkVolumeWriteAccess(_ drive: Drive, authorization: Data) async -> CreateInstallMediaOutcome? { .created }
}

/// Answers like a helper that formats at once. Nothing is erased.
nonisolated struct SampleHelperClient: HelperClient {
    var outcome: FormatOutcome? = .formatted
    var writeAccessOutcome: CreateInstallMediaOutcome? = .created
    var isCurrent = true

    func connectsToCurrentHelper() async -> Bool { isCurrent }

    func format(_ drive: Drive, authorization: Data) async -> FormatOutcome? { outcome }

    func createInstallMedia(installerURL: URL, installerPackageURL: URL?, drive: Drive, authorization: Data)
        async -> AsyncStream<HelperCreateEvent>
    {
        AsyncStream {
            $0.yield(.finished(.created))
            $0.finish()
        }
    }

    func checkVolumeWriteAccess(_ drive: Drive, authorization: Data) async -> CreateInstallMediaOutcome? {
        writeAccessOutcome
    }

    func cancel() async {}
}
