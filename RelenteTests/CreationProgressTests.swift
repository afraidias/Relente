//
//  CreationProgressTests.swift
//  RelenteTests
//

import Testing

@testable import Relente

struct CreationProgressTests {

    /// Sample Tahoe installer: 16.8 GB.
    let installerSize: Int64 = 16_800_000_000

    // MARK: - Phases

    @Test func `phases are in bar order`() {
        #expect(CreationPhase.allCases == [.format, .copy, .makeBootable, .verify])
    }

    @Test func `weights are 5, 85, 5 and 5 and add up to 100`() {
        #expect(CreationPhase.allCases.map(\.weight) == [5, 85, 5, 5])
        #expect(CreationPhase.allCases.map(\.weight).reduce(0, +) == 100)
    }

    // MARK: - Overall progress

    @Test func `nothing done is 0`() {
        let progress = CreationProgress(phase: .format, phaseFraction: 0)
        #expect(progress.overallFraction == 0)
        #expect(progress.percent == 0)
    }

    @Test func `finished phases count in full and the current one by its weight`() {
        // Format done (5) + half of Copy (85 × 0.5 = 42.5) = 47.5 %
        let progress = CreationProgress(phase: .copy, phaseFraction: 0.5)
        #expect(progress.overallFraction == 0.475)
        #expect(progress.percent == 47)
    }

    @Test func `a phase with no percentage counts 0 until it ends`() {
        let progress = CreationProgress(phase: .makeBootable, phaseFraction: nil)
        #expect(progress.overallFraction == 0.9)
        #expect(progress.percent == 90)
    }

    @Test func `the fraction within a phase is clamped to 0…1`() {
        #expect(CreationProgress(phase: .copy, phaseFraction: 1.5).overallFraction == 0.9)
        #expect(CreationProgress(phase: .copy, phaseFraction: -1).overallFraction == 0.05)
    }

    @Test func `percent rounds down`() {
        // 5 + 85 × 0.999 = 89.915 %
        #expect(CreationProgress(phase: .copy, phaseFraction: 0.999).percent == 89)
        // 95 + 5 × 0.98 = 99.9 %
        #expect(CreationProgress(phase: .verify, phaseFraction: 0.98).percent == 99)
    }

    @Test func `only a finished Verify reads 100`() {
        let progress = CreationProgress(phase: .verify, phaseFraction: 1)
        #expect(progress.overallFraction == 1)
        #expect(progress.percent == 100)
    }

    @Test(arguments: zip(CreationPhase.allCases, CreationPhase.allCases.dropFirst()))
    func `moving to the next phase never goes back`(phase: CreationPhase, next: CreationPhase) {
        let endOfPhase = CreationProgress(phase: phase, phaseFraction: 1)
        let startOfNext = CreationProgress(phase: next, phaseFraction: 0)
        #expect(startOfNext.overallFraction >= endOfPhase.overallFraction)
    }

    // MARK: - COPIED and SPEED

    /// A snapshot of the sample installer being made.
    private func progress(
        _ phase: CreationPhase,
        fraction: Double? = 0,
        elapsed: Duration = .zero,
        copied: Int64 = 0,
        speed: Int64 = 0
    ) -> CreationProgress {
        CreationProgress(
            phase: phase,
            phaseFraction: fraction,
            phaseElapsed: elapsed,
            copiedBytes: copied,
            installerSize: installerSize,
            bytesPerSecond: speed
        )
    }

    @Test func `before Copy nothing is copied and there's no speed`() {
        let format = progress(.format, fraction: 0.5, copied: 123, speed: 99)
        #expect(format.displayedCopiedBytes == 0)
        #expect(format.displayedBytesPerSecond == nil)
    }

    @Test func `during Copy the real bytes and speed are shown`() {
        let copy = progress(.copy, fraction: 0.43, copied: 7_200_000_000, speed: 40_000_000)
        #expect(copy.displayedCopiedBytes == 7_200_000_000)
        #expect(copy.displayedBytesPerSecond == 40_000_000)
    }

    @Test func `during Copy an unknown speed is not shown`() {
        #expect(progress(.copy, fraction: 0.01, copied: 150_000_000).displayedBytesPerSecond == nil)
    }

    @Test func `during Copy more bytes than the installer still shows the real bytes`() {
        let copy = progress(.copy, fraction: 1, copied: 17_000_000_000, speed: 40_000_000)
        #expect(copy.displayedCopiedBytes == 17_000_000_000)
        #expect(copy.overallFraction == 0.9)
    }

    @Test(arguments: [CreationPhase.makeBootable, .verify])
    func `after Copy the whole installer is copied and there's no speed`(phase: CreationPhase) {
        let after = progress(phase, copied: 0, speed: 40_000_000)
        #expect(after.displayedCopiedBytes == installerSize)
        #expect(after.displayedBytesPerSecond == nil)
    }

    // MARK: - REMAINING

    @Test func `during Copy remaining is bytes left divided by speed`() {
        // 9.6 GB left at 40 MB/s = 240 s
        let copy = progress(.copy, fraction: 0.43, copied: 7_200_000_000, speed: 40_000_000)
        #expect(copy.remaining == .estimate(.seconds(240)))
    }

    @Test func `during Copy with no speed remaining is calculating`() {
        #expect(progress(.copy, fraction: 0.01, copied: 150_000_000).remaining == .calculating)
    }

    @Test func `during Copy with more bytes than the installer remaining is zero`() {
        let copy = progress(.copy, fraction: 1, copied: 17_000_000_000, speed: 40_000_000)
        #expect(copy.remaining == .estimate(.zero))
    }

    @Test func `other phases estimate from elapsed time and percentage`() {
        // 30 s at 25 % → 90 s left
        #expect(progress(.format, fraction: 0.25, elapsed: .seconds(30)).remaining == .estimate(.seconds(90)))
        #expect(progress(.verify, fraction: 0.5, elapsed: .seconds(4)).remaining == .estimate(.seconds(4)))
    }

    @Test func `a phase at 0 % is calculating`() {
        #expect(progress(.format, fraction: 0, elapsed: .seconds(3)).remaining == .calculating)
    }

    @Test func `a phase after Copy with no percentage is almost done`() {
        #expect(progress(.makeBootable, fraction: nil, elapsed: .seconds(20)).remaining == .almostDone)
    }

    @Test func `a phase before Copy with no percentage is calculating`() {
        #expect(progress(.format, fraction: nil, elapsed: .seconds(20)).remaining == .calculating)
    }

    // MARK: - Sample data

    @Test func `samples cover every phase in order`() {
        let samples: [CreationProgress] = [
            .sampleFormat, .sampleEarlyCopy, .sampleMidCopy, .sampleMakeBootable, .sampleVerify,
        ]
        #expect(Set(samples.map(\.phase)) == Set(CreationPhase.allCases))
        #expect(samples.map(\.overallFraction) == samples.map(\.overallFraction).sorted())
        #expect(CreationProgress.sampleEarlyCopy.remaining == .calculating)
        #expect(CreationProgress.sampleMakeBootable.remaining == .almostDone)
    }
}
