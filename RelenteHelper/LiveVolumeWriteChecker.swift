import Foundation
import os

nonisolated struct LiveVolumeWriteChecker: VolumeWriteChecking {
    private static let logger = Logger(subsystem: "com.afraidias.Relente", category: "helper")

    @concurrent func canWrite(to volume: URL) async -> Bool {
        let root = volume.standardizedFileURL
        guard root.isFileURL, root.deletingLastPathComponent().path == "/Volumes" else { return false }
        let marker = root.appending(path: ".relente-write-check-\(UUID().uuidString)")
        do {
            try Data("Relente access check".utf8).write(to: marker, options: .withoutOverwriting)
            try FileManager.default.removeItem(at: marker)
            Self.logger.info("Write access confirmed for selected volume")
            return true
        } catch {
            try? FileManager.default.removeItem(at: marker)
            Self.logger.error("Selected volume write check failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
}
