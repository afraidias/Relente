//
//  CreationProgress.swift
//  Relente
//
//  A snapshot of the bootable installer being made: which phase it's in, how far along,
//  and the figures shown on the Creating screen.
//  Spec: specs/004-creating-screen/spec.md
//

import Foundation

nonisolated struct CreationProgress: Hashable, Sendable {
    let phase: CreationPhase
    /// Progress within the current phase, from 0 to 1, or `nil` when the phase reports no
    /// percentage (it then counts 0 until it ends).
    let phaseFraction: Double?
    /// Time spent in the current phase so far.
    let phaseElapsed: Duration
    /// Bytes copied to the drive so far. Only meaningful during Copy.
    let copiedBytes: Int64
    /// Size of the installer being copied, in bytes.
    let installerSize: Int64
    /// Current copy speed in bytes per second; 0 while it's still unknown.
    let bytesPerSecond: Int64

    init(
        phase: CreationPhase,
        phaseFraction: Double?,
        phaseElapsed: Duration = .zero,
        copiedBytes: Int64 = 0,
        installerSize: Int64 = 0,
        bytesPerSecond: Int64 = 0
    ) {
        self.phase = phase
        self.phaseFraction = phaseFraction
        self.phaseElapsed = phaseElapsed
        self.copiedBytes = copiedBytes
        self.installerSize = installerSize
        self.bytesPerSecond = bytesPerSecond
    }

    // MARK: - Overall progress

    /// Progress of the whole process, from 0 to 1: the finished phases in full plus the
    /// current one by its weight.
    var overallFraction: Double {
        overallPoints / 100
    }

    /// Overall progress as a whole percentage, rounded down so it only reads 100 when
    /// everything is done.
    var percent: Int {
        Int(overallPoints.rounded(.down))
    }

    /// Overall progress in percentage points, from 0 to 100.
    private var overallPoints: Double {
        let finished = CreationPhase.allCases
            .prefix { $0 != phase }
            .reduce(0) { $0 + $1.weight }
        return Double(finished) + Double(phase.weight) * clampedPhaseFraction
    }

    /// Progress within the current phase, clamped to 0…1; 0 when the phase reports none.
    private var clampedPhaseFraction: Double {
        min(max(phaseFraction ?? 0, 0), 1)
    }

    /// Whether Copy is already over.
    private var isPastCopy: Bool {
        phase != .copy && CreationPhase.allCases.prefix { $0 != phase }.contains(.copy)
    }

    // MARK: - Figures

    /// COPIED: nothing before Copy, the real bytes during it, the whole installer after it.
    var displayedCopiedBytes: Int64 {
        switch phase {
        case .copy: copiedBytes
        case _ where isPastCopy: max(copiedBytes, installerSize)
        default: 0
        }
    }

    /// SPEED: only during Copy and once it's known; `nil` shows "—".
    var displayedBytesPerSecond: Int64? {
        phase == .copy && bytesPerSecond > 0 ? bytesPerSecond : nil
    }

    /// REMAINING: an estimate of the time left in the current phase.
    var remaining: RemainingTime {
        if phase == .copy {
            guard bytesPerSecond > 0 else { return .calculating }
            let bytesLeft = max(installerSize - copiedBytes, 0)
            return .estimate(.seconds(Double(bytesLeft) / Double(bytesPerSecond)))
        }
        guard phaseFraction != nil else { return isPastCopy ? .almostDone : .calculating }
        let done = clampedPhaseFraction
        guard done > 0 else { return .calculating }
        return .estimate(phaseElapsed * ((1 - done) / done))
    }
}

// MARK: - Sample data

/// Fake snapshots of the sample Tahoe installer (16.8 GB) being made, one per moment the
/// previews show, before the real process exists.
nonisolated extension CreationProgress {
    private static let sampleInstallerSize = InstallerSource.samples[0].size

    /// Formatting the drive: 60 % after 6 s.
    static let sampleFormat = CreationProgress(
        phase: .format,
        phaseFraction: 0.6,
        phaseElapsed: .seconds(6),
        installerSize: sampleInstallerSize
    )

    /// Copy just started: the speed isn't known yet.
    static let sampleEarlyCopy = CreationProgress(
        phase: .copy,
        phaseFraction: 0.01,
        phaseElapsed: .seconds(2),
        copiedBytes: 150_000_000,
        installerSize: sampleInstallerSize
    )

    /// Halfway through Copy: 7.2 GB at 40 MB/s, about 4 min left.
    static let sampleMidCopy = CreationProgress(
        phase: .copy,
        phaseFraction: 7.2 / 16.8,
        phaseElapsed: .seconds(180),
        copiedBytes: 7_200_000_000,
        installerSize: sampleInstallerSize,
        bytesPerSecond: 40_000_000
    )

    /// Making the drive bootable, which reports no percentage.
    static let sampleMakeBootable = CreationProgress(
        phase: .makeBootable,
        phaseFraction: nil,
        phaseElapsed: .seconds(20),
        installerSize: sampleInstallerSize
    )

    /// Checking the finished drive: halfway after 5 s.
    static let sampleVerify = CreationProgress(
        phase: .verify,
        phaseFraction: 0.5,
        phaseElapsed: .seconds(5),
        installerSize: sampleInstallerSize
    )
}
