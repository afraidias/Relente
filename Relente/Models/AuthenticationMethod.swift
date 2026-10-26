//
//  AuthenticationMethod.swift
//  Relente
//
//  The method shown in the UI for the current Authorization Services erase flow.
//  Spec: specs/008-system-helper/spec.md
//

import Foundation
import LocalAuthentication

nonisolated enum AuthenticationMethod: Hashable, Sendable {
    case touchID
    case password

    /// Authorization Services performs authentication; this only chooses the matching UI hint.
    static var current: AuthenticationMethod {
        let context = LAContext()
        let canUseTouchID =
            context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
            && context.biometryType == .touchID
        return canUseTouchID ? .touchID : .password
    }

    /// The symbol on "Erase and Create" and on Permissions.
    var symbolName: String {
        switch self {
        case .touchID: "touchid"
        case .password: "lock"
        }
    }
}
