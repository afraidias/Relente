//
//  DriveService.swift
//  Relente
//
//  Follows the USB drives and SD cards plugged into the Mac, and ejects them. The live service
//  uses DiskArbitration; the sample one serves fixed data for previews, tests and `-sampleData`.
//  Spec: specs/007-real-detection/spec.md
//

import Foundation

nonisolated protocol DriveService: Sendable {
    /// The drives every time they change: plugged in, unplugged, renamed, written to.
    /// The first value comes as soon as it's known.
    func updates() -> AsyncStream<[Drive]>

    /// Unmounts every volume of the drive and ejects it. `force` unmounts even when something is
    /// using it.
    func eject(_ drive: Drive, force: Bool) async throws(EjectError)
}

/// Why a drive wasn't ejected.
nonisolated enum EjectError: Error, Hashable, Sendable {
    /// It's no longer plugged in.
    case notConnected
    /// macOS refused, usually because something is using it. `reason` is macOS's own explanation
    /// when it gives one.
    case refused(reason: String?)

    /// The alert's message, after its title.
    var message: LocalizedStringResource {
        switch self {
        case .notConnected:
            LocalizedStringResource("The drive is no longer connected.", comment: "Eject alert: the drive is gone.")
        case .refused(let reason?):
            LocalizedStringResource(
                "\(reason) Close any windows or apps using it and try again.",
                comment: "Eject alert. The value is macOS's reason, e.g. “The disk is in use by Finder.”")
        case .refused(nil):
            LocalizedStringResource(
                "A window or an app may be using it. Close them and try again.",
                comment: "Eject alert when macOS gives no reason.")
        }
    }
}
