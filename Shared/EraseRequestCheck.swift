//
//  EraseRequestCheck.swift
//  Relente
//
//  What the helper checks on its own before erasing (helper rule 3): a whole disk's identifier,
//  a USB drive or SD card of a reasonable size that isn't the boot disk, and the same fingerprint
//  as the drive the user confirmed. Pure rules on what DiskArbitration reports, tested case by case.
//  Spec: specs/008-system-helper/spec.md
//

import Foundation

nonisolated enum EraseRequestCheck {

    /// Smallest disk the helper erases: 8 GB. The smallest supported installer needs more.
    static let minimumSize: Int64 = 8_000_000_000
    /// Largest disk the helper erases: 2 TB, the most an SD card (SDXC) holds.
    static let maximumSize: Int64 = 2_000_000_000_000

    /// Whether the identifier names a whole disk: `^disk[0-9]+$`, nothing before or after.
    static func isValidIdentifier(_ identifier: String) -> Bool {
        identifier.wholeMatch(of: /disk[0-9]+/.asciiOnlyDigits()) != nil
    }

    /// Why the disk can't be erased, or `nil` if it can. Read right before erasing.
    /// - Parameters:
    ///   - disk: the disk as DiskArbitration describes it now, or `nil` if it's gone.
    ///   - requested: the identifier the app asked to erase.
    ///   - confirmed: the fingerprint of the drive the user confirmed on Review.
    static func check(
        _ disk: DiskDescription?, requested: String, confirmed: DiskFingerprint, bootDisks: Set<String>
    ) -> FormatOutcome? {
        guard let disk else { return .driveDisconnected }
        guard disk.bsdName == requested, DiskRules.isUSBDriveOrSDCard(disk, bootDisks: bootDisks),
            (minimumSize...maximumSize).contains(disk.size)
        else { return .driveNotAllowed }
        guard DiskFingerprint(disk).matches(confirmed) else { return .driveChanged }
        return nil
    }
}
