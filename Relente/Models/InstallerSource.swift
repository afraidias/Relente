//
//  InstallerSource.swift
//  Relente
//
//  A macOS installer the user can pick as the source for the USB drive.
//

import Foundation
import UniformTypeIdentifiers

nonisolated struct InstallerSource: Identifiable, Hashable, Sendable {

    /// The three kinds of source files the app accepts.
    enum Kind: Hashable, Sendable {
        /// `Install macOS *.app`
        case app
        /// `.dmg` that contains the installer app.
        case diskImage
        /// `InstallAssistant.pkg`
        case package

        /// File type used to show a generic icon when the file doesn't exist.
        var contentType: UTType {
            switch self {
            case .app: .applicationBundle
            case .diskImage: .diskImage
            case .package: UTType("com.apple.installer-package-archive") ?? .data
            }
        }
    }

    /// Location of the file on disk. It is also its identity: the same file
    /// found again in a later scan is the same installer.
    let url: URL
    /// Marketing name, e.g. "macOS Tahoe".
    let name: String
    /// macOS version, e.g. 26.0.
    let version: MacOSVersion
    let kind: Kind
    /// Size in bytes.
    let size: Int64

    var id: URL { url }

    /// Whether Relente can make a bootable drive from it: macOS Big Sur (11) or later.
    var isSupported: Bool {
        version >= .bigSur
    }

    /// Size formatted for people, e.g. "16.8 GB".
    var formattedSize: String {
        size.formatted(.byteCount(style: .file))
    }
}

// MARK: - Order and default selection

nonisolated extension InstallerSource {
    /// Newest macOS first. Installers of the same version keep their order.
    static func sorted(_ installers: [InstallerSource]) -> [InstallerSource] {
        installers.enumerated()
            .sorted { lhs, rhs in
                lhs.element.version != rhs.element.version
                    ? lhs.element.version > rhs.element.version : lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    /// The installer selected when the list first fills: the newest supported one.
    static func defaultSelection(in installers: [InstallerSource]) -> InstallerSource? {
        sorted(installers).first(where: \.isSupported)
    }
}

// MARK: - Sample data

nonisolated extension InstallerSource {
    /// Fake installers for building the screens before real detection exists.
    static let samples: [InstallerSource] = [
        InstallerSource(
            url: URL(filePath: "/Applications/Install macOS Tahoe.app"),
            name: "macOS Tahoe",
            version: "26.0",
            kind: .app,
            size: 16_800_000_000
        ),
        InstallerSource(
            url: URL(filePath: "/Users/Shared/macOS Sequoia.dmg"),
            name: "macOS Sequoia",
            version: "15.6",
            kind: .diskImage,
            size: 15_200_000_000
        ),
        InstallerSource(
            url: URL(filePath: "/Users/Shared/InstallAssistant.pkg"),
            name: "macOS Sonoma",
            version: "14.7",
            kind: .package,
            size: 13_400_000_000
        ),
    ]

    /// An installer older than Big Sur, which Relente shows but can't use.
    static let unsupportedSample = InstallerSource(
        url: URL(filePath: "/Applications/Install macOS Catalina.app"),
        name: "macOS Catalina",
        version: "10.15.7",
        kind: .app,
        size: 8_100_000_000
    )
}
