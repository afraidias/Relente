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
            await Task.yield()
            icon = Self.loadIcon(url: url, fallbackType: fallbackType)
        }
        .accessibilityHidden(true)
    }

    static func loadIcon(url: URL, fallbackType: UTType) -> NSImage {
        if FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
            if url.pathExtension == "app", let icon = applicationBundleIcon(at: url) {
                return icon
            }
            return NSWorkspace.shared.icon(forFile: url.path(percentEncoded: false))
        }
        return NSWorkspace.shared.icon(for: fallbackType)
    }

    private static func applicationBundleIcon(at url: URL) -> NSImage? {
        let infoURL = url.appending(path: "Contents/Info.plist")
        guard let data = try? Data(contentsOf: infoURL),
            let info = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
            let iconName = info["CFBundleIconFile"] as? String
        else { return nil }

        let resources = url.appending(path: "Contents/Resources", directoryHint: .isDirectory)
        let iconURL = resources.appending(path: iconName)
        let namedURL = iconURL.pathExtension.isEmpty ? iconURL.appendingPathExtension("icns") : iconURL
        return NSImage(contentsOf: namedURL)
    }
}

#Preview {
    HStack {
        FileIcon(
            url: URL(filePath: "/System/Applications/Utilities/Disk Utility.app"), fallbackType: .applicationBundle)
        FileIcon(url: URL(filePath: "/missing.dmg"), fallbackType: .diskImage)
    }
    .frame(width: 240, height: 96)
    .padding()
}
