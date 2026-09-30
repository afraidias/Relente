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
    /// Space in use on the drive, in bytes. All of it will be erased.
    let erasedBytes: Int64
    /// Size of the installer that will be copied, in bytes.
    let installedBytes: Int64
    /// Estimated free space left on the drive afterwards, in bytes. Never negative.
    let freeAfterwardsBytes: Int64
    /// Share of the drive the installer will take, from 0 to 1.
    let installedFraction: Double

    init(installer: InstallerSource, drive: Drive) {
        erasedBytes = drive.usedBytes
        installedBytes = installer.size
        freeAfterwardsBytes = max(drive.capacity - installer.size, 0)
        installedFraction =
            drive.capacity > 0
            ? min(max(Double(installer.size) / Double(drive.capacity), 0), 1)
            : 1
    }

    /// Whether the drive has nothing on it, so nothing but the format will be lost.
    var erasesNothing: Bool {
        erasedBytes == 0
    }
}
