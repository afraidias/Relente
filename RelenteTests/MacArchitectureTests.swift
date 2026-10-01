//
//  MacArchitectureTests.swift
//  RelenteTests
//

import Foundation
import Testing

@testable import Relente

struct MacArchitectureTests {

    /// A resource in English, whatever the language of the Mac running the tests.
    private func english(_ resource: LocalizedStringResource) -> String {
        var resource = resource
        resource.locale = Locale(identifier: "en_US")
        return String(localized: resource)
    }

    // MARK: - Detection

    @Test func `the hardware flag decides the architecture`() {
        #expect(MacArchitecture(arm64Flag: 1) == .appleSilicon)
        #expect(MacArchitecture(arm64Flag: 0) == .intel)
        // Intel Macs older than Apple silicon don't have the key at all.
        #expect(MacArchitecture(arm64Flag: nil) == .intel)
    }

    @Test func `the current Mac is detected`() {
        #expect(MacArchitecture.allCases.contains(MacArchitecture.current))
    }

    // MARK: - Card texts

    @Test func `each kind of Mac has its name and capsule`() {
        #expect(english(MacArchitecture.appleSilicon.name) == "Apple silicon")
        #expect(english(MacArchitecture.intel.name) == "Intel")
        #expect(english(MacArchitecture.appleSilicon.whenToPress) == "HOLD")
        #expect(english(MacArchitecture.intel.whenToPress) == "AT START-UP")
    }

    @Test func `each kind of Mac says which key to hold and what to choose`() {
        #expect(
            english(MacArchitecture.appleSilicon.startUpText(volumeName: "Install macOS Tahoe"))
                == "Hold the power button until you see the start-up options, then choose “Install macOS Tahoe”."
        )
        #expect(
            english(MacArchitecture.intel.startUpText(volumeName: "Install macOS Tahoe"))
                == "Hold Option (⌥) right after turning on the Mac, then choose “Install macOS Tahoe”."
        )
    }
}
