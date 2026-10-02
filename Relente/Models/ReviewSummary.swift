//
//  ReviewSummary.swift
//  Relente
//
//  The figures shown on the Review screen: what will be erased, what will be
//  installed and what will be left free on the drive.
//  Spec: specs/003-review-screen/spec.md
//

import Foundation

nonisolated struct ReviewSummary: Hashable, Sendable {
    /// What is stored on the drive. All of it will be erased.
    let erased: UsedSpace
    /// Size of the installer that will be copied, in bytes.
    let installedBytes: Int64
    /// Estimated free space left on the drive afterwards, in bytes. Never negative.
    let freeAfterwardsBytes: Int64
    /// Share of the drive the installer will take, from 0 to 1.
    let installedFraction: Double

    init(installer: InstallerSource, drive: Drive) {
        erased = drive.usedSpace
        erasesNothing = drive.isEmpty
        installedBytes = installer.size
        freeAfterwardsBytes = max(drive.capacity - installer.size, 0)
        installedFraction =
            drive.capacity > 0
            ? min(max(Double(installer.size) / Double(drive.capacity), 0), 1)
            : 1
    }

    /// Whether the drive is empty, so nothing but its format will be lost.
    let erasesNothing: Bool
}
