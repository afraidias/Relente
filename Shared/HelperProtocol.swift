//
//  HelperProtocol.swift
//  Relente
//
//  What the app and the system helper share to talk over XPC. Compiled into both targets. The
//  helper's whole API (helper rule 1): typed format/create/progress/cancel operations, no
//  "run this command" function or shell.
//  Spec: specs/008-system-helper/spec.md
//

import Foundation

/// Names that identify the system helper.
nonisolated enum HelperIdentity {
    /// The helper's bundle identifier from its code signature.
    static let bundleIdentifier = "com.afraidias.Relente.Helper"
    /// The launchd Mach service advertised by the new daemon registration.
    static let machServiceName = "com.afraidias.Relente.Helper.LiveCreation"
    /// The launchd plist inside the app, in `Contents/Library/LaunchDaemons/`.
    static let plistName = "com.afraidias.Relente.Helper.LiveCreation.plist"
    /// Changes whenever `HelperProtocol` changes, so the app can tell an outdated helper apart.
    static let protocolVersion = 5

    static func supports(_ version: Int?) -> Bool { version == protocolVersion }
}

/// The only callback the helper can make to report the current create operation.
@objc nonisolated protocol HelperProgressProtocol {
    /// `phase` is a `CreateInstallMediaPhase` raw value or -1; `fraction` is 0…1 or -1.
    /// `output` is the command line, or an empty string when only progress changed. Copy bytes
    /// are nonnegative when measured and -1 otherwise.
    func report(
        phase: Int, fraction: Double, output: String, timestamp: Date,
        copiedBytes: Int64, totalBytes: Int64, bytesPerSecond: Int64)
}

/// The calls the helper answers.
@objc nonisolated protocol HelperProtocol {
    /// Replies with `HelperIdentity.protocolVersion` as the helper knows it.
    func protocolVersion(reply: @escaping @Sendable (Int) -> Void)

    /// Erases the whole disk `bsdName` as Mac OS Extended (Journaled), GPT, named "MyVolume",
    /// once the authorization and every check pass. Replies with a `FormatOutcome` raw value.
    /// - Parameters:
    ///   - mediaUUID, serialNumber, size: the fingerprint of the drive the user confirmed.
    ///   - authorization: the external form of an authorization that grants `EraseRight.name`.
    func format(
        bsdName: String, mediaUUID: String?, serialNumber: String?, size: Int64, authorization: Data,
        reply: @escaping @Sendable (Int) -> Void)

    /// Runs Apple's signed `createinstallmedia`; these paths are inputs, never executable paths.
    /// The helper independently resolves and validates the installer and volume. The Apple tool
    /// performs its own erase and preparation phase.
    func createInstallMedia(
        bsdName: String, mediaUUID: String?, serialNumber: String?, size: Int64,
        installerPath: String, installerPackagePath: String?, volumePath: String, authorization: Data,
        reply: @escaping @Sendable (Int) -> Void)

    /// Confirms that the helper can write a harmless temporary marker to the confirmed volume.
    /// This does not format or erase the drive. Replies with a `CreateInstallMediaOutcome` value.
    func checkVolumeWriteAccess(
        bsdName: String, mediaUUID: String?, serialNumber: String?, size: Int64,
        volumePath: String, authorization: Data, reply: @escaping @Sendable (Int) -> Void)

    /// Stops the active format or creation operation, if there is one.
    func cancel()
}
