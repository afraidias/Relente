//
//  InstallerReader.swift
//  Relente
//
//  Reads an installer's name, version and size from its files: an `Install macOS *.app`, a disk
//  image that contains one, or an InstallAssistant.pkg. It only reads: disk images are attached
//  read-only and hidden, and always detached again; packages are never installed or expanded,
//  only their Distribution file is extracted to a temporary folder. External tools run with
//  fixed paths and argument arrays, never through a shell.
//  Spec: specs/007-real-detection/spec.md
//

import Foundation
import os

nonisolated enum InstallerReader {

    /// The file isn't a macOS installer, or it couldn't be read.
    struct ReadError: Error {
        let reason: String
    }

    private static let logger = Logger(subsystem: "com.afraidias.Relente", category: "installer")

    /// Reads any of the three kinds, by its extension.
    @concurrent
    static func read(_ url: URL) async throws -> InstallerSource {
        switch url.pathExtension.lowercased() {
        case "app": try await readApp(at: url)
        case "dmg": try await readDiskImage(at: url)
        case "pkg": try await readPackage(at: url)
        default: throw ReadError(reason: "Unknown kind of file")
        }
    }

    // MARK: - Installer app

    /// An `Install macOS *.app`. Its full version is in the software update catalog inside
    /// `Contents/SharedSupport/SharedSupport.dmg` (Big Sur and later); when that can't be read,
    /// the version its own version number points to is used.
    @concurrent
    static func readApp(at url: URL, as source: URL? = nil, kind: InstallerSource.Kind = .app) async throws
        -> InstallerSource
    {
        let info = try InstallerMetadata.appInfo(
            fromInfoPlist: Data(contentsOf: url.appending(path: "Contents/Info.plist")))
        var version = info.version
        if version >= .bigSur {
            let sharedSupport = url.appending(path: "Contents/SharedSupport/SharedSupport.dmg")
            do {
                version = try await withAttachedImage(sharedSupport) { mountPoint in
                    try InstallerMetadata.version(
                        fromCatalog: Data(contentsOf: mountPoint.appending(path: InstallerMetadata.catalogPath)))
                }
            } catch {
                logger.error(
                    "No full version for \(url.lastPathComponent, privacy: .public): \(String(describing: error), privacy: .public)"
                )
            }
        }
        return InstallerSource(
            url: source ?? url, name: info.name, version: version, kind: kind, size: allocatedSize(of: url))
    }

    // MARK: - Disk image

    /// A `.dmg` with an installer app at its root.
    @concurrent
    static func readDiskImage(at url: URL) async throws -> InstallerSource {
        try await withAttachedImage(url) { mountPoint in
            let items = try FileManager.default.contentsOfDirectory(
                at: mountPoint, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            guard
                let app = items.first(where: { $0.pathExtension == "app" && $0.lastPathComponent.hasPrefix("Install ") }
                )
            else { throw ReadError(reason: "No installer app in the disk image") }
            return try await readApp(at: app, as: url, kind: .diskImage)
        }
    }

    // MARK: - Package

    /// An InstallAssistant.pkg: only its Distribution file is extracted, with `xar`.
    @concurrent
    static func readPackage(at url: URL) async throws -> InstallerSource {
        let folder = FileManager.default.temporaryDirectory.appending(path: "Relente-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        _ = try run(
            "/usr/bin/xar",
            ["-xf", url.path(percentEncoded: false), "-C", folder.path(percentEncoded: false), "Distribution"])
        let info = try InstallerMetadata.packageInfo(
            fromDistribution: Data(contentsOf: folder.appending(path: "Distribution")))
        return InstallerSource(
            url: url, name: InstallerMetadata.name(for: info.version), version: info.version, kind: .package,
            size: info.installedSize)
    }

    // MARK: - Disk images

    /// Runs `body` with the image mounted read-only and hidden, then detaches it, also when
    /// `body` fails. An image that's already mounted is used where it is and left mounted.
    static func withAttachedImage<T>(_ image: URL, _ body: (URL) async throws -> T) async throws -> T {
        if let mountPoint = try mountPoint(ofAttached: image) {
            return try await body(mountPoint)
        }
        let output = try run(
            "/usr/bin/hdiutil",
            [
                "attach", "-readonly", "-nobrowse", "-noverify", "-noautoopen", "-plist",
                image.path(percentEncoded: false),
            ])
        guard let plist = try PropertyListSerialization.propertyList(from: output, format: nil) as? [String: Any],
            let entities = plist["system-entities"] as? [[String: Any]]
        else { throw ReadError(reason: "hdiutil attach gave no entities") }
        let device = entities.compactMap { $0["dev-entry"] as? String }.min { $0.count < $1.count }
        defer {
            if let device {
                _ = try? run("/usr/bin/hdiutil", ["detach", device])
            }
        }
        guard let mountPoint = entities.lazy.compactMap({ $0["mount-point"] as? String }).first else {
            throw ReadError(reason: "The disk image has no volume")
        }
        return try await body(URL(filePath: mountPoint, directoryHint: .isDirectory))
    }

    /// Where an image is mounted if it already is, from `hdiutil info`.
    private static func mountPoint(ofAttached image: URL) throws -> URL? {
        let output = try run("/usr/bin/hdiutil", ["info", "-plist"])
        guard let plist = try PropertyListSerialization.propertyList(from: output, format: nil) as? [String: Any],
            let images = plist["images"] as? [[String: Any]]
        else { return nil }
        let path = image.resolvingSymlinksInPath().path(percentEncoded: false)
        guard let attached = images.first(where: { ($0["image-path"] as? String) == path }),
            let entities = attached["system-entities"] as? [[String: Any]],
            let mountPoint = entities.lazy.compactMap({ $0["mount-point"] as? String }).first
        else { return nil }
        return URL(filePath: mountPoint, directoryHint: .isDirectory)
    }

    // MARK: - Helpers

    /// Runs a tool at a fixed path with an argument array and returns what it printed.
    private static func run(_ executable: String, _ arguments: [String]) throws -> Data {
        let process = Process()
        process.executableURL = URL(filePath: executable)
        process.arguments = arguments
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw ReadError(reason: "\(executable) \(arguments.first ?? "") ended with \(process.terminationStatus)")
        }
        return data
    }

    /// The space a bundle takes on disk.
    private static func allocatedSize(of url: URL) -> Int64 {
        let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .isRegularFileKey]
        guard let files = FileManager.default.enumerator(at: url, includingPropertiesForKeys: Array(keys)) else {
            return 0
        }
        var total: Int64 = 0
        for case let file as URL in files {
            guard let values = try? file.resourceValues(forKeys: keys), values.isRegularFile == true else { continue }
            total += Int64(values.totalFileAllocatedSize ?? 0)
        }
        return total
    }
}
