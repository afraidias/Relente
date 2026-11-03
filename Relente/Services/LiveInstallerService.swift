//
//  LiveInstallerService.swift
//  Relente
//
//  Finds the installers in /Applications and keeps the ones the user chose. The folder is
//  listed every two seconds (macOS's folder notifications need a dispatch queue, which the
//  project doesn't use); only installers that are new or changed are read again.
//

import Foundation
import os

actor LiveInstallerService: InstallerService {

    /// What a file looked like when it was read, to read it again only if it changed.
    private struct Stamp: Hashable {
        let modified: Date?
        let size: Int?
        let packageModified: Date?
        let packageSize: Int?
    }

    private static let applications = URL(filePath: "/Applications", directoryHint: .isDirectory)
    private let logger = Logger(subsystem: "com.afraidias.Relente", category: "installer")

    private var cache: [URL: (stamp: Stamp, installer: InstallerSource?)] = [:]
    private var chosen: [URL] = []
    private var retained: [URL: InstallerSource] = [:]
    private var installers: [InstallerSource]?
    private var listeners: [UUID: AsyncStream<[InstallerSource]>.Continuation] = [:]
    private var watching: Task<Void, Never>?

    // MARK: - InstallerService

    nonisolated func updates() -> AsyncStream<[InstallerSource]> {
        let (stream, continuation) = AsyncStream.makeStream(
            of: [InstallerSource].self, bufferingPolicy: .bufferingNewest(1))
        Task { await self.addListener(continuation) }
        return stream
    }

    func add(_ url: URL) async throws(InstallerError) -> InstallerSource {
        let url = url.standardizedFileURL
        guard let installer = await installer(at: url) else {
            throw .notAnInstaller(fileName: url.lastPathComponent)
        }
        if !chosen.contains(url) {
            chosen.append(url)
        }
        await scan()
        return installer
    }

    func addRetained(_ source: InstallerSource) async throws(InstallerError) -> InstallerSource {
        guard source.packageURL != nil, source.build != nil else { throw .notAnInstaller(fileName: source.name) }
        retained[source.url] = source
        cache[source.url] = nil
        do { return try await add(source.url) } catch {
            retained[source.url] = nil
            throw error
        }
    }

    // MARK: - Watching

    private func addListener(_ continuation: AsyncStream<[InstallerSource]>.Continuation) {
        let id = UUID()
        listeners[id] = continuation
        continuation.onTermination = { _ in Task { await self.removeListener(id) } }
        if let installers { continuation.yield(installers) }
        guard watching == nil else { return }
        watching = Task {
            while !Task.isCancelled {
                await scan()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    private func removeListener(_ id: UUID) {
        listeners[id] = nil
    }

    /// Lists /Applications and the chosen files, reads what changed and tells the listeners.
    private func scan() async {
        let found =
            (try? FileManager.default.contentsOfDirectory(
                at: Self.applications, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)) ?? []
        let candidates = found.filter { $0.pathExtension == "app" && $0.lastPathComponent.hasPrefix("Install ") }
        chosen.removeAll { !FileManager.default.fileExists(atPath: $0.path(percentEncoded: false)) }

        var list: [InstallerSource] = []
        for url in candidates.map(\.standardizedFileURL) + chosen {
            if let installer = await installer(at: url), !list.contains(where: { $0.id == installer.id }) {
                list.append(installer)
            }
        }
        cache = cache.filter { url, _ in list.contains { $0.url == url } || candidates.contains(url) }

        guard list != installers else { return }
        logger.info("Installers: \(list.map(\.url.lastPathComponent).joined(separator: ", "), privacy: .public)")
        installers = list
        for listener in listeners.values {
            listener.yield(list)
        }
    }

    /// The installer at `url`, read again only if the file changed since the last time.
    /// `nil` if it isn't one, or can't be read yet (e.g. still downloading).
    private func installer(at url: URL) async -> InstallerSource? {
        let expected = retained[url]
        let stamp = Self.stamp(of: url, package: expected?.packageURL)
        if let cached = cache[url], cached.stamp == stamp { return cached.installer }
        let installer: InstallerSource?
        do {
            let read = try await InstallerReader.read(url)
            if let expected, let package = expected.packageURL {
                let output = try await InstallerCommand.verifyPackage(package).run(
                    in: package.deletingLastPathComponent(), timeout: 60)
                guard let text = String(data: output, encoding: .utf8),
                    AppleInstallerPackageSignature.acceptsSuccessfulCheck(text),
                    read.version == expected.version, read.build == expected.build
                else {
                    throw InstallerReader.ReadError(reason: "Retained package identity changed")
                }
                installer = InstallerSource(
                    url: read.url, name: read.name, version: read.version,
                    kind: read.kind, size: read.size, build: read.build, packageURL: package)
            } else {
                installer = read
            }
        } catch {
            logger.error(
                "Can't read \(url.lastPathComponent, privacy: .public): \(String(describing: error), privacy: .public)")
            installer = nil
        }
        cache[url] = (stamp, installer)
        return installer
    }

    /// An app changes inside: its Info.plist and its SharedSupport image are what's read.
    private static func stamp(of url: URL, package: URL?) -> Stamp {
        let file =
            url.pathExtension == "app" ? url.appending(path: "Contents/SharedSupport/SharedSupport.dmg") : url
        let values = try? file.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
        let bundle = try? url.resourceValues(forKeys: [.contentModificationDateKey])
        let packageValues = try? package?.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
        return Stamp(
            modified: values?.contentModificationDate ?? bundle?.contentModificationDate,
            size: values?.fileSize, packageModified: packageValues?.contentModificationDate,
            packageSize: packageValues?.fileSize)
    }
}
