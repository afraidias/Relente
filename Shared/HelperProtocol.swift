//
//  HelperProtocol.swift
//  Relente
//
//  What the app and the system helper share to talk over XPC. Compiled into both targets. The
//  helper's whole API (helper rule 1): three calls with simple types, no "run this command".
//  Roadmap step 7 adds running `createinstallmedia`; nothing else.
//  Spec: specs/008-system-helper/spec.md
//

import Foundation

/// Names that identify the system helper.
nonisolated enum HelperIdentity {
    /// The helper's bundle identifier, launchd label and XPC Mach service name.
    static let machServiceName = "com.afraidias.Relente.Helper"
    /// The launchd plist inside the app, in `Contents/Library/LaunchDaemons/`.
    static let plistName = "com.afraidias.Relente.Helper.plist"
    /// Changes whenever `HelperProtocol` changes, so the app can tell an outdated helper apart.
    static let protocolVersion = 1
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

    /// Stops the format in progress, if there is one.
    func cancel()
}
