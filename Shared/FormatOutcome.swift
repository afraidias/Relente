//
//  FormatOutcome.swift
//  Relente
//
//  How a format request ended, as the helper replies over XPC (a plain integer).
//  Spec: specs/008-system-helper/spec.md
//

import Foundation

nonisolated enum FormatOutcome: Int, CaseIterable, Hashable, Sendable {
    /// The drive was erased.
    case formatted = 0
    /// The authorization is missing or doesn't grant the erase right (helper rule 5).
    case notAuthorized = 1
    /// The identifier isn't a whole disk's (`^disk[0-9]+$`).
    case invalidIdentifier = 2
    /// The disk isn't a USB drive or SD card Relente may erase (helper rule 3).
    case driveNotAllowed = 3
    /// The disk isn't the one the user confirmed: its fingerprint differs.
    case driveChanged = 4
    /// The disk is no longer connected.
    case driveDisconnected = 5
    /// `diskutil` failed or was stopped.
    case formatFailed = 6
    /// Another format is running.
    case busy = 7
}
