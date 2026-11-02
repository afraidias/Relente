//
//  IncompleteInstaller.swift
//  Relente
//
//  An Apple installer app in /Applications that lacks required acquisition files.
//  Spec: specs/011-installer-acquisition/spec.md
//

import Foundation

nonisolated struct IncompleteInstaller: Hashable, Identifiable, Sendable {
    let url: URL
    let name: String
    let version: MacOSVersion
    let sizeInBytes: Int64
    let snapshot: String

    var id: URL { url }

    var fileName: String { url.lastPathComponent }
}

nonisolated enum IncompleteInstallerError: Error, Hashable, Sendable {
    case downloadActive
    case changed
    case moveFailed

    var message: LocalizedStringResource {
        switch self {
        case .downloadActive:
            LocalizedStringResource(
                "Wait for the active download to finish before moving an installer to the Trash.",
                comment: "Download recovery error when cleanup is attempted during an active Relente download.")
        case .changed:
            LocalizedStringResource(
                "This installer changed. Refresh the list before trying again.",
                comment: "Download recovery error when the selected incomplete app changed before cleanup.")
        case .moveFailed:
            LocalizedStringResource(
                "Relente couldn’t move this installer to the Trash.",
                comment: "Download recovery error when moving an incomplete installer app to the Trash fails.")
        }
    }
}
