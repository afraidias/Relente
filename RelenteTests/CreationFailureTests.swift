//
//  CreationFailureTests.swift
//  RelenteTests
//

import Foundation
import Testing

@testable import Relente

struct CreationFailureTests {

    /// The text in English, whatever the language of the Mac running the tests.
    private func english(_ resource: LocalizedStringResource) -> String {
        var resource = resource
        resource.locale = Locale(identifier: "en_US")
        return String(localized: resource)
    }

    // MARK: - Reasons

    @Test(arguments: CreationFailure.Reason.allCases)
    func `every reason has a title and a recovery line`(reason: CreationFailure.Reason) {
        #expect(!english(reason.title).isEmpty)
        #expect(!english(reason.recovery).isEmpty)
    }

    @Test func `a disconnected drive says so and what to do`() {
        #expect(english(CreationFailure.Reason.driveDisconnected.title) == "The drive was disconnected.")
        #expect(english(CreationFailure.Reason.driveDisconnected.recovery) == "Plug it in again and try again.")
    }

    // MARK: - Where it stopped

    @Test func `STOPPED AT comes from the progress when it stopped`() {
        let failure = CreationFailure(reason: .driveDisconnected, progress: .sampleMidCopy)
        #expect(failure.stoppedPercent == CreationProgress.sampleMidCopy.percent)
    }

    @Test func `a failure during Format stops at 5 % at most`() {
        let failure = CreationFailure(reason: .unknown, progress: CreationProgress(phase: .format, phaseFraction: 1))
        #expect(failure.stoppedPercent <= 5)
    }

    @Test func `a failure at the very start stops at 0 %`() {
        let failure = CreationFailure(reason: .unknown, progress: CreationProgress(phase: .format, phaseFraction: 0))
        #expect(failure.stoppedPercent == 0)
    }

    // MARK: - State

    @Test func `the state gives the progress to draw, running or failed`() {
        let running = CreationState.running(.sampleMidCopy)
        #expect(running.progress == .sampleMidCopy)
        #expect(running.failure == nil)

        let failed = CreationState.failed(.sampleDriveDisconnected)
        #expect(failed.progress == CreationFailure.sampleDriveDisconnected.progress)
        #expect(failed.failure == .sampleDriveDisconnected)
    }

    @Test func `samples are a disconnected drive and a cancellation`() {
        #expect(CreationFailure.sampleDriveDisconnected.reason == .driveDisconnected)
        #expect(CreationFailure.sampleCancelled.reason == .cancelled)
    }
}
