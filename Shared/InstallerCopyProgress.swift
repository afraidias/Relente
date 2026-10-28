import Darwin
import Foundation

nonisolated struct InstallerCopyMeasurement: Hashable, Sendable {
    let copiedBytes: Int64
    let totalBytes: Int64

    init?(copiedBytes: Int64, totalBytes: Int64) {
        guard totalBytes > 0, copiedBytes >= 0, copiedBytes <= totalBytes else { return nil }
        self.copiedBytes = copiedBytes
        self.totalBytes = totalBytes
    }

    var fraction: Double {
        Double(copiedBytes) / Double(totalBytes)
    }
}

/// Reads only the primary installer image at the same relative path in the source and USB apps.
nonisolated enum InstallerCopyProgressReader {
    private static let imagePath = "Contents/SharedSupport/SharedSupport.dmg"

    static func measure(sourceInstaller: URL, destinationVolume: URL) -> InstallerCopyMeasurement? {
        guard InstallerPathSafety.isSafe(sourceInstaller), InstallerPathSafety.isSafe(destinationVolume) else {
            return nil
        }
        let source = sourceInstaller.appending(path: imagePath)
        let destination = destinationVolume.appending(path: sourceInstaller.lastPathComponent).appending(
            path: imagePath)
        guard InstallerPathSafety.isSafe(source), InstallerPathSafety.isSafe(destination),
            let totalBytes = regularFileSize(at: source), let copiedBytes = regularFileSize(at: destination)
        else { return nil }
        return InstallerCopyMeasurement(copiedBytes: copiedBytes, totalBytes: totalBytes)
    }

    private static func regularFileSize(at url: URL) -> Int64? {
        var info = stat()
        guard lstat(url.path, &info) == 0, (info.st_mode & S_IFMT) == S_IFREG else { return nil }
        return Int64(info.st_size)
    }
}

/// Estimates the primary image's sustained copy rate over a 30-second rolling window.
nonisolated struct InstallerCopyRateEstimator: Sendable {
    private static let observationLimit = 31
    private static let stabilityWindow: TimeInterval = 30

    private struct Observation: Sendable {
        let copiedBytes: Int64
        let totalBytes: Int64
        let timestamp: Date
    }

    private var observations: [Observation] = []

    mutating func record(_ measurement: InstallerCopyMeasurement, at timestamp: Date) -> Int64? {
        if let previous = observations.last,
            timestamp <= previous.timestamp || measurement.totalBytes != previous.totalBytes
                || measurement.copiedBytes < previous.copiedBytes
        {
            observations.removeAll(keepingCapacity: true)
        }
        observations.append(
            Observation(copiedBytes: measurement.copiedBytes, totalBytes: measurement.totalBytes, timestamp: timestamp))
        if observations.count > Self.observationLimit { observations.removeFirst() }
        guard observations.count >= 4, let first = observations.first, let last = observations.last else { return nil }
        let elapsed = timestamp.timeIntervalSince(first.timestamp)
        let increase = last.copiedBytes - first.copiedBytes
        guard elapsed >= Self.stabilityWindow, increase > 0 else { return nil }
        return Int64((Double(increase) / elapsed).rounded(.down))
    }
}
