//
//  DiskutilCommand.swift
//  Relente
//
//  The only command the helper runs in this step (helper rule 1): `diskutil` from its fixed path,
//  with its arguments as an array, never through a shell. The drive is erased as Apple's guide
//  prepares it (support.apple.com/101578): Mac OS Extended (Journaled), named "MyVolume", here on
//  a GPT partition map.
//  Spec: specs/008-system-helper/spec.md
//

import Foundation

nonisolated enum DiskutilCommand {
    static let executable = URL(filePath: "/usr/sbin/diskutil")
    static let volumeName = "MyVolume"

    /// The arguments to erase a whole disk, or `nil` if the identifier isn't a whole disk's.
    static func eraseArguments(for bsdName: String) -> [String]? {
        guard EraseRequestCheck.isValidIdentifier(bsdName) else { return nil }
        return ["eraseDisk", "JHFS+", volumeName, "GPT", bsdName]
    }
}
