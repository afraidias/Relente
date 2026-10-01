//
//  DiskDescription.swift
//  Relente
//
//  What Relente reads about one disk, partition or volume from DiskArbitration, as plain values.
//  The live drive service fills it in; tests build it by hand.
//  Spec: specs/007-real-detection/spec.md
//

import Foundation

nonisolated struct DiskDescription: Hashable, Sendable {
    /// BSD name, e.g. "disk4" for a whole disk or "disk4s1" for a partition.
    let bsdName: String
    /// Whether it's a whole disk rather than a partition or volume.
    let isWhole: Bool
    let isInternal: Bool
    /// Whether the media can be taken out (USB sticks and SD cards), unlike fixed external drives.
    let isRemovable: Bool
    /// How the device is connected, e.g. "USB", "Secure Digital", "SATA", "Virtual Interface".
    let deviceProtocol: String?
    let mediaUUID: String?
    let vendor: String?
    let model: String?
    let serialNumber: String?
    /// Size in bytes.
    let size: Int64
    /// Partition type or scheme, e.g. "GUID_partition_scheme", "Apple_APFS" or a partition GUID.
    let content: String?
    /// The volume's name as the Finder shows it, when it has a file system.
    let volumeName: String?
    /// Where its volume is mounted, if it is.
    let mountPoint: URL?
    /// For a volume in a synthesized APFS container: the physical whole disk that holds it.
    let physicalWholeDisk: String?

    init(
        bsdName: String, isWhole: Bool, isInternal: Bool = false, isRemovable: Bool = false,
        deviceProtocol: String? = nil, mediaUUID: String? = nil, vendor: String? = nil, model: String? = nil,
        serialNumber: String? = nil, size: Int64 = 0, content: String? = nil, volumeName: String? = nil,
        mountPoint: URL? = nil, physicalWholeDisk: String? = nil
    ) {
        self.bsdName = bsdName
        self.isWhole = isWhole
        self.isInternal = isInternal
        self.isRemovable = isRemovable
        self.deviceProtocol = deviceProtocol
        self.mediaUUID = mediaUUID
        self.vendor = vendor
        self.model = model
        self.serialNumber = serialNumber
        self.size = size
        self.content = content
        self.volumeName = volumeName
        self.mountPoint = mountPoint
        self.physicalWholeDisk = physicalWholeDisk
    }

    /// The whole disk a partition belongs to: "disk4s1" → "disk4". A whole disk is its own.
    var wholeDiskName: String {
        guard !isWhole, let range = bsdName.range(of: #"^disk[0-9]+"#, options: .regularExpression) else {
            return bsdName
        }
        return String(bsdName[range])
    }

    /// The partition's number on its disk, for ordering: "disk4s2" → 2.
    var partitionNumber: Int {
        guard let suffix = bsdName.range(of: #"[0-9]+$"#, options: .regularExpression), !isWhole else { return 0 }
        return Int(bsdName[suffix]) ?? 0
    }
}
