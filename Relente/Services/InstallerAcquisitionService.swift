//
//  InstallerAcquisitionService.swift
//  Relente
//
//  Lists and downloads full macOS installers without involving the privileged helper.
//  Design: intent/direct-installer-download/spec.md
//

import Foundation

nonisolated protocol InstallerAcquisitionService: Sendable {
    func availableInstallers() async throws(InstallerAcquisitionError) -> [AvailableInstaller]
    func download(_ installer: AvailableInstaller) async -> AsyncStream<InstallerAcquisitionEvent>
    func cancelDownload() async
}

nonisolated enum InstallerAcquisitionError: Error, Hashable, Sendable {
    case catalogUnavailable
    case downloadFailed
    case alreadyDownloading
    case verificationFailed
    case preparationFailed
    case recoveryRequired

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
        case .verificationFailed:
            LocalizedStringResource(
                "The downloaded package couldn’t be verified as Apple software.",
                comment: "Acquisition package authenticity failure.")
        case .preparationFailed:
            LocalizedStringResource(
                "The installer couldn’t be prepared safely. Your local installers are still available.",
                comment: "Acquisition preparation failure.")
        case .recoveryRequired:
            LocalizedStringResource(
                "Relente couldn’t confirm safe cleanup. The incomplete work is isolated; a new download is blocked.",
                comment: "Acquisition unresolved process or cleanup failure.")
        case .alreadyDownloading:
            LocalizedStringResource(
                "A download is already in progress.",
                comment: "Download screen error when another installer download is already active.")
        }
    }
}

nonisolated enum InstallerAcquisitionEvent: Hashable, Sendable {
    case transfer(InstallerTransferProgress)
    case stage(InstallerAcquisitionStage)
    case progress(Double?)
    case completed(InstallerSource)
    case failed(InstallerAcquisitionError)
    case blocked(InstallerAcquisitionPolicy.Reason)
    case cancelled
}

nonisolated struct InstallerTransferProgress: Hashable, Sendable {
    let bytes: Int64
    let total: Int64?
    let bytesPerSecond: Double?
}
