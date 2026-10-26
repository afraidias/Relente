//
//  LiveEraseAuthorizer.swift
//  Relente
//
//  Asks for `EraseRight` with Authorization Services: macOS shows its dialog, with Relente's own
//  prompt, and offers Touch ID where it can. The right is never shared or kept, so every erase
//  asks again. The helper creates the right; the app connects to the helper before asking.
//  Spec: specs/008-system-helper/spec.md
//

import Foundation
import Security
import os

nonisolated struct LiveEraseAuthorizer: EraseAuthorizer {

    private static let logger = Logger(subsystem: "com.afraidias.Relente", category: "helper")

    func authorize() async throws(EraseAuthorizationError) -> EraseAuthorization {
        let prompt = String(
            localized: "Relente wants to erase a drive to make a macOS installer on it.",
            comment: "Shown in macOS's Touch ID or administrator-password authorization dialog before each erase.")
        let result = await Self.requestRight(prompt: prompt)
        switch result {
        case .success(let authorization):
            return authorization
        case .failure(let error):
            throw error
        }
    }

    /// Blocks while macOS's dialog is open, so it runs off the main actor.
    @concurrent
    private static func requestRight(prompt: String) async -> Result<EraseAuthorization, EraseAuthorizationError> {
        var reference: AuthorizationRef?
        guard AuthorizationCreate(nil, nil, [], &reference) == errAuthorizationSuccess, let reference else {
            return .failure(.denied)
        }

        let status = EraseRight.name.withCString { name in
            kAuthorizationEnvironmentPrompt.withCString { promptKey in
                prompt.withCString { promptText in
                    var right = AuthorizationItem(name: name, valueLength: 0, value: nil, flags: 0)
                    var promptItem = AuthorizationItem(
                        name: promptKey, valueLength: strlen(promptText),
                        value: UnsafeMutableRawPointer(mutating: promptText), flags: 0)
                    return withUnsafeMutablePointer(to: &right) { right in
                        withUnsafeMutablePointer(to: &promptItem) { promptItem in
                            var rights = AuthorizationRights(count: 1, items: right)
                            var environment = AuthorizationEnvironment(count: 1, items: promptItem)
                            return AuthorizationCopyRights(
                                reference, &rights, &environment, [.interactionAllowed, .extendRights, .preAuthorize],
                                nil)
                        }
                    }
                }
            }
        }

        guard status == errAuthorizationSuccess else {
            AuthorizationFree(reference, [.destroyRights])
            if status == errAuthorizationCanceled {
                logger.info("Authorization cancelled")
                return .failure(.cancelled)
            }
            logger.error("Authorization denied: \(status, privacy: .public)")
            return .failure(.denied)
        }

        var form = AuthorizationExternalForm()
        guard AuthorizationMakeExternalForm(reference, &form) == errAuthorizationSuccess else {
            AuthorizationFree(reference, [.destroyRights])
            return .failure(.denied)
        }
        let externalForm = withUnsafeBytes(of: &form) { Data($0) }
        logger.info("Authorization granted")
        return .success(EraseAuthorization(reference: reference, externalForm: externalForm))
    }
}
