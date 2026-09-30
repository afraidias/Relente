//
//  FileIcon.swift
//  Relente
//
//  The Finder icon of a file. It is read from disk once, when the view
//  appears (or the URL changes), not on every redraw.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct FileIcon: View {
    let url: URL
    /// Type used for a generic icon when the file doesn't exist.
    let fallbackType: UTType

    @State private var icon: NSImage?

    var body: some View {
        ZStack {
            if let icon {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
            }
        }
        .task(id: url) {
            icon = Self.loadIcon(url: url, fallbackType: fallbackType)
        }
        .accessibilityHidden(true)
    }

    private static func loadIcon(url: URL, fallbackType: UTType) -> NSImage {
        if FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
            NSWorkspace.shared.icon(forFile: url.path(percentEncoded: false))
        } else {
            NSWorkspace.shared.icon(for: fallbackType)
        }
    }
}

#Preview {
    HStack {
        FileIcon(url: URL(filePath: "/System/Applications/Utilities/Disk Utility.app"), fallbackType: .applicationBundle)
        FileIcon(url: URL(filePath: "/missing.dmg"), fallbackType: .diskImage)
    }
    .frame(width: 240, height: 96)
    .padding()
}
