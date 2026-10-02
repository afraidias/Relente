//
//  MacOSVersionTests.swift
//  RelenteTests
//

import Testing

@testable import Relente

struct MacOSVersionTests {

    @Test func `parses one, two or three numbers`() {
        #expect(MacOSVersion("15") == MacOSVersion(major: 15))
        #expect(MacOSVersion("15.6") == MacOSVersion(major: 15, minor: 6))
        #expect(MacOSVersion("10.15.7") == MacOSVersion(major: 10, minor: 15, patch: 7))
    }

    @Test(arguments: ["", "15.", ".6", "15.6.1.2", "15.x", "-1", "15 6", "١٥"])
    func `rejects anything else`(text: String) {
        #expect(MacOSVersion(text) == nil)
    }

    @Test func `compares part by part, not as text`() {
        let versions: [MacOSVersion] = ["10.15.7", "11.0", "15.6", "15.10", "26.0"]
        #expect(versions == versions.shuffled().sorted())
        #expect(MacOSVersion(stringLiteral: "15.10") > MacOSVersion(stringLiteral: "15.9"))
    }

    @Test func `Big Sur is the first supported version`() {
        #expect(MacOSVersion(stringLiteral: "10.15.7") < .bigSur)
        #expect(MacOSVersion(stringLiteral: "11.0") >= .bigSur)
    }

    @Test func `shows the minor always and the patch only when it isn't zero`() {
        #expect(MacOSVersion(major: 26).description == "26.0")
        #expect(MacOSVersion(major: 15, minor: 6).description == "15.6")
        #expect(MacOSVersion(major: 10, minor: 15, patch: 7).description == "10.15.7")
    }
}
