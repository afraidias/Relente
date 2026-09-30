//
//  CreationFailure.swift
//  Relente
//
//  Why making the bootable installer stopped, and where: shown on the Error screen.
//  Spec: specs/004-creating-screen/spec.md
//

import Foundation

nonisolated struct CreationFailure: Hashable, Sendable {

    /// Why it stopped. Real failures are mapped to these in roadmap step 7.
    enum Reason: CaseIterable, Hashable, Sendable {
        case driveDisconnected
        case cancelled
        case installerDamaged
        case verificationFailed
        case unknown

        /// What happened, the first sentence of the Error screen's subtitle.
        var title: LocalizedStringResource {
            switch self {
            case .driveDisconnected:
                LocalizedStringResource(
                    "The drive was disconnected.", comment: "Error screen: the drive was unplugged while creating.")
            case .cancelled:
                LocalizedStringResource(
                    "You stopped the process.", comment: "Error screen: the user cancelled the creation.")
            case .installerDamaged:
                LocalizedStringResource(
                    "The installer couldn't be verified.",
                    comment: "Error screen: the macOS installer failed its signature check.")
            case .verificationFailed:
                LocalizedStringResource(
                    "The drive didn't pass the final check.",
                    comment: "Error screen: the finished drive failed Relente's verification.")
            case .unknown:
                LocalizedStringResource(
                    "Something went wrong while creating the installer.",
                    comment: "Error screen: a failure with no known cause.")
            }
        }

        /// What the user can do about it, after the reason in the subtitle.
        var recovery: LocalizedStringResource {
            switch self {
            case .driveDisconnected:
                LocalizedStringResource(
                    "Plug it in again and try again.",
                    comment: "Error screen: what to do after the drive was unplugged."
                )
            case .cancelled:
                LocalizedStringResource(
                    "Try again to erase the drive and start over.",
                    comment: "Error screen: what to do after cancelling.")
            case .installerDamaged:
                LocalizedStringResource(
                    "Download the installer again, then try again.",
                    comment: "Error screen: what to do when the installer is damaged.")
            case .verificationFailed:
                LocalizedStringResource(
                    "Try again, or use a different drive.",
                    comment: "Error screen: what to do when the finished drive failed the check.")
            case .unknown:
                LocalizedStringResource(
                    "Try again. If it keeps happening, use a different drive.",
                    comment: "Error screen: what to do after an unknown failure.")
            }
        }
    }

    let reason: Reason
    /// The process as it was when it stopped.
    let progress: CreationProgress

    /// STOPPED AT: the overall percentage when it stopped.
    var stoppedPercent: Int {
        progress.percent
    }
}

// MARK: - Sample data

/// Fake failures for the Error screen's previews, before the real process exists.
nonisolated extension CreationFailure {
    /// The drive was unplugged halfway through Copy.
    static let sampleDriveDisconnected = CreationFailure(reason: .driveDisconnected, progress: .sampleMidCopy)

    /// The user pressed Cancel and Stop right after Copy started.
    static let sampleCancelled = CreationFailure(reason: .cancelled, progress: .sampleEarlyCopy)
}
