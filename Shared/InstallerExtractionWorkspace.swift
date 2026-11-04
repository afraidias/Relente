import Foundation

/// A bounded temporary filesystem for authenticated-package expansion, not a path sandbox.
nonisolated enum InstallerExtractionWorkspace {
    private static let gibibyte: Int64 = 1_073_741_824
    enum Failure: Error {
        case storageUnavailable, invalidMount
        case recoveryRequired(URL)
    }

    static func capacity(for packageBytes: Int64) throws -> Int {
        guard packageBytes > 0, packageBytes <= 60 * gibibyte else { throw Failure.storageUnavailable }
        return Int((packageBytes * 2 + 4 * gibibyte + gibibyte - 1) / gibibyte)
    }

    @concurrent
    static func expand(package: URL, destination: URL, isCancelled: @Sendable () -> Bool) async throws -> Data {
        let folder = package.deletingLastPathComponent()
        let bytes = try package.resourceValues(forKeys: [.fileSizeKey]).fileSize.map(Int64.init) ?? 0
        let capacity = try capacity(for: bytes)
        let available =
            try folder.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            .volumeAvailableCapacityForImportantUsage ?? 0
        guard available >= bytes * 4 + 8 * gibibyte else { throw Failure.storageUnavailable }
        let image = folder.appending(path: "preparation.sparsebundle")
        let mount = folder.appending(path: "workspace", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: mount, withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700])
        _ = try await InstallerCommand.createWorkspace(image: image, gibibytes: capacity)
            .run(in: folder, isCancelled: isCancelled)
        // Mount/detach are transactions: resolve their result even if cancellation was requested.
        let output: Data
        do {
            output = try await InstallerCommand.attachWorkspace(image: image, mount: mount)
                .run(in: folder, completingCleanup: true)
        } catch { throw Failure.recoveryRequired(folder) }
        guard let device = ownedDevice(from: output, mount: mount) else {
            // An attachment with an unknown identity must not be removed or force-detached.
            throw Failure.recoveryRequired(folder)
        }
        var detached = false
        do {
            if isCancelled() || Task.isCancelled { throw CancellationError() }
            let expanded = mount.appending(path: "expanded")
            let result = try await InstallerCommand.expand(package: package, destination: expanded)
                .run(in: mount, isCancelled: isCancelled)
            if isCancelled() || Task.isCancelled { throw CancellationError() }
            try FileManager.default.copyItem(at: expanded, to: destination)
            if isCancelled() || Task.isCancelled { throw CancellationError() }
            _ = try await InstallerCommand.detachWorkspace(device: device)
                .run(in: folder, timeout: 30, completingCleanup: true)
            detached = true
            try FileManager.default.removeItem(at: image)
            try FileManager.default.removeItem(at: mount)
            return result
        } catch InstallerCommand.Failure.lostProcess {
            throw Failure.recoveryRequired(folder)
        } catch {
            // Never remove an image or mountpoint while an attachment may still own it.
            if !detached {
                do {
                    _ = try await InstallerCommand.detachWorkspace(device: device)
                        .run(in: folder, timeout: 30, completingCleanup: true)
                } catch { throw Failure.recoveryRequired(folder) }
            }
            throw error
        }
    }

    static func ownedDevice(from output: Data, mount: URL) -> String? {
        guard let plist = try? PropertyListSerialization.propertyList(from: output, format: nil) as? [String: Any],
            let entities = plist["system-entities"] as? [[String: Any]],
            entities.filter({ ($0["mount-point"] as? String) == mount.path }).count == 1,
            entities.filter({ ($0["content-hint"] as? String) == "GUID_partition_scheme" }).count == 1,
            let device = entities.first(where: { ($0["content-hint"] as? String) == "GUID_partition_scheme" })?[
                "dev-entry"] as? String,
            device.range(of: "^/dev/disk[0-9]+$", options: .regularExpression) != nil
        else { return nil }
        return device
    }
}
