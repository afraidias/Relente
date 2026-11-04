import Foundation

/// A read-only support attachment whose returned identity is retained until a confirmed detach.
nonisolated enum InstallerSupportMetadata {
    enum Failure: Error {
        case invalid
        case recoveryRequired(URL)
    }

    @concurrent
    static func identity(
        in image: URL, workingDirectory: URL,
        isCancelled: @Sendable () -> Bool = { false }
    ) async throws -> InstallerOSIdentity {
        try Task.checkCancellation()
        if isCancelled() { throw CancellationError() }
        guard InstallerPathSafety.isSafe(image) else { throw Failure.invalid }
        let mount = workingDirectory.appending(path: "support-\(UUID())", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: mount, withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700])
        let output: Data
        do {
            output = try await InstallerCommand.attachSupport(image: image, mount: mount)
                .run(in: workingDirectory, completingCleanup: true)
        } catch { throw Failure.recoveryRequired(workingDirectory) }
        guard let device = InstallerExtractionWorkspace.ownedDevice(from: output, mount: mount) else {
            throw Failure.recoveryRequired(workingDirectory)
        }
        let result: Result<InstallerOSIdentity, any Error>
        do {
            if isCancelled() || Task.isCancelled { throw CancellationError() }
            let catalog = mount.appending(path: InstallerOSIdentity.catalogPath)
            guard InstallerPathSafety.isSafe(catalog),
                let size = try catalog.resourceValues(forKeys: [.fileSizeKey]).fileSize,
                size > 0, size <= 8 * 1_024 * 1_024
            else { throw Failure.invalid }
            result = .success(try InstallerOSIdentity.read(from: Data(contentsOf: catalog)))
        } catch { result = .failure(error) }
        do {
            _ = try await InstallerCommand.detachWorkspace(device: device)
                .run(in: workingDirectory, timeout: 30, completingCleanup: true)
        } catch { throw Failure.recoveryRequired(workingDirectory) }
        try FileManager.default.removeItem(at: mount)
        if isCancelled() || Task.isCancelled { throw CancellationError() }
        return try result.get()
    }
}
