//
//  CreationResultTests.swift
//  RelenteTests
//

import Foundation
import Testing

@testable import Relente

struct CreationResultTests {

    private func result(seconds: Int64) -> CreationResult {
        CreationResult(installer: InstallerSource.samples[0], drive: Drive.samples[0], duration: .seconds(seconds))
    }

    /// The total time in English, whatever the language of the Mac running the tests.
    private func englishDuration(seconds: Int64) -> String {
        var resource = result(seconds: seconds).durationText
        resource.locale = Locale(identifier: "en_US")
        return String(localized: resource)
    }

    // MARK: - Volume name

    @Test func `the volume is named after the installer, as createinstallmedia does`() {
        #expect(result(seconds: 720).volumeName == "Install macOS Tahoe")
    }

    // MARK: - Total time

    @Test func `under a minute reads less than a minute`() {
        #expect(englishDuration(seconds: 0) == "less than a minute")
        #expect(englishDuration(seconds: 59) == "less than a minute")
    }

    @Test func `a minute or more is rounded to the nearest minute`() {
        #expect(englishDuration(seconds: 60) == "1 minute")
        #expect(englishDuration(seconds: 89) == "1 minute")
        #expect(englishDuration(seconds: 90) == "2 minutes")
        #expect(englishDuration(seconds: 720) == "12 minutes")
    }

    @Test func `over an hour shows hours and minutes`() {
        let text = englishDuration(seconds: 80 * 60)
        #expect(text.contains("1 hour"))
        #expect(text.contains("20 minutes"))
    }

    @Test func `the sample is Tahoe on the SanDisk Ultra in 12 minutes`() {
        #expect(CreationResult.sample.volumeName == "Install macOS Tahoe")
        #expect(CreationResult.sample.drive.name == "SanDisk Ultra")
        #expect(CreationResult.sample.duration == .seconds(720))
    }
}
