//
//  FormatPipeline.swift
//  Relente
//
//  How the helper handles a format request, in order: the authorization (rule 5), the identifier,
//  the disk read again from DiskArbitration, the drive rules and the fingerprint (rule 3), and
//  only then `diskutil`. One request at a time. The outside pieces are protocols, so all of it is
//  tested with fakes; the helper gives it the live ones.
//  Spec: specs/008-system-helper/spec.md
//

import Foundation

/// A format request as the helper receives it.
nonisolated struct FormatRequest: Sendable {
    let bsdName: String
    /// The drive the user confirmed on Review.
    let fingerprint: DiskFingerprint
    /// The external form of the app's authorization.
    let authorization: Data
}

/// Checks that an authorization grants `EraseRight.name`, without asking the user.
nonisolated protocol AuthorizationChecking: Sendable {
    func isAuthorized(_ externalForm: Data) async -> Bool
}

/// Reads disks as they are now.
nonisolated protocol DiskReading: Sendable {
    /// The disk's description, or `nil` if it isn't connected.
    func describe(_ bsdName: String) async -> DiskDescription?
    /// The physical whole disks the Mac started up from.
    func bootDisks() async -> Set<String>
}

/// Erases a whole disk with `DiskutilCommand`.
nonisolated protocol DiskFormatting: Sendable {
    /// Whether `diskutil` finished successfully.
    func format(_ bsdName: String) async -> Bool
    /// Stops the format in progress.
    func cancel() async
}

actor FormatPipeline {
    private let authorization: any AuthorizationChecking
    private let disks: any DiskReading
    private let formatter: any DiskFormatting
    private var isRunning = false

    init(authorization: any AuthorizationChecking, disks: any DiskReading, formatter: any DiskFormatting) {
        self.authorization = authorization
        self.disks = disks
        self.formatter = formatter
    }

    func format(_ request: FormatRequest) async -> FormatOutcome {
        // Taken before the first suspension, so a second request can't slip in meanwhile.
        guard !isRunning else { return .busy }
        isRunning = true
        defer { isRunning = false }

        guard await authorization.isAuthorized(request.authorization) else { return .notAuthorized }
        guard EraseRequestCheck.isValidIdentifier(request.bsdName) else { return .invalidIdentifier }

        let disk = await disks.describe(request.bsdName)
        let bootDisks = await disks.bootDisks()
        if let refusal = EraseRequestCheck.check(
            disk, requested: request.bsdName, confirmed: request.fingerprint, bootDisks: bootDisks)
        {
            return refusal
        }

        if await formatter.format(request.bsdName) { return .formatted }
        return await disks.describe(request.bsdName) == nil ? .driveDisconnected : .formatFailed
    }

    /// Stops the format in progress; it then ends as `formatFailed` (or `driveDisconnected`).
    func cancel() async {
        guard isRunning else { return }
        await formatter.cancel()
    }
}
