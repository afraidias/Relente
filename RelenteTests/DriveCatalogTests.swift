//
//  DriveCatalogTests.swift
//  RelenteTests
//
//  The disks are built like DiskArbitration describes them; no real disk is touched.
//

import Foundation
import Testing

@testable import Relente

struct DriveCatalogTests {

    private static let efi = "C12A7328-F81F-11D2-BA4B-00A0C93EC93B"
    private static let msData = "EBD0A0A2-B9E5-4433-87C0-68B6B72699C7"
    private static let apfs = "7C3457EF-0000-11AA-AA11-00306543ECAC"
    private static let linux = "0FC63DAF-8483-4772-8E79-3D69D8477DE4"

    private func usbStick(
        _ bsdName: String = "disk4", uuid: String? = "UUID-4", isRemovable: Bool = true, isInternal: Bool = false,
        deviceProtocol: String = "USB", content: String? = "GUID_partition_scheme", mountPoint: URL? = nil,
        volumeName: String? = nil
    ) -> DiskDescription {
        DiskDescription(
            bsdName: bsdName, isWhole: true, isInternal: isInternal, isRemovable: isRemovable,
            deviceProtocol: deviceProtocol, mediaUUID: uuid, vendor: "SanDisk", model: "Ultra", serialNumber: "123",
            size: 32_000_000_000, content: content, volumeName: volumeName, mountPoint: mountPoint)
    }

    private func partition(
        _ bsdName: String, content: String = msData, volumeName: String? = nil, mounted: Bool = true
    ) -> DiskDescription {
        DiskDescription(
            bsdName: bsdName, isWhole: false, size: 1, content: content, volumeName: volumeName,
            mountPoint: mounted ? URL(filePath: "/Volumes/\(volumeName ?? bsdName)") : nil)
    }

    private func onlyDrive(
        _ disks: [DiskDescription], used: [String: Int64] = [:], bootDisks: Set<String> = []
    ) throws -> Drive {
        let drives = DriveCatalog.drives(from: disks, usedBytes: used, bootDisks: bootDisks)
        try #require(drives.count == 1)
        return drives[0]
    }

    // MARK: - Which disks

    @Test func `a removable USB disk is a candidate`() {
        #expect(DriveCatalog.isCandidate(usbStick(), bootDisks: []))
    }

    @Test func `an SD card is a candidate, also in a built-in slot`() {
        #expect(DriveCatalog.isCandidate(usbStick(deviceProtocol: "Secure Digital"), bootDisks: []))
        #expect(DriveCatalog.isCandidate(usbStick(isInternal: true, deviceProtocol: "Secure Digital"), bootDisks: []))
    }

    @Test func `an external SSD, which reports fixed media, isn't`() {
        #expect(!DriveCatalog.isCandidate(usbStick(isRemovable: false), bootDisks: []))
    }

    @Test(arguments: ["SATA", "PCI-Express", "Apple Fabric", "Virtual Interface", "Disk Image", "Thunderbolt"])
    func `internal, Thunderbolt and virtual disks aren't`(deviceProtocol: String) {
        #expect(!DriveCatalog.isCandidate(usbStick(deviceProtocol: deviceProtocol), bootDisks: []))
    }

    @Test func `an internal USB device isn't`() {
        #expect(!DriveCatalog.isCandidate(usbStick(isInternal: true), bootDisks: []))
    }

    @Test func `a partition isn't, only whole disks`() {
        #expect(!DriveCatalog.isCandidate(partition("disk4s1"), bootDisks: []))
    }

    @Test func `the disk the Mac started up from isn't`() {
        #expect(!DriveCatalog.isCandidate(usbStick("disk4"), bootDisks: ["disk4"]))
    }

    @Test func `a synthesized APFS container isn't`() {
        let container = DiskDescription(
            bsdName: "disk5", isWhole: true, isRemovable: true, deviceProtocol: "USB", physicalWholeDisk: "disk4")
        #expect(!DriveCatalog.isCandidate(container, bootDisks: []))
    }

    @Test func `drives are listed in disk order, with only their own partitions`() throws {
        let drives = DriveCatalog.drives(
            from: [
                usbStick("disk10", uuid: "B"), partition("disk10s1", volumeName: "TEN"), usbStick("disk4", uuid: "A"),
                partition("disk4s1", volumeName: "FOUR"), partition("disk1s1", volumeName: "Macintosh HD"),
            ],
            usedBytes: ["disk10s1": 0, "disk4s1": 0], bootDisks: [])
        #expect(drives.map(\.bsdName) == ["disk4", "disk10"])
        #expect(drives.map(\.name) == ["FOUR", "TEN"])
    }

    @Test func `an SD card is an SD card, anything else a USB drive`() throws {
        #expect(try onlyDrive([usbStick(deviceProtocol: "Secure Digital")]).kind == .sdCard)
        #expect(try onlyDrive([usbStick()]).kind == .usbDrive)
    }

    // MARK: - Names

    @Test func `the name is the volume's, the model is vendor and product`() throws {
        let drive = try onlyDrive([usbStick(), partition("disk4s1", volumeName: "Photos 2023")], used: ["disk4s1": 0])
        #expect(drive.name == "Photos 2023")
        #expect(drive.model == "SanDisk Ultra")
    }

    @Test func `with several volumes, the first on the disk names it`() throws {
        let drive = try onlyDrive(
            [usbStick(), partition("disk4s2", volumeName: "SECOND"), partition("disk4s1", volumeName: "FIRST")],
            used: ["disk4s1": 0, "disk4s2": 0])
        #expect(drive.name == "FIRST")
    }

