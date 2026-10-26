//
//  DiskFingerprint.swift
//  Relente
//
//  What identifies the drive the user confirmed on Review. The helper compares it with the disk
//  it's about to erase, right before erasing, so a drive swapped in the meantime is refused
//  (helper rule 3).
//  Spec: specs/008-system-helper/spec.md
//

import Foundation

nonisolated struct DiskFingerprint: Hashable, Sendable {
    let mediaUUID: String?
    let serialNumber: String?
    /// Size in bytes.
    let size: Int64

    init(mediaUUID: String?, serialNumber: String?, size: Int64) {
        self.mediaUUID = mediaUUID
        self.serialNumber = serialNumber
        self.size = size
    }

    /// The fingerprint of a whole disk, as DiskArbitration describes it.
    init(_ disk: DiskDescription) {
        self.init(mediaUUID: disk.mediaUUID, serialNumber: disk.serialNumber, size: disk.size)
    }

    /// Whether it tells the drive apart from others: it has a media UUID or a serial number. Its
    /// size alone could match another drive.
    var isIdentifiable: Bool {
        Self.normalized(mediaUUID) != nil || Self.normalized(serialNumber) != nil
    }

    /// Whether it's the same drive: identifiable, and every part equal, absent included. Media
    /// UUIDs compare regardless of case.
    func matches(_ other: DiskFingerprint) -> Bool {
        isIdentifiable
            && Self.normalized(mediaUUID)?.uppercased() == Self.normalized(other.mediaUUID)?.uppercased()
            && Self.normalized(serialNumber) == Self.normalized(other.serialNumber)
            && size == other.size
    }

    /// Empty or blank values count as absent.
    private static func normalized(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return value
    }
}
