//
//  DiskRules.swift
//  Relente
//
//  Which disks are USB drives or SD cards. The app uses it to list drives; the helper, to refuse
//  any other disk before erasing (helper rule 3). One implementation for both.
//  Spec: specs/008-system-helper/spec.md (rule from specs/007-real-detection/spec.md)
//

import Foundation

nonisolated enum DiskRules {

    static let usbProtocol = "USB"
    static let secureDigitalProtocol = "Secure Digital"

    /// Whether a disk is a USB drive or SD card: a whole, removable disk over USB (external) or
    /// an SD card (also in a built-in slot), never a synthesized APFS disk or one the Mac started
    /// up from.
    static func isUSBDriveOrSDCard(_ disk: DiskDescription, bootDisks: Set<String>) -> Bool {
        guard disk.isWhole, disk.isRemovable, disk.physicalWholeDisk == nil, !bootDisks.contains(disk.bsdName)
        else { return false }
        switch disk.deviceProtocol {
        case usbProtocol: return !disk.isInternal
        case secureDigitalProtocol: return true
        default: return false
        }
    }
}
