import Foundation
import Testing

@testable import Relente

struct InstallerCopyProgressTests {
    @Test func `measures the matching SharedSupport image in source and destination`() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appending(path: "Install macOS Test.app", directoryHint: .isDirectory)
        let volume = root.appending(path: "USB", directoryHint: .isDirectory)
        let sourceImage = try makeImage(in: source, bytes: 1_000)
        let destinationImage = try makeImage(in: volume.appending(path: source.lastPathComponent), bytes: 250)

        let measurement = InstallerCopyProgressReader.measure(sourceInstaller: source, destinationVolume: volume)

        #expect(measurement?.copiedBytes == 250)
        #expect(measurement?.totalBytes == 1_000)
        #expect(measurement?.fraction == 0.25)
        #expect(destinationImage.lastPathComponent == sourceImage.lastPathComponent)
    }

    @Test func `does not report progress before the destination image exists`() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appending(path: "Install macOS Test.app", directoryHint: .isDirectory)
        let volume = root.appending(path: "USB", directoryHint: .isDirectory)
        _ = try makeImage(in: source, bytes: 1_000)

        #expect(InstallerCopyProgressReader.measure(sourceInstaller: source, destinationVolume: volume) == nil)
    }

    @Test func `rejects a destination SharedSupport symbolic link`() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appending(path: "Install macOS Test.app", directoryHint: .isDirectory)
        let volume = root.appending(path: "USB", directoryHint: .isDirectory)
        let sourceImage = try makeImage(in: source, bytes: 1_000)
        let destinationDirectory = volume.appending(path: source.lastPathComponent)
            .appending(path: "Contents/SharedSupport", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(
            at: destinationDirectory.appending(path: "SharedSupport.dmg"), withDestinationURL: sourceImage)

        #expect(InstallerCopyProgressReader.measure(sourceInstaller: source, destinationVolume: volume) == nil)
    }

    @Test func `rejects destination size larger than the validated source`() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appending(path: "Install macOS Test.app", directoryHint: .isDirectory)
        let volume = root.appending(path: "USB", directoryHint: .isDirectory)
        _ = try makeImage(in: source, bytes: 1_000)
        _ = try makeImage(in: volume.appending(path: source.lastPathComponent), bytes: 1_001)

        #expect(InstallerCopyProgressReader.measure(sourceInstaller: source, destinationVolume: volume) == nil)
    }

    @Test func `waits for a full thirty-second window before estimating a copy rate`() {
        var estimator = InstallerCopyRateEstimator()
        let start = Date(timeIntervalSince1970: 100)
        let observations: [(Int64, TimeInterval)] = [(0, 0), (200, 2), (400, 4), (600, 6), (3_000, 30)]

        let rates = observations.map { bytes, seconds in
            estimator.record(
                InstallerCopyMeasurement(copiedBytes: bytes, totalBytes: 10_000)!,
                at: start.addingTimeInterval(seconds))
        }

        #expect(rates.prefix(4).allSatisfy { $0 == nil })
        #expect(rates.last! == 100)
    }

    @Test func `one-second samples use a thirty-second window for a stable rate`() {
        var estimator = InstallerCopyRateEstimator()
        let start = Date(timeIntervalSince1970: 100)
        let rates = (0...31).map { second in
            estimator.record(
                InstallerCopyMeasurement(copiedBytes: Int64(second) * 100, totalBytes: 10_000)!,
                at: start.addingTimeInterval(TimeInterval(second)))
        }

        #expect(rates[..<30].allSatisfy { $0 == nil })
        #expect(rates[30] == 100)
        #expect(rates[31] == 100)
    }

    @Test func `a brief copy burst has little effect on the sustained rate`() {
        var estimator = InstallerCopyRateEstimator()
        let start = Date(timeIntervalSince1970: 100)
        var rate: Int64?
        for second in 0...30 {
            let copiedBytes = Int64(second * 100 + (second >= 15 ? 200 : 0))
            rate = estimator.record(
                InstallerCopyMeasurement(copiedBytes: copiedBytes, totalBytes: 10_000)!,
                at: start.addingTimeInterval(TimeInterval(second)))
        }

        #expect(rate == 106)
    }

    @Test func `resets the copy rate when the destination size moves backwards`() {
        var estimator = InstallerCopyRateEstimator()
        let start = Date(timeIntervalSince1970: 100)
        for (bytes, seconds) in [(Int64(100), 0.0), (200, 2), (300, 4), (250, 6)] {
            _ = estimator.record(
                InstallerCopyMeasurement(copiedBytes: bytes, totalBytes: 1_000)!, at: start.addingTimeInterval(seconds))
        }

        #expect(
            estimator.record(
                InstallerCopyMeasurement(copiedBytes: 350, totalBytes: 1_000)!, at: start.addingTimeInterval(8)) == nil)
    }

    private func temporaryDirectory() throws -> URL {
        let root = URL(filePath: "/private/tmp", directoryHint: .isDirectory)
            .appending(path: "Relente-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func makeImage(in installer: URL, bytes: Int) throws -> URL {
        let image = installer.appending(path: "Contents/SharedSupport/SharedSupport.dmg")
        try FileManager.default.createDirectory(
            at: image.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 0x5A, count: bytes).write(to: image)
        return image
    }
}
