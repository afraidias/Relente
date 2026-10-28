import Foundation

nonisolated enum InstallerPackagePreparer {
    enum PreparationError: Error, Equatable {
        case invalid
        case cancelled
    }
    typealias CommandRunner = @Sendable (String, [String]) -> Data?

    @concurrent
    static func prepare(
        _ packageURL: URL, isCancelled: @Sendable () -> Bool = { false }
    ) async throws -> PreparedInstallerPackage {
        try await prepare(packageURL, run: Self.run, isCancelled: isCancelled)
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
        let temporaryDirectory = URL(filePath: "/private/tmp/Relente-" + UUID().uuidString)
        try FileManager.default.createDirectory(
            at: temporaryDirectory, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        let stagedPackage = temporaryDirectory.appending(path: "InstallAssistant.pkg")
        let expandedPackage = temporaryDirectory.appending(path: "expanded")
        do {
            try FileManager.default.copyItem(at: packageURL, to: stagedPackage)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: stagedPackage.path)
            guard !isCancelled() else { throw PreparationError.cancelled }
            guard let signature = command("/usr/sbin/pkgutil", ["--check-signature", stagedPackage.path]),
                let signatureText = String(data: signature, encoding: .utf8),
                InstallerPackageProvenance.hasAppleSoftwareUpdateSignature(signatureText)
            else { throw PreparationError.invalid }
            guard !isCancelled() else { throw PreparationError.cancelled }
            guard command("/usr/sbin/pkgutil", ["--expand-full", stagedPackage.path, expandedPackage.path]) != nil
            else { throw PreparationError.invalid }
            guard !isCancelled() else { throw PreparationError.cancelled }
            guard let app = installerApp(in: expandedPackage), addSharedSupport(from: expandedPackage, to: app) else {
                throw PreparationError.invalid
            }
            return PreparedInstallerPackage(
                appURL: app, packageURL: stagedPackage, temporaryDirectory: temporaryDirectory)
        } catch {
            try? FileManager.default.removeItem(at: temporaryDirectory)
            throw (error as? PreparationError) ?? PreparationError.invalid
        }
    }

    private static func installerApp(in folder: URL) -> URL? {
        guard
            let enumerator = FileManager.default.enumerator(
                at: folder, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles])
        else { return nil }
        for case let candidate as URL in enumerator {
            guard candidate.pathExtension == "app" else { continue }
            enumerator.skipDescendants()
            guard candidate.lastPathComponent.hasPrefix("Install "), InstallerPathSafety.isSafe(candidate) else {
                continue
            }
            return candidate
        }
        return nil
    }

    private static func addSharedSupport(from expandedPackage: URL, to app: URL) -> Bool {
        let sharedSupportImage = expandedPackage.appending(path: "SharedSupport.dmg")
        let sharedSupportDirectory = app.appending(path: "Contents/SharedSupport", directoryHint: .isDirectory)
        let sharedSupportDestination = sharedSupportDirectory.appending(path: "SharedSupport.dmg")
        guard InstallerPathSafety.isSafe(sharedSupportImage),
            (try? sharedSupportImage.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
        else { return false }

        do {
            try FileManager.default.createDirectory(
                at: sharedSupportDirectory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o755])
            if FileManager.default.fileExists(atPath: sharedSupportDestination.path) {
                return InstallerPathSafety.isSafe(sharedSupportDestination)
                    && (try? sharedSupportDestination.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile)
                        == true
            }
            try FileManager.default.linkItem(at: sharedSupportImage, to: sharedSupportDestination)
            return true
        } catch {
            return false
        }
    }

    private static func run(_ executable: String, _ arguments: [String]) -> Data? {
        let process = Process()
        process.executableURL = URL(filePath: executable)
        process.arguments = arguments
        let output = Pipe()
        process.standardOutput = output
        process.standardError = output
        guard (try? process.run()) != nil else { return nil }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return process.terminationStatus == 0 ? data : nil
    }
}
