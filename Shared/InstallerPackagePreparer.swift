import Darwin
import Foundation

nonisolated enum InstallerPackagePreparer {
    enum PreparationError: Error, Equatable {
        case invalid
        case invalidLayout(String)
        case invalidSupport
        case cancelled
        case recoveryRequired(URL)
        case cleanupFailed(URL)
    }
    typealias CommandRunner = @Sendable (String, [String]) async throws -> Data?

    @concurrent
    static func prepare(
        _ packageURL: URL, isCancelled: @Sendable () -> Bool = { false }
    ) async throws -> PreparedInstallerPackage {
        try await prepare(
            packageURL,
            run: { executable, arguments in
                guard executable == "/usr/sbin/pkgutil", let path = arguments.dropFirst().first else {
                    throw PreparationError.invalid
                }
                let package = URL(filePath: path)
                let command: InstallerCommand
                switch arguments.first {
                case "--check-signature" where arguments.count == 2:
                    command = .verifyPackage(package)
                case "--expand-full" where arguments.count == 3:
                    return try await InstallerExtractionWorkspace.expand(
                        package: package,
                        destination: URL(filePath: arguments[2]), isCancelled: isCancelled)
                default: throw PreparationError.invalid
                }
                return try await command.run(in: package.deletingLastPathComponent(), isCancelled: isCancelled)
            }, isCancelled: isCancelled)
    }

    @concurrent
    static func prepare(
        _ packageURL: URL, run command: CommandRunner, isCancelled: @Sendable () -> Bool = { false }
    ) async throws -> PreparedInstallerPackage {
        guard InstallerPathSafety.isSafe(packageURL), packageURL.pathExtension.lowercased() == "pkg",
            (try? packageURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
        else { throw PreparationError.invalid }
        guard !isCancelled() else { throw PreparationError.cancelled }

        // Use the backing path: macOS exposes the same location through the `/var` symlink.
        let temporaryDirectory = try InstallerPrivateDirectory.create()
        let stagedPackage = temporaryDirectory.appending(path: "InstallAssistant.pkg")
        let expandedPackage = temporaryDirectory.appending(path: "expanded")
        do {
            try copySnapshot(from: packageURL, to: stagedPackage, isCancelled: isCancelled)
            guard !isCancelled() else { throw PreparationError.cancelled }
            guard let signature = try await command("/usr/sbin/pkgutil", ["--check-signature", stagedPackage.path]),
                let signatureText = String(data: signature, encoding: .utf8),
                InstallerPackageProvenance.hasAppleSoftwareUpdateSignature(signatureText)
            else { throw PreparationError.invalid }
            guard !isCancelled() else { throw PreparationError.cancelled }
            guard
                try await command("/usr/sbin/pkgutil", ["--expand-full", stagedPackage.path, expandedPackage.path])
                    != nil
            else { throw PreparationError.invalid }
            guard !isCancelled() else { throw PreparationError.cancelled }
            let app = try installerApp(in: expandedPackage)
            guard addSharedSupport(from: stagedPackage, to: app) else { throw PreparationError.invalidSupport }
            return PreparedInstallerPackage(
                appURL: app, packageURL: stagedPackage, temporaryDirectory: temporaryDirectory)
        } catch InstallerCommand.Failure.lostProcess {
            throw PreparationError.recoveryRequired(temporaryDirectory)
        } catch InstallerExtractionWorkspace.Failure.recoveryRequired {
            throw PreparationError.recoveryRequired(temporaryDirectory)
        } catch {
            do { try FileManager.default.removeItem(at: temporaryDirectory) } catch {
                throw PreparationError.cleanupFailed(temporaryDirectory)
            }
            if error is CancellationError { throw PreparationError.cancelled }
            throw (error as? PreparationError) ?? PreparationError.invalid
        }
    }

    /// Open the source without following a final symlink; only the private completed copy is verified.
    private static func copySnapshot(from source: URL, to destination: URL, isCancelled: @Sendable () -> Bool) throws {
        let input = open(source.path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
        guard input >= 0 else { throw PreparationError.invalid }
        defer { close(input) }
        var info = stat()
        guard fstat(input, &info) == 0, (info.st_mode & S_IFMT) == S_IFREG,
            info.st_size > 0, info.st_size <= 60 * 1_073_741_824
        else { throw PreparationError.invalid }
        let free =
            try destination.deletingLastPathComponent().resourceValues(forKeys: [
                .volumeAvailableCapacityForImportantUsageKey
            ])
            .volumeAvailableCapacityForImportantUsage ?? 0
        guard free >= info.st_size * 4 + 8 * 1_073_741_824 else { throw PreparationError.invalid }
        let output = open(destination.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard output >= 0 else { throw PreparationError.invalid }
        defer { close(output) }
        var buffer = [UInt8](repeating: 0, count: 1_048_576)
        var copied: Int64 = 0
        while true {
            if isCancelled() || Task.isCancelled { throw PreparationError.cancelled }
            let count = buffer.withUnsafeMutableBytes { Darwin.read(input, $0.baseAddress, $0.count) }
            guard count >= 0 else {
                if errno == EINTR { continue }
                throw PreparationError.invalid
            }
            if count == 0 { break }
            copied += Int64(count)
            guard copied <= info.st_size else { throw PreparationError.invalid }
            var offset = 0
            while offset < count {
                let written = buffer.withUnsafeBytes {
                    Darwin.write(output, $0.baseAddress!.advanced(by: offset), count - offset)
                }
                guard written > 0 else {
                    if errno == EINTR { continue }
                    throw PreparationError.invalid
                }
                offset += written
            }
        }
        guard copied == info.st_size, fsync(output) == 0 else { throw PreparationError.invalid }
    }

    private static func installerApp(in folder: URL) throws -> URL {
        let applications = folder.appending(path: "Payload/Applications", directoryHint: .isDirectory)
        guard InstallerPathSafety.isSafe(applications) else {
            throw PreparationError.invalidLayout("unsafe Applications path")
        }
        let items = try FileManager.default.contentsOfDirectory(
            at: applications,
            includingPropertiesForKeys: [.isDirectoryKey], options: [])
        guard items.count == 1, let app = items.first else {
            throw PreparationError.invalidLayout(
                "expected one application, found: " + items.map(\.lastPathComponent).joined(separator: ", "))
        }
        guard app.pathExtension == "app", app.lastPathComponent.hasPrefix("Install "),
            InstallerPathSafety.isSafe(app), (try? app.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        else { throw PreparationError.invalidLayout("unexpected application entry") }
        guard safeContents(of: app) else { throw PreparationError.invalidLayout("unsafe application contents") }
        return app
    }

    /// Framework links may resolve inside the app; no link may escape its authenticated layout.
    private static func safeContents(of app: URL) -> Bool {
        guard
            let entries = FileManager.default.enumerator(
                at: app,
                includingPropertiesForKeys: [.isSymbolicLinkKey, .isRegularFileKey, .isDirectoryKey])
        else { return false }
        let resolvedApp = app.resolvingSymlinksInPath().path
        for case let entry as URL in entries {
            guard
                let values = try? entry.resourceValues(forKeys: [
                    .isSymbolicLinkKey, .isRegularFileKey, .isDirectoryKey,
                ])
            else { return false }
            if values.isSymbolicLink == true {
                let target = entry.resolvingSymlinksInPath()
                guard target.path.hasPrefix(resolvedApp + "/"), FileManager.default.fileExists(atPath: target.path)
                else {
                    return false
                }
            } else if values.isRegularFile != true && values.isDirectory != true {
                return false
            }
        }
        return true
    }

    private static func addSharedSupport(from package: URL, to app: URL) -> Bool {
        let sharedSupportImage = package
        let sharedSupportDirectory = app.appending(path: "Contents/SharedSupport", directoryHint: .isDirectory)
        let sharedSupportDestination = sharedSupportDirectory.appending(path: "SharedSupport.dmg")
        guard InstallerPathSafety.isSafe(sharedSupportImage),
            (try? sharedSupportImage.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
        else { return false }

        do {
            try FileManager.default.createDirectory(
                at: sharedSupportDirectory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o755])
            if FileManager.default.fileExists(atPath: sharedSupportDestination.path) {
                // A pre-existing support image is an unknown composition, not a reusable result.
                return false
            }
            try FileManager.default.linkItem(at: sharedSupportImage, to: sharedSupportDestination)
            return true
        } catch {
            return false
        }
    }

}
