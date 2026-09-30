//
//  NoDriveView.swift
//  Relente
//
//  Step 2b: no USB drive or SD card is connected yet.
//  Spec: specs/002-drive-screen/spec.md
//

import SwiftUI

struct NoDriveView: View {
    /// Minimum drive size for the chosen installer, in bytes.
    let requiredCapacity: Int64

    var body: some View {
        ContentUnavailableView {
            Label("Connect a USB Drive", systemImage: "externaldrive.badge.plus")
        } description: {
            Text(
                "Use a USB drive or SD card with at least \(requiredCapacity.formatted(.byteCount(style: .file))). \(Drive.recommendedCapacity.formatted(.byteCount(style: .file))) or more works for any version of macOS.",
                comment:
                    "Empty state when no drive is connected. First value: minimum size for the chosen installer (e.g. 17.8 GB); second: size that works for any installer (32 GB)."
            )
        } actions: {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Waiting for a drive…", comment: "Shown while no USB drive or SD card is connected.")
            }
            .foregroundStyle(Theme.Colors.secondary)
        }
    }
}

#Preview {
    NoDriveView(requiredCapacity: 17_800_000_000)
        .frame(width: 800, height: 480)
}
