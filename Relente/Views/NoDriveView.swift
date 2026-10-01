//
//  NoDriveView.swift
//  Relente
//
//  Step 2b: no USB drive or SD card is connected yet. Shown under the screen's header and the
//  installer label; it switches to the drives by itself when one is plugged in.
//  Specs: specs/002-drive-screen/spec.md, specs/007-real-detection/spec.md
//

import SwiftUI

struct NoDriveView: View {
    /// Minimum drive size for the chosen installer, in bytes.
    let requiredCapacity: Int64

    var body: some View {
        EmptyStateView(
            title: LocalizedStringResource(
                "No USB Drive Connected", comment: "Empty state title on the USB Drive screen."),
            systemImage: "externaldrive.badge.plus",
            description: Text(
                "Use a USB drive or SD card with at least \(Self.size(requiredCapacity)). \(Self.size(Drive.recommendedCapacity)) or more works for any version of macOS.",
                comment:
                    "Empty state when no drive is connected. First value: minimum size for the chosen installer (e.g. 17.8 GB); second: size that works for any installer (32 GB)."
            ),
            waitingText: LocalizedStringResource(
                "Waiting for a drive…", comment: "Shown while no USB drive or SD card is connected.")
        )
    }

    /// A size such as "32 GB" that never breaks between the number and the unit.
    private static func size(_ bytes: Int64) -> String {
        bytes.formatted(.byteCount(style: .file)).replacingOccurrences(of: " ", with: "\u{00A0}")
    }
}

#Preview {
    NoDriveView(requiredCapacity: 17_800_000_000)
        .frame(width: 800, height: 400)
}
