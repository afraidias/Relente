//
//  AvailableInstallerArtwork.swift
//  Relente
//
//  Artwork shared by the Apple installer picker and its download details sheet.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct AvailableInstallerArtwork: View {
    let installer: AvailableInstaller
    let match: AvailableInstaller.LocalMatch
    let side: CGFloat
    var preloadedIcon: NSImage? = nil
    @State private var localAppIcon: NSImage?

    var body: some View {
        Group {
            if localAppURL != nil {
                if let localAppIcon = preloadedIcon ?? localAppIcon {
                    Image(nsImage: localAppIcon)
                        .resizable()
                        .scaledToFit()
                } else {
                    Color.clear
                }
            } else {
                versionArtwork
            }
        }
        .frame(width: side, height: side)
        .task(id: localAppURL) {
            localAppIcon = nil
            guard preloadedIcon == nil, let localAppURL else { return }
            await Task.yield()
            localAppIcon = FileIcon.loadIcon(url: localAppURL, fallbackType: .applicationBundle)
        }
        .accessibilityHidden(true)
    }

    private var localAppURL: URL? {
        guard case .unique(let source) = match, source.kind == .app else { return nil }
        return source.url
    }

    private var versionArtwork: some View {
        VStack(spacing: -3) {
            Text("macOS")
                .font(.system(size: side * 0.125, weight: .medium, design: .rounded))
            Text(verbatim: String(installer.version.major))
                .font(.system(size: side * 0.35, weight: .medium, design: .rounded).monospacedDigit())
        }
        .frame(width: side, height: side)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: side * 0.18))
        .overlay {
            RoundedRectangle(cornerRadius: side * 0.18)
                .strokeBorder(.quaternary, lineWidth: 1)
        }
    }
}

#Preview {
    AvailableInstallerArtwork(
        installer: AvailableInstaller(title: "macOS Tahoe", version: "26.1", build: "25B354"),
        match: .none,
        side: 112
    )
    .padding()
}
