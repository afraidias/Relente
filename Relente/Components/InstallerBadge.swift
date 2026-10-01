//
//  InstallerBadge.swift
//  Relente
//
//  The installer's real icon, as the badge on the drive, with a green checkmark on its corner
//  once the installer is made (Done).
//

import SwiftUI

struct InstallerBadge: View {
    let installer: InstallerSource
    var isChecked = false

    var body: some View {
        FileIcon(url: installer.url, fallbackType: installer.kind.contentType)
            .overlay(alignment: .topTrailing) {
                Image(systemName: "checkmark.circle.fill")
                    .resizable()
                    .foregroundStyle(.white, Theme.Colors.success)
                    .frame(width: 18, height: 18)
                    .offset(x: 6, y: -6)
                    .opacity(isChecked ? 1 : 0)
            }
            .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: 32) {
        InstallerBadge(installer: InstallerSource.samples[0])
        InstallerBadge(installer: InstallerSource.samples[0], isChecked: true)
    }
    .frame(height: 44)
    .padding()
}
