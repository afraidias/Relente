//
//  EraseAuthorizer.swift
//  Relente
//
//  Asks an administrator to authorize an erase (helper rule 5): macOS's own dialog, with Touch ID
//  on Macs that have it. The result goes to the helper, which checks it again. The live authorizer
//  uses Authorization Services; the sample one authorizes at once, for previews and tests.
//  Spec: specs/008-system-helper/spec.md
//

import Foundation
import Security

nonisolated protocol EraseAuthorizer: Sendable {
    /// Shows macOS's dialog and waits for the user. Throws `.cancelled` if they cancel it.
    func authorize() async throws(EraseAuthorizationError) -> EraseAuthorization
}

/// Why there's no authorization.
nonisolated enum EraseAuthorizationError: Error, Hashable, Sendable {
    /// The user cancelled the dialog.
    case cancelled
    /// macOS refused, e.g. after too many wrong passwords.
    case denied
}

/// An authorization that grants `EraseRight.name`, kept alive until the erase ends: the helper
/// reads it through its external form, which only works while the app still holds it.
nonisolated final class EraseAuthorization: @unchecked Sendable {
    // `@unchecked`: both properties are set once in `init` and never change; the reference is only
    // freed in `deinit`.
    private let reference: AuthorizationRef?
    /// What the app sends to the helper over XPC.
    let externalForm: Data

    init(reference: AuthorizationRef?, externalForm: Data) {
        self.reference = reference
        self.externalForm = externalForm
    }

    /// A pretend authorization for previews and tests, which the helper would refuse.
    static let sample = EraseAuthorization(reference: nil, externalForm: Data())

    deinit {
        if let reference {
            // Destroying the rights too, so nothing can reuse them after this erase.
            AuthorizationFree(reference, [.destroyRights])
        }
    }
}

/// Authorizes at once. Nothing is shown.
nonisolated struct SampleEraseAuthorizer: EraseAuthorizer {
    var error: EraseAuthorizationError?

    func authorize() async throws(EraseAuthorizationError) -> EraseAuthorization {
        if let error { throw error }
        return .sample
    }
}
