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
        /// It has data, which will be erased: how much, or `.unknown`.
        case willErase(UsedSpace)
        /// Nothing on it but its own file system; it can be used right away.
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
    /// Name shown to the user: its volume's name as the Finder shows it, e.g. "Photos 2023", or
    /// its model when it has no named volume.
    let name: String
    /// Vendor and product, e.g. "SanDisk Ultra".
    let model: String
    let kind: Kind
    /// Total capacity in bytes.
    let capacity: Int64
    /// What is stored on it.
    let usedSpace: UsedSpace

    /// Capacity formatted for people, e.g. "32 GB".
    var formattedCapacity: String {
        capacity.formatted(.byteCount(style: .file))
    }

    /// The first line under the name on the USB Drive screen: the model, or what kind of drive it
    /// is ("USB Drive", "SD Card") when the name already is the model, so every drive has the line.
    var subtitle: String {
        guard name == model else { return model }
        return switch kind {
        case .usbDrive: DriveCatalog.genericUSBDriveName
        case .sdCard: DriveCatalog.genericSDCardName
        }
    }

    /// The line under the name: "SanDisk Ultra · 32 GB", or only "32 GB" when the name is the model.
    var detail: String {
        name == model ? formattedCapacity : "\(model) · \(formattedCapacity)"
    }

    /// Whether only the file system's own space is in use: under `emptyThreshold`.
    var isEmpty: Bool {
        switch usedSpace {
        case .bytes(let bytes): bytes < Self.emptyThreshold
        case .unknown: false
        }
    }

    /// How full the usage bar under the drive is, from 0 to 1. No fill when the drive counts as
    /// empty or its data can't be measured.
    var usageFraction: Double {
        guard !isEmpty, case .bytes(let bytes) = usedSpace, capacity > 0 else { return 0 }
        return min(Double(bytes) / Double(capacity), 1)
    }

    /// The drive's status for an installer of the given size.
    /// Being too small beats the space in use.
    func status(forInstallerSize installerSize: Int64) -> Status {
        if capacity < Self.requiredCapacity(forInstallerSize: installerSize) { return .tooSmall }
        return isEmpty ? .empty : .willErase(usedSpace)
    }

    /// Below this much space in use (100 MB), a drive counts as empty: a freshly formatted drive
    /// always uses a little space for its own file system.
    static let emptyThreshold: Int64 = 100_000_000

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
            model: "SanDisk Ultra",
            kind: .usbDrive,
            capacity: 32_000_000_000,
            usedSpace: .bytes(9_800_000_000)
        ),
        Drive(
            id: "5A1C2E4F-0002-4B6D-9C3A-222222222222",
            bsdName: "disk5",
            name: "UNTITLED",
            model: "Kingston DataTraveler",
            kind: .usbDrive,
            capacity: 64_000_000_000,
            usedSpace: .bytes(2_000_000)
        ),
        Drive(
            id: "5A1C2E4F-0003-4B6D-9C3A-333333333333",
            bsdName: "disk6",
            name: "Photos 2023",
            model: "SD Card",
            kind: .sdCard,
            capacity: 8_000_000_000,
            usedSpace: .bytes(1_200_000_000)
        ),
    ]

    /// A drive with data Relente can't measure, e.g. formatted for Linux.
    static let unknownDataSample = Drive(
        id: "5A1C2E4F-0004-4B6D-9C3A-444444444444",
        bsdName: "disk7",
        name: "Lexar JumpDrive",
        model: "Lexar JumpDrive",
        kind: .usbDrive,
        capacity: 32_000_000_000,
        usedSpace: .unknown
    )
}
