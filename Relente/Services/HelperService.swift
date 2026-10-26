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
    /// macOS's technical explanation, when it gives one. Kept for diagnostics, not shown verbatim.
    case registrationFailed(reason: String?)
    case unregistrationFailed(reason: String?)

    /// A recovery hint shown in Permissions or the uninstall alert. Raw system details stay in logs.
    var message: LocalizedStringResource {
        switch self {
        case .registrationFailed:
            LocalizedStringResource(
                "Install a signed copy of Relente in Applications, then try again.",
                comment: "Recovery hint when macOS couldn't register the system helper.")
        case .unregistrationFailed:
            LocalizedStringResource(
                "Try again. If the problem continues, restart your Mac.",
                comment: "Recovery hint when macOS couldn't unregister the system helper.")
        }
    }
}
