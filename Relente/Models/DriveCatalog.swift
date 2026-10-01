//
//  DriveCatalog.swift
//  Relente
//
//  Turns what DiskArbitration reports into the drives Relente shows: which disks are USB drives
//  or SD cards, their names, identity and the space in use. Pure rules, tested case by case.
//  Spec: specs/007-real-detection/spec.md
//

import Foundation

nonisolated enum DriveCatalog {

    static let usbProtocol = "USB"
    static let secureDigitalProtocol = "Secure Digital"

    // MARK: - Which disks

    /// Whether a disk is a USB drive or SD card Relente can offer: a whole, removable disk over
    /// USB (external) or an SD card (also in a built-in slot), never one the Mac started up from.
    static func isCandidate(_ disk: DiskDescription, bootDisks: Set<String>) -> Bool {
        guard disk.isWhole, disk.isRemovable, disk.physicalWholeDisk == nil, !bootDisks.contains(disk.bsdName)
        else { return false }
        switch disk.deviceProtocol {
        case usbProtocol: return !disk.isInternal
        case secureDigitalProtocol: return true
        default: return false
        }
    }

    /// The drives among every disk, partition and volume DiskArbitration reports.
    /// - Parameter usedBytes: space in use of each mounted volume, by BSD name.
    static func drives(
        from disks: [DiskDescription], usedBytes: [String: Int64], bootDisks: Set<String>
    ) -> [Drive] {
        disks.filter { isCandidate($0, bootDisks: bootDisks) }
            .sorted { $0.bsdName.localizedStandardCompare($1.bsdName) == .orderedAscending }
            .map { whole in
                let partitions = disks.filter { !$0.isWhole && $0.wholeDiskName == whole.bsdName }
                    .sorted { $0.partitionNumber < $1.partitionNumber }
                let apfsVolumes = disks.filter { !$0.isWhole && $0.physicalWholeDisk == whole.bsdName }
                    .sorted { $0.bsdName.localizedStandardCompare($1.bsdName) == .orderedAscending }
                return drive(whole: whole, partitions: partitions, apfsVolumes: apfsVolumes, usedBytes: usedBytes)
            }
    }

    static func drive(
        whole: DiskDescription, partitions: [DiskDescription], apfsVolumes: [DiskDescription],
        usedBytes: [String: Int64]
    ) -> Drive {
        let kind: Drive.Kind = whole.deviceProtocol == secureDigitalProtocol ? .sdCard : .usbDrive
        let model = modelName(of: whole, kind: kind)
        let dataPartitions = partitions.filter { !isSystemPartition($0) }
        let volumes = (whole.mountPoint != nil ? [whole] : []) + dataPartitions + apfsVolumes
        let name = volumes.lazy.compactMap { $0.volumeName?.trimmed }.first { !$0.isEmpty } ?? model
        return Drive(
            id: identity(of: whole),
            bsdName: whole.bsdName,
            name: name,
            model: model,
            kind: kind,
            capacity: whole.size,
            usedSpace: usedSpace(
                whole: whole, partitions: dataPartitions, apfsVolumes: apfsVolumes, usedBytes: usedBytes)
        )
    }

    // MARK: - Names and identity

    /// Vendor and product, e.g. "SanDisk Ultra". An SD card is always "SD Card": what macOS
    /// reports is the reader, not the card. A drive that reports nothing gets "USB Drive".
    static func modelName(of disk: DiskDescription, kind: Drive.Kind) -> String {
        if kind == .sdCard { return genericSDCardName }
        let vendor = disk.vendor?.trimmed ?? ""
        let model = disk.model?.trimmed ?? ""
        let name =
            vendor.isEmpty || model.lowercased().hasPrefix(vendor.lowercased())
            ? model : model.isEmpty ? vendor : "\(vendor) \(model)"
        return name.isEmpty ? genericUSBDriveName : name
    }

    static var genericSDCardName: String {
        String(localized: "SD Card", comment: "Model shown for an SD card: macOS reports the reader, not the card.")
    }

    static var genericUSBDriveName: String {
        String(localized: "USB Drive", comment: "Model shown for a USB drive that reports no vendor or product name.")
    }

    /// The media UUID, which stays the same when the drive is plugged in again. Drives without
    /// one (some MBR-formatted ones) are told apart by vendor, model, serial number and size.
    static func identity(of disk: DiskDescription) -> String {
        if let uuid = disk.mediaUUID, !uuid.isEmpty { return uuid }
        return [
            disk.vendor?.trimmed ?? "", disk.model?.trimmed ?? "", disk.serialNumber?.trimmed ?? "", "\(disk.size)",
        ]
        .joined(separator: "|")
    }

    // MARK: - Space in use

    /// Partition types that never hold the user's data: EFI, Apple_Boot, Microsoft Reserved.
    private static let systemPartitionTypes: Set<String> = [
        "EFI", "C12A7328-F81F-11D2-BA4B-00A0C93EC93B",
        "Apple_Boot", "426F6F74-0000-11AA-AA11-00306543ECAC",
        "Microsoft Reserved", "E3C9E316-0B5C-4DB8-817D-F92DF00215AE",
    ]

    /// Partition types of an APFS container, whose space is measured through its volumes.
    private static let apfsContainerTypes: Set<String> = ["Apple_APFS", "7C3457EF-0000-11AA-AA11-00306543ECAC"]

    static func isSystemPartition(_ partition: DiskDescription) -> Bool {
        partition.content.map { systemPartitionTypes.contains($0.uppercasedGUID) } ?? false
    }

    /// The sum of what the drive's mounted volumes use. Anything that holds data but can't be
    /// measured (not mounted, or a locked APFS volume) makes it `.unknown`.
    static func usedSpace(
        whole: DiskDescription, partitions: [DiskDescription], apfsVolumes: [DiskDescription],
        usedBytes: [String: Int64]
    ) -> UsedSpace {
        // A file system right on the disk, without partitions (common on SD cards).
        if partitions.isEmpty {
            if whole.mountPoint != nil { return usedBytes[whole.bsdName].map(UsedSpace.bytes) ?? .unknown }
            let hasNoData = whole.content?.isEmpty ?? true
            return hasNoData ? .bytes(0) : .unknown
        }

        var total: Int64 = 0
        for partition in partitions {
            if partition.content.map({ apfsContainerTypes.contains($0.uppercasedGUID) }) ?? false {
                // Every APFS volume reports the whole container's use, so take it once.
                guard !apfsVolumes.isEmpty, apfsVolumes.allSatisfy({ $0.mountPoint != nil }) else { return .unknown }
                let containerUse = apfsVolumes.compactMap { usedBytes[$0.bsdName] }
                guard containerUse.count == apfsVolumes.count, let used = containerUse.max() else { return .unknown }
                total += used
            } else {
                guard partition.mountPoint != nil, let used = usedBytes[partition.bsdName] else { return .unknown }
                total += used
            }
        }
        return .bytes(total)
    }
}

// MARK: - Helpers

nonisolated extension String {
    fileprivate var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// GUIDs compare in upper case; other partition types are left as they are.
    fileprivate var uppercasedGUID: String {
        count == 36 ? uppercased() : self
    }
}
