//
//  AuthenticationMethodTests.swift
//  RelenteTests
//
//  Spec: specs/008-system-helper/spec.md
//

import LocalAuthentication
import Testing

@testable import Relente

struct AuthenticationMethodTests {

    @Test func `Touch ID when it can be used`() {
        let method = AuthenticationMethod(canUseBiometrics: true, biometryType: .touchID)
        #expect(method == .touchID)
        #expect(method.symbolName == "touchid")
    }

    @Test func `the password when there's no sensor or no enrolled finger`() {
        #expect(AuthenticationMethod(canUseBiometrics: false, biometryType: .touchID) == .password)
        #expect(AuthenticationMethod(canUseBiometrics: false, biometryType: .none) == .password)
    }

    @Test func `the password shows a lock`() {
        #expect(AuthenticationMethod.password.symbolName == "lock")
    }
}
