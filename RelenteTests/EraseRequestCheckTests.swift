//
//  EraseRequestCheckTests.swift
//  RelenteTests
//
//  Helper rule 3: what the helper accepts before erasing. The disks are built like DiskArbitration
//  describes them; no real disk is touched.
//

import Foundation
import Testing

@testable import Relente

struct EraseRequestCheckTests {

    private func disk(
        _ bsdName: String = "disk4", isWhole: Bool = true, isInternal: Bool = false, isRemovable: Bool = true,
        deviceProtocol: String = "USB", uuid: String? = "UUID-4", serial: String? = "123",
        size: Int64 = 32_000_000_000, physicalWholeDisk: String? = nil
    ) -> DiskDescription {
        DiskDescription(
            bsdName: bsdName, isWhole: isWhole, isInternal: isInternal, isRemovable: isRemovable,
            deviceProtocol: deviceProtocol, mediaUUID: uuid, serialNumber: serial, size: size,
            physicalWholeDisk: physicalWholeDisk)
    }

    private func check(
        _ disk: DiskDescription?, requested: String = "disk4", confirmed: DiskFingerprint? = nil,
        bootDisks: Set<String> = ["disk0"]
    ) -> FormatOutcome? {
        EraseRequestCheck.check(
            disk, requested: requested,
            confirmed: confirmed ?? DiskFingerprint(mediaUUID: "UUID-4", serialNumber: "123", size: 32_000_000_000),
            bootDisks: bootDisks)
    }

    // MARK: - Identifier

    @Test(arguments: ["disk4", "disk0", "disk12"])
    func `a whole disk identifier is accepted`(identifier: String) {
        #expect(EraseRequestCheck.isValidIdentifier(identifier))
    }

    @Test(arguments: [
        "disk4s1", "disk", "../disk4", "disk4 ", " disk4", "disk4\n", "", "/dev/disk4", "rdisk4", "disk٤",
    ])
    func `anything else is refused`(identifier: String) {
        #expect(!EraseRequestCheck.isValidIdentifier(identifier))
    }

    // MARK: - Drive

    @Test func `a USB drive that matches what the user confirmed is accepted`() {
        #expect(check(disk()) == nil)
    }

    @Test func `an SD card is accepted, also in a built-in slot`() {
        #expect(check(disk(deviceProtocol: "Secure Digital")) == nil)
        #expect(check(disk(isInternal: true, deviceProtocol: "Secure Digital")) == nil)
    }

    @Test func `a disk that is gone is reported as disconnected`() {
        #expect(check(nil) == .driveDisconnected)
    }

    @Test func `a disk other than the one requested is refused`() {
        #expect(check(disk("disk5")) == .driveNotAllowed)
    }

    @Test func `a partition is refused`() {
        #expect(check(disk("disk4s1", isWhole: false), requested: "disk4s1") == .driveNotAllowed)
    }

    @Test func `internal, fixed and virtual disks are refused`() {
        #expect(check(disk(isInternal: true)) == .driveNotAllowed)
        #expect(check(disk(isRemovable: false)) == .driveNotAllowed)
        #expect(check(disk(deviceProtocol: "Virtual Interface")) == .driveNotAllowed)
        #expect(check(disk(deviceProtocol: "SATA")) == .driveNotAllowed)
        #expect(check(disk(physicalWholeDisk: "disk3")) == .driveNotAllowed)
    }

    @Test func `the boot disk is refused`() {
        #expect(check(disk(), bootDisks: ["disk4"]) == .driveNotAllowed)
    }

    @Test func `sizes from 8 GB to 2 TB are accepted`() {
        for size: Int64 in [8_000_000_000, 2_000_000_000_000] {
            let fingerprint = DiskFingerprint(mediaUUID: "UUID-4", serialNumber: "123", size: size)
            #expect(check(disk(size: size), confirmed: fingerprint) == nil)
        }
    }

    @Test func `smaller or larger disks are refused`() {
        for size: Int64 in [7_999_999_999, 2_000_000_000_001] {
            let fingerprint = DiskFingerprint(mediaUUID: "UUID-4", serialNumber: "123", size: size)
            #expect(check(disk(size: size), confirmed: fingerprint) == .driveNotAllowed)
        }
    }

    // MARK: - Fingerprint

    @Test func `a different media UUID, serial number or size is a changed drive`() {
        #expect(check(disk(uuid: "UUID-5")) == .driveChanged)
        #expect(check(disk(serial: "456")) == .driveChanged)
        #expect(check(disk(size: 32_000_000_001)) == .driveChanged)
    }

    @Test func `a part present on one side and absent on the other is a changed drive`() {
        #expect(check(disk(serial: nil)) == .driveChanged)
        #expect(check(disk(uuid: nil)) == .driveChanged)
    }

    @Test func `a drive with neither media UUID nor serial number is refused`() {
        let anonymous = DiskFingerprint(mediaUUID: nil, serialNumber: nil, size: 32_000_000_000)
        #expect(check(disk(uuid: nil, serial: nil), confirmed: anonymous) == .driveChanged)
    }
}
