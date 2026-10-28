import Foundation

nonisolated enum InstallerImageMounter {
    typealias CommandRunner = @Sendable (String, [String]) -> Data?

    private static let executable = "/usr/bin/hdiutil"

    static func mount(_ image: URL, run command: CommandRunner) -> InstallerImageMount? {
        if let output = command(executable, ["info", "-plist"]),
            let plist = propertyList(output),
            let images = plist["images"] as? [[String: Any]],
            let mountedImage = images.first(where: { ($0["image-path"] as? String) == image.path }),
            let entities = mountedImage["system-entities"] as? [[String: Any]],
            let entity = entities.first(where: { $0["mount-point"] != nil }),
            let mountPoint = entity["mount-point"] as? String
        {
            return InstallerImageMount(url: URL(filePath: mountPoint), device: nil, isOwned: false)
        }

        guard let output = command(executable, ["attach", "-readonly", "-nobrowse", "-plist", image.path]),
            let plist = propertyList(output),
            let entities = plist["system-entities"] as? [[String: Any]],
            let entity = entities.first(where: { $0["mount-point"] != nil }),
            let mountPoint = entity["mount-point"] as? String
        else { return nil }

        let device = entity["dev-entry"] as? String
        return InstallerImageMount(url: URL(filePath: mountPoint), device: device, isOwned: true)
    }

    static func detach(_ mount: InstallerImageMount?, run command: CommandRunner) {
        mount?.detach { device in
            _ = command(executable, ["detach", device])
        }
    }

    static func withCleanup<Result: Sendable>(
        of mount: InstallerImageMount?, run command: CommandRunner,
        operation: @Sendable () async throws -> Result
    ) async rethrows -> Result {
        defer { detach(mount, run: command) }
        return try await operation()
    }

    private static func propertyList(_ data: Data) -> [String: Any]? {
        (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any]
    }
}
