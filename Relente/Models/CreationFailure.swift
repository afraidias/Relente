//
//  CreationFailure.swift
//  Relente
//
//  Why making the bootable installer stopped, and where: shown on the Error screen.
//  Spec: specs/004-creating-screen/spec.md, specs/008-system-helper/spec.md
//

import Foundation

nonisolated struct CreationFailure: Hashable, Sendable {

    /// Why it stopped. Real failures are mapped to these in roadmap step 7.
    enum Reason: CaseIterable, Hashable, Sendable {
        case driveDisconnected
        case cancelled
        case installerDamaged
        case verificationFailed
        /// The drive isn't the one the user confirmed (the helper's fingerprint check).
        case driveChanged
        /// The helper refused the drive: it isn't a USB drive or SD card it may erase.
        case driveNotAllowed
        /// `diskutil` couldn't erase the drive.
        case formatFailed
        /// `createinstallmedia` failed after accepting the installer and volume.
        case createFailed
        /// Apple reported that writing the installer media was not permitted.
        case volumeAccessDenied
        /// The helper didn't answer, or is an older one.
        case helperUnavailable
        case unknown

        /// Whether "Try Again" goes back to USB Drive, to pick the drive again, instead of Review:
        /// after a disconnection or when the drive isn't the one confirmed (spec 007 Decision 13).
        var sendsBackToDriveScreen: Bool {
            switch self {
            case .driveDisconnected, .driveChanged, .driveNotAllowed: true
            case .cancelled, .installerDamaged, .verificationFailed, .formatFailed, .createFailed, .volumeAccessDenied,
                .helperUnavailable,
                .unknown:
                false
            }
        }

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
            case .driveChanged:
                LocalizedStringResource(
                    "The drive changed after you confirmed it.",
                    comment: "Error screen: the drive about to be erased isn't the one confirmed on Review.")
            case .driveNotAllowed:
                LocalizedStringResource(
                    "Relente can only erase USB drives and SD cards.",
                    comment: "Error screen: the helper refused the drive.")
            case .formatFailed:
                LocalizedStringResource(
                    "The drive couldn't be erased.", comment: "Error screen: diskutil failed to erase the drive.")
            case .createFailed:
                LocalizedStringResource(
                    "The bootable installer couldn't be created.",
                    comment: "Error screen: createinstallmedia failed while creating the installer on the drive.")
            case .volumeAccessDenied:
                LocalizedStringResource(
                    "macOS prevented writing to the drive.",
                    comment: "Error screen: Apple's tool reported a permission error writing installer media.")
            case .helperUnavailable:
                LocalizedStringResource(
                    "The system helper didn't respond.", comment: "Error screen: the helper didn't answer.")
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
            case .driveChanged:
                LocalizedStringResource(
                    "Check it's the right drive and choose it again.",
                    comment: "Error screen: what to do when the drive changed after confirming it.")
            case .driveNotAllowed:
                LocalizedStringResource(
                    "Use a different drive.", comment: "Error screen: what to do when the helper refused the drive.")
            case .formatFailed, .createFailed:
                LocalizedStringResource(
                    "Try again, or use a different drive.",
                    comment: "Error screen: what to do when the drive couldn't be erased.")
            case .volumeAccessDenied:
                LocalizedStringResource(
                    "Enable Full Disk Access for Relente in Privacy & Security, then try again. The drive may have been erased.",
                    comment: "Error screen: recovery after Apple's tool fails to write to installer media.")
            case .helperUnavailable:
                LocalizedStringResource(
                    "Try again. If it keeps happening, quit and open Relente again.",
                    comment: "Error screen: what to do when the helper didn't respond.")
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
