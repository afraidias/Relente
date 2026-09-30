//
//  InstallerSource.swift
//  Relente
//
//  A macOS installer the user can pick as the source for the USB drive.
//

import Foundation
import UniformTypeIdentifiers

struct InstallerSource: Identifiable, Hashable {

    /// The three kinds of source files the app accepts.
    enum Kind: Hashable {
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
    /// Version number, e.g. "26.0".
    let version: String
    let kind: Kind
    /// Size in bytes.
    let size: Int64

    var id: URL { url }

    /// Size formatted for people, e.g. "16.8 GB".
    var formattedSize: String {
        size.formatted(.byteCount(style: .file))
    }
}

// MARK: - Sample data

extension InstallerSource {
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
}
