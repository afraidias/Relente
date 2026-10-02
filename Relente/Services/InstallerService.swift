//
//  InstallerService.swift
//  Relente
//
//  Finds the macOS installers on the Mac and reads the ones the user chooses. The live service
//  watches /Applications; the sample one serves fixed data for previews, tests and `-sampleData`.
//  Spec: specs/007-real-detection/spec.md
//

import Foundation

nonisolated protocol InstallerService: Sendable {
    /// The full list every time it changes: installers found in /Applications plus the ones
    /// the user chose that are still on disk. The first value comes as soon as it's known.
    func updates() -> AsyncStream<[InstallerSource]>

    /// Reads an installer the user chose (an app, a disk image or an InstallAssistant.pkg) and
    /// keeps it in the list while its file exists.
    func add(_ url: URL) async throws(InstallerError) -> InstallerSource
}

/// Why a file can't be used as an installer.
nonisolated enum InstallerError: Error, Hashable, Sendable {
    /// It isn't a macOS installer, a disk image with one inside, or InstallAssistant.pkg.
    case notAnInstaller(fileName: String)

    /// The alert's title.
    var title: LocalizedStringResource {
        switch self {
        case .notAnInstaller(let fileName):
            LocalizedStringResource(
                "“\(fileName)” Isn't a macOS Installer",
                comment: "Alert title when the chosen file isn't an installer. The value is the file's name.")
        }
    }

    /// The alert's message.
    var message: LocalizedStringResource {
        switch self {
        case .notAnInstaller:
            LocalizedStringResource(
                "Choose an installer app, a disk image that contains one, or InstallAssistant.pkg.",
                comment: "Alert message when the chosen file isn't an installer.")
        }
    }
}
