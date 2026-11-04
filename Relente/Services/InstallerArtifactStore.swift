import Darwin
import Foundation

/// Ready records are an index, never authority for the helper. Revalidate content before reuse.
nonisolated struct InstallerArtifactStore: Sendable {
    struct Record: Codable, Sendable {
        let schema: Int
        let version: String
        let build: String
        let appRelativePath: String
    }

    let root: URL
    init(
        root: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "Relente/Installers", directoryHint: .isDirectory)
    ) { self.root = root }

    func makePendingDirectory() throws -> URL {
        try FileManager.default.createDirectory(
            at: root, withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700])
        let folder = root.appending(path: "pending-\(UUID())", directoryHint: .isDirectory)
        guard InstallerPathSafety.isSafe(root), mkdir(folder.path, 0o700) == 0 else {
            throw InstallerAcquisitionError.recoveryRequired
        }
        return folder
    }

    @concurrent
    func commit(_ prepared: PreparedInstallerPackage, identity: InstallerSource) async throws -> InstallerSource {
        guard let build = identity.build, !build.isEmpty,
            prepared.appURL.path.hasPrefix(prepared.temporaryDirectory.path + "/"),
            InstallerPathSafety.isSafe(prepared.appURL), InstallerPathSafety.isSafe(prepared.packageURL)
        else { throw InstallerAcquisitionError.preparationFailed }
        let relative = String(prepared.appURL.path.dropFirst(prepared.temporaryDirectory.path.count + 1))
        let record = Record(schema: 1, version: identity.version.description, build: build, appRelativePath: relative)
        try FileManager.default.createDirectory(
            at: root, withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700])
        let folder = root.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.moveItem(at: prepared.temporaryDirectory, to: folder)
        // No Ready marker exists until the complete owned directory is in its retained location.
        try JSONEncoder().encode(record).write(to: folder.appending(path: "ready.json"), options: .atomic)
        return InstallerSource(
            url: folder.appending(path: relative), name: identity.name, version: identity.version,
            kind: .app, size: identity.size, build: build, packageURL: folder.appending(path: "InstallAssistant.pkg"))
    }

    @concurrent
    func retainedSources() async throws -> [InstallerSource] {
        guard FileManager.default.fileExists(atPath: root.path) else { return [] }
        let folders = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
        guard folders.count <= 256 else { throw InstallerAcquisitionError.recoveryRequired }
        var sources: [InstallerSource] = []
        for folder in folders where UUID(uuidString: folder.lastPathComponent) != nil {
            try Task.checkCancellation()
            let marker = folder.appending(path: "ready.json")
            guard InstallerPathSafety.isSafe(marker),
                let size = try marker.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= 16_384,
                let record = try? JSONDecoder().decode(Record.self, from: Data(contentsOf: marker)),
                record.schema == 1, let version = MacOSVersion(record.version), !record.build.isEmpty,
                !record.appRelativePath.hasPrefix("/"),
                !record.appRelativePath.split(separator: "/").contains(where: { $0 == ".." || $0 == "." })
            else { continue }
            let app = folder.appending(path: record.appRelativePath)
            let package = folder.appending(path: "InstallAssistant.pkg")
            guard app.path.hasPrefix(folder.path + "/"), InstallerPathSafety.isSafe(app),
                InstallerPathSafety.isSafe(package)
            else { continue }
            // A crash during verification leaves an explicit pending operation, never a
            // falsely trusted Ready record or an unidentified mount in a retained directory.
            let work = try makePendingDirectory()
            do {
                let output = try await InstallerCommand.verifyPackage(package).run(in: work, timeout: 60)
                guard let text = String(data: output, encoding: .utf8),
                    AppleInstallerPackageSignature.acceptsSuccessfulCheck(text)
                else {
                    try FileManager.default.removeItem(at: work)
                    continue
                }
                let expected = try InstallerOSIdentity(version: version.description, build: record.build)
                let candidate = PreparedInstallerPackage(appURL: app, packageURL: package, temporaryDirectory: work)
                let read = try await AcquiredInstallerReader.read(candidate, expected: expected)
                try FileManager.default.removeItem(at: work)
                sources.append(read)
            } catch InstallerCommand.Failure.lostProcess {
                throw InstallerAcquisitionError.recoveryRequired
            } catch InstallerSupportMetadata.Failure.recoveryRequired {
                throw InstallerAcquisitionError.recoveryRequired
            } catch {
                do { try FileManager.default.removeItem(at: work) } catch {
                    throw InstallerAcquisitionError.recoveryRequired
                }
                if error is CancellationError { throw error }
                // Failed validation makes this entry unavailable; never delete retained content.
            }
        }
        return sources
    }

    static func isUnpublished(_ url: URL, root storageRoot: URL = InstallerArtifactStore().root) -> Bool {
        // Foundation only canonicalizes existing paths consistently. Check the lexical path
        // too, so a not-yet-created child of pending storage cannot escape this guard.
        let pairs = [
            (url, storageRoot),
            (url.resolvingSymlinksInPath(), storageRoot.resolvingSymlinksInPath()),
        ]
        for (candidate, root) in pairs where candidate.path.hasPrefix(root.path + "/") {
            let relative = String(candidate.path.dropFirst(root.path.count + 1))
            guard let directory = relative.split(separator: "/").first else { return true }
            let marker = root.appending(path: String(directory)).appending(path: "ready.json")
            return !FileManager.default.fileExists(atPath: marker.path)
        }
        return false
    }

    /// Never promote pending work on relaunch. Surface it for recovery instead of deleting it.
    func hasPendingWork() throws -> Bool {
        guard FileManager.default.fileExists(atPath: root.path) else { return false }
        return try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
            .contains { folder in
                folder.lastPathComponent.hasPrefix("pending-")
                    || (UUID(uuidString: folder.lastPathComponent) != nil
                        && !FileManager.default.fileExists(atPath: folder.appending(path: "ready.json").path))
            }
    }
}
