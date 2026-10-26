//
//  LiveAuthorizationChecker.swift
//  RelenteHelper
//
//  Helper rule 5 with Authorization Services: adds the erase right to the authorization database
//  (the helper runs as root, so nobody is asked), and checks that the authorization the app sends
//  grants it, without showing any dialog.
//  Spec: specs/008-system-helper/spec.md
//

import Foundation
import Security
import os

nonisolated struct LiveAuthorizationChecker: AuthorizationChecking {

    private static let logger = Logger(subsystem: "com.afraidias.Relente", category: "helper")

    /// Adds `EraseRight` to the authorization database, or updates it when its rule's version
    /// changed. Called when the helper starts, before any request.
    static func installRight() {
        var current: CFDictionary?
        if AuthorizationRightGet(EraseRight.name, &current) == errAuthorizationSuccess,
            let current = current as? [String: Any],
            current["version"] as? Int == EraseRight.rule["version"] as? Int
        {
            return
        }
        var authorization: AuthorizationRef?
        guard AuthorizationCreate(nil, nil, [], &authorization) == errAuthorizationSuccess, let authorization else {
            logger.error("Couldn't create an authorization to add the erase right")
            return
        }
        defer { AuthorizationFree(authorization, []) }
        let status = AuthorizationRightSet(
            authorization, EraseRight.name, EraseRight.rule as CFDictionary, nil, nil, nil)
        if status == errAuthorizationSuccess {
            logger.info("Erase right added")
        } else {
            logger.error("Couldn't add the erase right: \(status, privacy: .public)")
        }
    }

    func isAuthorized(_ externalForm: Data) async -> Bool {
        guard externalForm.count == kAuthorizationExternalFormLength else { return false }
        var form = AuthorizationExternalForm()
        withUnsafeMutableBytes(of: &form) { _ = externalForm.copyBytes(to: $0) }

        var authorization: AuthorizationRef?
        guard AuthorizationCreateFromExternalForm(&form, &authorization) == errAuthorizationSuccess,
            let authorization
        else { return false }
        defer { AuthorizationFree(authorization, []) }

        // No interaction: the app already asked the user; here it's only checked.
        let status = EraseRight.name.withCString { name in
            var item = AuthorizationItem(name: name, valueLength: 0, value: nil, flags: 0)
            return withUnsafeMutablePointer(to: &item) { item in
                var rights = AuthorizationRights(count: 1, items: item)
                return AuthorizationCopyRights(authorization, &rights, nil, [.extendRights], nil)
            }
        }
        if status != errAuthorizationSuccess {
            Self.logger.error("Authorization refused: \(status, privacy: .public)")
        }
        return status == errAuthorizationSuccess
    }
}
