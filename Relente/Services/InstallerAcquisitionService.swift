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
    case downloadInterrupted
    case downloadResponseRejected
    case downloadSizeUnexpected
    case downloadRedirectBlocked
    case alreadyDownloading
    case verificationFailed
    case preparationFailed
    case recoveryRequired

    static func downloadFailure(for failure: InstallerDownload.Failure) -> Self {
        switch failure {
        case .networkInterrupted: .downloadInterrupted
        case .unexpectedResponse: .downloadResponseRejected
        case .sizeMismatch: .downloadSizeUnexpected
        case .unsafeRedirect: .downloadRedirectBlocked
        default: .downloadFailed
        }
    }

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
        case .downloadInterrupted:
            LocalizedStringResource(
                "The network connection was interrupted. Check your connection and try again.",
                comment: "Safe explanation for an interrupted installer download.")
        case .downloadResponseRejected:
            LocalizedStringResource(
                "Apple’s server couldn’t provide the installer. Try again later.",
                comment: "Safe explanation for a rejected installer response.")
        case .downloadSizeUnexpected:
            LocalizedStringResource(
                "The installer download was incomplete or had an unexpected size. Try again.",
                comment: "Safe explanation for installer size mismatch.")
        case .downloadRedirectBlocked:
            LocalizedStringResource(
                "The installer download was redirected to an untrusted destination. Try again later.",
                comment: "Safe explanation for a blocked installer redirect.")
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
