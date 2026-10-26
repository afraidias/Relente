//
//  AuthenticationMethodTests.swift
//  RelenteTests
//
//  Spec: specs/008-system-helper/spec.md
//

import Testing

@testable import Relente

struct AuthenticationMethodTests {

    @Test func `Touch ID shows its symbol`() {
        #expect(AuthenticationMethod.touchID.symbolName == "touchid")
    }

    @Test func `the password shows a lock`() {
        #expect(AuthenticationMethod.password.symbolName == "lock")
    }
}
