//
//  AuthenticationMethod.swift
//  Relente
//
//  How macOS will ask the administrator to authorize an erase: Touch ID on Macs that can use it
//  (built in, or a paired Magic Keyboard with Touch ID), the password otherwise. It picks the
//  symbol on "Erase and Create" and Permissions' text.
//  Spec: specs/008-system-helper/spec.md
//

import Foundation
import LocalAuthentication

nonisolated enum AuthenticationMethod: Hashable, Sendable {
    case touchID
    case password

    /// Touch ID only when it can be used now (a sensor and an enrolled finger).
    init(canUseBiometrics: Bool, biometryType: LABiometryType) {
        self = canUseBiometrics && biometryType == .touchID ? .touchID : .password
    }

    /// This Mac's method, read now: a keyboard with Touch ID may have been connected meanwhile.
    static var current: AuthenticationMethod {
        let context = LAContext()
        let canUse = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return AuthenticationMethod(canUseBiometrics: canUse, biometryType: context.biometryType)
    }

    /// The symbol on "Erase and Create" and on Permissions.
    var symbolName: String {
        switch self {
        case .touchID: "touchid"
        case .password: "lock"
        }
    }
}
