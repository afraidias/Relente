//
//  HelperService.swift
//  Relente
//
//  Installs, follows and uninstalls the system helper. The live service uses `SMAppService`; the
//  sample one changes its status by itself, for previews, tests and `-sampleData`.
//  Spec: specs/008-system-helper/spec.md
//

import Foundation

nonisolated protocol HelperService: Sendable {
    /// Where the helper stands now, as macOS reports it.
    var status: HelperStatus { get }

    /// Registers the helper. macOS then usually needs the user to turn it on in System Settings,
    /// and the status becomes `needsApproval`.
    func register() async throws(HelperError)

    /// Unregisters the helper (helper rule 6).
    func unregister() async throws(HelperError)

    /// Opens System Settings › General › Login Items, where the helper is turned on.
    func openSettings()
}

/// Where the system helper stands.
nonisolated enum HelperStatus: Hashable, Sendable {
    case notInstalled
    /// Registered, but the user hasn't turned it on in System Settings yet.
    case needsApproval
    case ready
    /// Registering failed.
    case failed(HelperError)
}

/// Why installing or uninstalling the helper failed.
nonisolated enum HelperError: Error, Hashable, Sendable {
    /// `reason` is macOS's own explanation, when it gives one.
    case registrationFailed(reason: String?)
    case unregistrationFailed(reason: String?)

    /// Shown as the help tag of "Couldn't install", or in the uninstall alert.
    var message: LocalizedStringResource {
        switch self {
        case .registrationFailed(let reason?), .unregistrationFailed(let reason?):
            LocalizedStringResource(
                "\(reason)", comment: "Helper error: macOS's own explanation, e.g. “Operation not permitted”.")
        case .registrationFailed(nil):
            LocalizedStringResource(
                "macOS didn't install the system helper. Try again.",
                comment: "Help tag of “Couldn't install” when macOS gives no reason.")
        case .unregistrationFailed(nil):
            LocalizedStringResource(
                "macOS didn't uninstall the system helper. Try again.",
                comment: "Uninstall failure alert when macOS gives no reason.")
        }
    }
}
