//
//  DriveTests.swift
//  RelenteTests
//

import Testing

@testable import Relente

struct DriveTests {

    /// Size of the sample Tahoe installer: 16.8 GB.
    let installerSize: Int64 = 16_800_000_000

    private func drive(capacity: Int64, usedBytes: Int64 = 0) -> Drive {
        Drive(
            id: "TEST",
            bsdName: "disk9",
            name: "Test Drive",
            kind: .usbDrive,
            capacity: capacity,
            usedBytes: usedBytes
        )
    }

    // MARK: - Required capacity

    @Test func `required capacity is the installer plus 1 GB of headroom`() {
        #expect(Drive.requiredCapacity(forInstallerSize: installerSize) == 17_800_000_000)
    }

    @Test func `a drive sold as 16 GB fits an older installer`() {
        // "16GB is enough for most earlier versions of macOS" (Apple). Drives sold as 16 GB
        // usually have a bit less, e.g. 15.5 GB; a Big Sur installer is about 12.5 GB.
        let status = drive(capacity: 15_500_000_000).status(forInstallerSize: 12_500_000_000)
        #expect(status == .empty)
    }

    @Test func `a 32 GB drive fits a recent installer`() {
        // "A 32GB flash drive has more than enough storage space for any macOS installer" (Apple).
        #expect(Drive.recommendedCapacity == 32_000_000_000)
        #expect(drive(capacity: Drive.recommendedCapacity).status(forInstallerSize: installerSize) == .empty)
    }

    // MARK: - Status

    @Test func `an empty drive that is big enough is empty`() {
        #expect(drive(capacity: 64_000_000_000).status(forInstallerSize: installerSize) == .empty)
    }

    @Test func `a drive with data reports how much will be erased`() {
        let status = drive(capacity: 32_000_000_000, usedBytes: 9_800_000_000).status(forInstallerSize: installerSize)
        #expect(status == .willErase(usedBytes: 9_800_000_000))
    }

    @Test func `a drive smaller than required is too small`() {
        #expect(drive(capacity: 16_000_000_000).status(forInstallerSize: installerSize) == .tooSmall)
    }

    @Test func `a drive exactly the required size is big enough`() {
        #expect(drive(capacity: 17_800_000_000).status(forInstallerSize: installerSize) == .empty)
    }

    @Test func `being too small wins over having data`() {
        let status = drive(capacity: 8_000_000_000, usedBytes: 1_000_000_000).status(forInstallerSize: installerSize)
        #expect(status == .tooSmall)
    }

    @Test(arguments: [
        (Drive.Status.willErase(usedBytes: 1), true),
        (.empty, true),
        (.tooSmall, false),
    ])
    func `only drives that can be used are selectable`(status: Drive.Status, isSelectable: Bool) {
        #expect(status.isSelectable == isSelectable)
    }

    // MARK: - Sample data

    @Test func `samples cover every status for the sample installer`() {
        let statuses = Drive.samples.map { $0.status(forInstallerSize: installerSize) }
        #expect(statuses.contains(.empty))
        #expect(statuses.contains(.tooSmall))
        #expect(statuses.contains { if case .willErase = $0 { true } else { false } })
    }
}
