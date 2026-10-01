//
//  ReviewSummaryTests.swift
//  RelenteTests
//

import Foundation
import Testing

@testable import Relente

struct ReviewSummaryTests {

    /// Sample Tahoe installer: 16.8 GB.
    let installer = InstallerSource(
        url: URL(filePath: "/Applications/Install macOS Tahoe.app"),
        name: "macOS Tahoe",
        version: "26.0",
        kind: .app,
        size: 16_800_000_000
    )

    private func drive(capacity: Int64 = 32_000_000_000, used: UsedSpace = .bytes(0)) -> Drive {
        Drive(
            id: "TEST",
            bsdName: "disk9",
            name: "Test Drive",
            model: "Test Drive",
            kind: .usbDrive,
            capacity: capacity,
            usedSpace: used
        )
    }

    // MARK: - Figures

    @Test func `erased is the space in use on the drive`() {
        let summary = ReviewSummary(installer: installer, drive: drive(used: .bytes(9_800_000_000)))
        #expect(summary.erased == .bytes(9_800_000_000))
        #expect(!summary.erasesNothing)
    }

    @Test func `data that can't be measured is erased, size unknown`() {
        let summary = ReviewSummary(installer: installer, drive: drive(used: .unknown))
        #expect(summary.erased == .unknown)
        #expect(!summary.erasesNothing)
    }

    @Test func `an empty drive erases nothing`() {
        // Under 100 MB, only the file system's own space is in use.
        let summary = ReviewSummary(installer: installer, drive: drive(used: .bytes(2_000_000)))
        #expect(summary.erasesNothing)
    }

    @Test func `installed is the installer size`() {
        let summary = ReviewSummary(installer: installer, drive: drive())
        #expect(summary.installedBytes == 16_800_000_000)
    }

    @Test func `free afterwards is the capacity minus the installer`() {
        let summary = ReviewSummary(installer: installer, drive: drive(capacity: 32_000_000_000))
        #expect(summary.freeAfterwardsBytes == 15_200_000_000)
    }

    @Test func `free afterwards is never negative`() {
        let summary = ReviewSummary(installer: installer, drive: drive(capacity: 8_000_000_000))
        #expect(summary.freeAfterwardsBytes == 0)
    }

    // MARK: - Usage bar

    @Test func `bar fraction is the installer size over the capacity`() {
        let summary = ReviewSummary(installer: installer, drive: drive(capacity: 33_600_000_000))
        #expect(summary.installedFraction == 0.5)
    }

    @Test func `bar fraction is clamped to a full bar`() {
        let summary = ReviewSummary(installer: installer, drive: drive(capacity: 8_000_000_000))
        #expect(summary.installedFraction == 1)
    }

    @Test func `bar fraction is full for a drive with no capacity`() {
        let summary = ReviewSummary(installer: installer, drive: drive(capacity: 0))
        #expect(summary.installedFraction == 1)
    }
}
