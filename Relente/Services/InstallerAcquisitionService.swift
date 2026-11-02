//
//  InstallerAcquisitionService.swift
//  Relente
//
//  Lists and downloads full macOS installers without involving the privileged helper.
//  Spec: specs/011-installer-acquisition/spec.md
//

import Foundation

nonisolated protocol InstallerAcquisitionService: Sendable {
    func availableInstallers() async throws(InstallerAcquisitionError) -> [AvailableInstaller]
    func incompleteInstallers() async -> [IncompleteInstaller]
    func moveToTrash(_ installer: IncompleteInstaller) async throws(IncompleteInstallerError)
    func download(_ installer: AvailableInstaller) async -> AsyncStream<InstallerAcquisitionEvent>
    func cancelDownload() async
}

nonisolated enum InstallerAcquisitionError: Error, Hashable, Sendable {
    case catalogUnavailable
    case downloadFailed
    case alreadyDownloading

    var message: LocalizedStringResource {
        switch self {
        case .catalogUnavailable:
            LocalizedStringResource(
                "Apple’s installer list couldn’t be loaded.",
                comment: "Download screen error when the list of full installers cannot be loaded.")
        case .downloadFailed:
            LocalizedStringResource(
                "The installer download failed.",
                comment: "Download screen error when downloading a macOS installer fails.")
        case .alreadyDownloading:
            LocalizedStringResource(
                "A download is already in progress.",
                comment: "Download screen error when another installer download is already active.")
        }
    }
}

nonisolated enum InstallerAcquisitionEvent: Hashable, Sendable {
    case output(CreationOutputLine)
    case progress(Double?)
    case completed(InstallerSource)
    case failed(InstallerAcquisitionError)
    case blocked(InstallerAcquisitionPolicy.Reason)
    case cancelled
}
