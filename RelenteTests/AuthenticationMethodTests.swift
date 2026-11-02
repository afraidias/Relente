//
//  AuthenticationMethodTests.swift
//  RelenteTests
//
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
