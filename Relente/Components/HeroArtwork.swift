//
//  HeroArtwork.swift
//  Relente
//
//  The big illustration at the center of a screen, such as the chosen drive,
//  on a soft halo, with a small badge on its bottom-trailing corner
//  (the installer's icon, a checkmark, an error…).
//

import SwiftUI

struct HeroArtwork<Artwork: View, Badge: View>: View {
    /// Side of the square the illustration fits in.
    let size: CGFloat
    /// Color of the halo behind the illustration.
    let haloColor: Color
    let artwork: Artwork
    let badge: Badge

    init(
        size: CGFloat = 112,
        haloColor: Color = Theme.Colors.accent,
        @ViewBuilder artwork: () -> Artwork,
        @ViewBuilder badge: () -> Badge = { EmptyView() }
    ) {
        self.size = size
        self.haloColor = haloColor
        self.artwork = artwork()
        self.badge = badge()
    }

    var body: some View {
        artwork
            .frame(width: size, height: size)
            .background {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [haloColor.opacity(0.28), haloColor.opacity(0)],
                            center: .center,
                            startRadius: 0,
                            endRadius: size * 0.75
                        )
                    )
                    .frame(width: size * 1.5, height: size * 1.5)
            }
            .overlay(alignment: .bottomTrailing) {
                badge
                    .frame(width: size * 0.42, height: size * 0.42)
                    .offset(x: size * 0.08, y: size * 0.04)
            }
            .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: 48) {
        HeroArtwork {
            DriveArtwork(kind: .usbDrive)
        } badge: {
            FileIcon(url: InstallerSource.samples[0].url, fallbackType: InstallerSource.samples[0].kind.contentType)
        }

        HeroArtwork(haloColor: Theme.Colors.success) {
            DriveArtwork(kind: .sdCard)
        } badge: {
            Image(systemName: "checkmark.circle.fill")
                .resizable()
                .foregroundStyle(.white, Theme.Colors.success)
        }
    }
    .padding(48)
}
