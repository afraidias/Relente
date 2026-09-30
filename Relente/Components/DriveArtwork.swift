//
//  DriveArtwork.swift
//  Relente
//
//  Large illustration of a USB drive or SD card. It uses SF Symbols, which
//  exist on every supported macOS version and adapt to light and dark mode.
//

import SwiftUI

struct DriveArtwork: View {
    let kind: Drive.Kind

    private var systemImage: String {
        switch kind {
        case .usbDrive: "externaldrive.fill"
        case .sdCard: "sdcard.fill"
        }
    }

    var body: some View {
        Image(systemName: systemImage)
            .resizable()
            .scaledToFit()
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.secondary)
            .padding(14)
            .accessibilityHidden(true)
    }
}

#Preview {
    HStack {
        DriveArtwork(kind: .usbDrive)
        DriveArtwork(kind: .sdCard)
    }
    .frame(width: 240, height: 110)
    .padding()
}
