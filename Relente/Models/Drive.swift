//
//  Drive.swift
//  Relente
//
//  A removable drive (USB drive or SD card) that can become the bootable installer.
//

import Foundation

nonisolated struct Drive: Identifiable, Hashable, Sendable {

    enum Kind: Hashable, Sendable {
        case usbDrive
        case sdCard
    }

    /// What the drive offers for the chosen installer, shown as a label under it.
    enum Status: Hashable, Sendable {
        /// It has data, which will be erased. The value is the space in use, in bytes.
        case willErase(usedBytes: Int64)
        /// Nothing on it; it can be used right away.
        case empty
        /// Smaller than the installer needs.
        case tooSmall

        /// Whether the drive can be picked.
        var isSelectable: Bool {
            switch self {
            case .willErase, .empty: true
            case .tooSmall: false
            }
        }
    }

    /// Media UUID. It stays the same when the drive is unplugged and plugged in again,
    /// unlike the BSD name.
    let id: String
    /// BSD name of the whole disk, e.g. "disk4".
    let bsdName: String
    /// Name shown to the user, e.g. "SanDisk Ultra".
    let name: String
    let kind: Kind
    /// Total capacity in bytes.
    let capacity: Int64
    /// Space in use, in bytes.
    let usedBytes: Int64

    /// Capacity formatted for people, e.g. "32 GB".
    var formattedCapacity: String {
        capacity.formatted(.byteCount(style: .file))
    }

    /// The drive's status for an installer of the given size.
    /// Being too small beats the space in use.
    func status(forInstallerSize installerSize: Int64) -> Status {
        if capacity < Self.requiredCapacity(forInstallerSize: installerSize) { return .tooSmall }
        return usedBytes > 0 ? .willErase(usedBytes: usedBytes) : .empty
    }

    /// Smallest drive that can hold an installer of the given size: the installer
    /// plus 1 GB of headroom. Apple doesn't give a figure per version, only that
    /// "a 32GB flash drive has more than enough storage space for any macOS installer,
    /// and 16GB is enough for most earlier versions" (support.apple.com/101578).
    static func requiredCapacity(forInstallerSize installerSize: Int64) -> Int64 {
        installerSize + 1_000_000_000
    }

    /// Size Apple says is enough for any macOS installer: 32 GB.
    static let recommendedCapacity: Int64 = 32_000_000_000
}

// MARK: - Sample data

nonisolated extension Drive {
    /// Fake drives for building the screens before real detection exists.
    /// With the sample installer (16.8 GB) they show every status.
    static let samples: [Drive] = [
        Drive(
            id: "5A1C2E4F-0001-4B6D-9C3A-111111111111",
            bsdName: "disk4",
            name: "SanDisk Ultra",
            kind: .usbDrive,
            capacity: 32_000_000_000,
            usedBytes: 9_800_000_000
        ),
        Drive(
            id: "5A1C2E4F-0002-4B6D-9C3A-222222222222",
            bsdName: "disk5",
            name: "Kingston DataTraveler",
            kind: .usbDrive,
            capacity: 64_000_000_000,
            usedBytes: 0
        ),
        Drive(
            id: "5A1C2E4F-0003-4B6D-9C3A-333333333333",
            bsdName: "disk6",
            name: "SD Card",
            kind: .sdCard,
            capacity: 8_000_000_000,
            usedBytes: 1_200_000_000
        ),
    ]
}
