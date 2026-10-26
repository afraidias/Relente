//
//  DiskDescriber.swift
//  Relente
//
//  Reads a disk's description from DiskArbitration and the I/O Registry into a `DiskDescription`,
//  and finds the disks the Mac started up from. The app's drive service and the helper read disks
//  the same way.
//  Spec: specs/008-system-helper/spec.md (moved from specs/007-real-detection/spec.md)
//

import DiskArbitration
import Foundation
import IOKit

nonisolated enum DiskDescriber {

    /// The description of a disk, partition or volume, or `nil` if it has no BSD name.
    static func describe(_ disk: DADisk) -> DiskDescription? {
        guard let description = DADiskCopyDescription(disk) as? [CFString: Any],
            let bsdName = description[kDADiskDescriptionMediaBSDNameKey] as? String
        else { return nil }
        let uuid = description[kDADiskDescriptionMediaUUIDKey].flatMap { value -> String? in
            let object = value as CFTypeRef
            guard CFGetTypeID(object) == CFUUIDGetTypeID() else { return nil }
            return CFUUIDCreateString(kCFAllocatorDefault, unsafeDowncast(object, to: CFUUID.self)) as String
        }
        let isWhole = description[kDADiskDescriptionMediaWholeKey] as? Bool ?? false
        let ancestry = IOMediaAncestry(disk: disk)
        return DiskDescription(
            bsdName: bsdName,
            isWhole: isWhole,
            isInternal: description[kDADiskDescriptionDeviceInternalKey] as? Bool ?? true,
            isRemovable: description[kDADiskDescriptionMediaRemovableKey] as? Bool ?? false,
            deviceProtocol: description[kDADiskDescriptionDeviceProtocolKey] as? String,
            mediaUUID: uuid,
            vendor: description[kDADiskDescriptionDeviceVendorKey] as? String,
            model: description[kDADiskDescriptionDeviceModelKey] as? String,
            serialNumber: ancestry.serialNumber,
            size: (description[kDADiskDescriptionMediaSizeKey] as? NSNumber)?.int64Value ?? 0,
            content: description[kDADiskDescriptionMediaContentKey] as? String,
            volumeName: description[kDADiskDescriptionVolumeNameKey] as? String,
            mountPoint: description[kDADiskDescriptionVolumePathKey] as? URL,
            physicalWholeDisk: ancestry.physicalWholeDisk.flatMap { physical in
                let own = isWhole ? bsdName : DiskDescription(bsdName: bsdName, isWhole: false).wholeDiskName
                return physical == own ? nil : physical
            }
        )
    }

    /// The physical whole disks behind the startup volume and its data volume.
    static func bootDisks(session: DASession) -> Set<String> {
        Set(
            ["/", "/System/Volumes/Data"].compactMap { path in
                DADiskCreateFromVolumePath(kCFAllocatorDefault, session, URL(filePath: path) as CFURL)
                    .flatMap { IOMediaAncestry(disk: $0).physicalWholeDisk }
            })
    }
}

// MARK: - IOKit

/// What the I/O Registry says above a disk: the outermost whole disk (the physical one behind an
/// APFS volume) and the USB serial number.
private nonisolated struct IOMediaAncestry {
    var physicalWholeDisk: String?
    var serialNumber: String?

    init(disk: DADisk) {
        let media = DADiskCopyIOMedia(disk)
        guard media != IO_OBJECT_NULL else { return }
        var entry = media
        IOObjectRetain(entry)
        while entry != IO_OBJECT_NULL {
            if IOObjectConformsTo(entry, "IOMedia") != 0,
                Self.property("Whole", of: entry) as? Bool == true,
                let name = Self.property("BSD Name", of: entry) as? String
            {
                physicalWholeDisk = name
            }
            if serialNumber == nil {
                serialNumber = Self.property("USB Serial Number", of: entry) as? String
            }
            var parent: io_registry_entry_t = IO_OBJECT_NULL
            let result = IORegistryEntryGetParentEntry(entry, kIOServicePlane, &parent)
            IOObjectRelease(entry)
            entry = result == KERN_SUCCESS ? parent : IO_OBJECT_NULL
        }
        IOObjectRelease(media)
    }

    private static func property(_ key: String, of entry: io_registry_entry_t) -> Any? {
        IORegistryEntryCreateCFProperty(entry, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
    }
}