    @Test func `the EFI partition doesn't name the drive`() throws {
        let drive = try onlyDrive(
            [
                usbStick(), partition("disk4s1", content: Self.efi, volumeName: "EFI"),
                partition("disk4s2", volumeName: "DATA"),
            ],
            used: ["disk4s1": 0, "disk4s2": 0])
        #expect(drive.name == "DATA")
    }

    @Test func `without a named volume, the model names it`() throws {
        let drive = try onlyDrive([usbStick(content: nil)])
        #expect(drive.name == "SanDisk Ultra")
        #expect(drive.detail == "32 GB")
    }

    @Test func `a model that already starts with the vendor isn't repeated`() {
        let disk = DiskDescription(bsdName: "disk4", isWhole: true, vendor: "Kingston", model: "Kingston DataTraveler")
        #expect(DriveCatalog.modelName(of: disk, kind: .usbDrive) == "Kingston DataTraveler")
    }

    @Test func `a drive that reports no vendor or product gets a generic model`() {
        let disk = DiskDescription(bsdName: "disk4", isWhole: true, vendor: "  ", model: nil)
        #expect(DriveCatalog.modelName(of: disk, kind: .usbDrive) == DriveCatalog.genericUSBDriveName)
    }

    @Test func `an SD card's model is always the generic one`() {
        let disk = DiskDescription(bsdName: "disk4", isWhole: true, vendor: "APPLE", model: "SDXC Reader")
        #expect(DriveCatalog.modelName(of: disk, kind: .sdCard) == DriveCatalog.genericSDCardName)
    }

    // MARK: - Identity

    @Test func `the identity is the media UUID`() throws {
        #expect(try onlyDrive([usbStick(uuid: "5A1C2E4F")]).id == "5A1C2E4F")
    }

    @Test func `without a media UUID, vendor, model, serial and size tell it apart`() {
        let identity = DriveCatalog.identity(of: usbStick(uuid: nil))
        #expect(identity == "SanDisk|Ultra|123|32000000000")
        #expect(identity == DriveCatalog.identity(of: usbStick("disk9", uuid: nil)))
    }

    // MARK: - Space in use

    @Test func `adds up the space used by every mounted volume`() throws {
        let drive = try onlyDrive(
            [usbStick(), partition("disk4s1", volumeName: "A"), partition("disk4s2", volumeName: "B")],
            used: ["disk4s1": 1_000_000_000, "disk4s2": 500_000_000])
        #expect(drive.usedSpace == .bytes(1_500_000_000))
    }

    @Test func `system partitions don't count`() throws {
        let drive = try onlyDrive(
            [
                usbStick(), partition("disk4s1", content: Self.efi, mounted: false),
                partition("disk4s2", volumeName: "B"),
            ],
            used: ["disk4s2": 20_000_000])
        #expect(drive.usedSpace == .bytes(20_000_000))
        #expect(drive.isEmpty)
    }

    @Test func `a partition that isn't mounted holds data of unknown size`() throws {
        let drive = try onlyDrive(
            [
                usbStick(), partition("disk4s1", content: Self.linux, mounted: false),
                partition("disk4s2", volumeName: "B"),
            ],
            used: ["disk4s2": 0])
        #expect(drive.usedSpace == .unknown)
    }

    @Test func `a mounted volume without figures is unknown`() throws {
        let drive = try onlyDrive([usbStick(), partition("disk4s1", volumeName: "A")])
        #expect(drive.usedSpace == .unknown)
    }

    @Test func `a file system right on the disk is measured`() throws {
        let card = usbStick(content: "", mountPoint: URL(filePath: "/Volumes/CARD"), volumeName: "CARD")
        let drive = try onlyDrive([card], used: ["disk4": 3_000_000_000])
        #expect(drive.name == "CARD")
        #expect(drive.usedSpace == .bytes(3_000_000_000))
    }

    @Test func `a disk with no partitions at all is empty`() throws {
        #expect(try onlyDrive([usbStick(content: nil)]).usedSpace == .bytes(0))
        #expect(try onlyDrive([usbStick(content: "")]).usedSpace == .bytes(0))
    }

    @Test func `an unmounted file system right on the disk is unknown`() throws {
        #expect(try onlyDrive([usbStick(content: "Linux")]).usedSpace == .unknown)
    }

    @Test func `an APFS container counts its use once, through its volumes`() throws {
        let volume1 = DiskDescription(
            bsdName: "disk5s1", isWhole: false, volumeName: "Backup", mountPoint: URL(filePath: "/Volumes/Backup"),
            physicalWholeDisk: "disk4")
        let volume2 = DiskDescription(
            bsdName: "disk5s2", isWhole: false, volumeName: "Other", mountPoint: URL(filePath: "/Volumes/Other"),
            physicalWholeDisk: "disk4")
        let drive = try onlyDrive(
            [
                usbStick(), partition("disk4s1", content: Self.efi, mounted: false),
                partition("disk4s2", content: Self.apfs, mounted: false), volume1, volume2,
            ],
            used: ["disk5s1": 4_000_000_000, "disk5s2": 4_000_000_000])
        #expect(drive.name == "Backup")
        #expect(drive.usedSpace == .bytes(4_000_000_000))
    }

    @Test func `a locked APFS volume makes the use unknown`() throws {
        let locked = DiskDescription(
            bsdName: "disk5s1", isWhole: false, volumeName: "Secret", physicalWholeDisk: "disk4")
        let drive = try onlyDrive([usbStick(), partition("disk4s2", content: Self.apfs, mounted: false), locked])
        #expect(drive.usedSpace == .unknown)
    }
}
