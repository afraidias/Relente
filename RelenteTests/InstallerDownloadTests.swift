import Foundation
import Testing
import os

@testable import Relente

struct InstallerDownloadTests {
    private func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "Relente-download-test-\(UUID())")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        return url
    }

    private var configuration: URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [InstallerDownloadProtocol.self]
        return configuration
    }

    @Test func completedTransferMovesExactlyTheExpectedBytes() async throws {
        let directory = try directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let destination = directory.appending(path: "package.partial")
        let transfer = InstallerDownload(origin: .package, destination: destination, maximumBytes: 4, expectedBytes: 4)
        let result = try await transfer.start(
            URL(string: "https://swcdn.apple.com/success")!, configuration: configuration)
        #expect(result == destination)
        #expect(try Data(contentsOf: result) == Data("test".utf8))
    }

    @Test func truncatedTransferCannotPublishItsTemporaryFile() async throws {
        let directory = try directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let destination = directory.appending(path: "package.partial")
        let transfer = InstallerDownload(origin: .package, destination: destination, maximumBytes: 5, expectedBytes: 5)
        await #expect(throws: InstallerDownload.Failure.sizeMismatch) {
            try await transfer.start(URL(string: "https://swcdn.apple.com/success")!, configuration: configuration)
        }
        #expect(!FileManager.default.fileExists(atPath: destination.path))
    }

    @Test func cancellationBeforeStartingStillWaitsForATerminalCallback() async throws {
        let directory = try directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let destination = directory.appending(path: "package.partial")
        let transfer = InstallerDownload(origin: .package, destination: destination, maximumBytes: 4)
        transfer.cancel()
        await #expect(throws: CancellationError.self) {
            try await transfer.start(URL(string: "https://swcdn.apple.com/success")!, configuration: configuration)
        }
        #expect(!FileManager.default.fileExists(atPath: destination.path))
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["RELENTE_REAL_DOWNLOAD_URL"] != nil))
    func realAppleTransferCancellationAcknowledgesTerminationBeforeReturning() async throws {
        let text = try #require(ProcessInfo.processInfo.environment["RELENTE_REAL_DOWNLOAD_URL"])
        let url = try #require(URL(string: text))
        let directory = try directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let destination = directory.appending(path: "package.partial")
        let expected: Int64 = 12_205_110_942
        let observed = OSAllocatedUnfairLock(
            initialState: (transfer: Optional<InstallerDownload>.none, bytes: Int64(0)))
        let transfer = InstallerDownload(
            origin: .package, destination: destination,
            maximumBytes: expected, expectedBytes: expected
        ) { bytes, _, _ in
            let cancel = observed.withLock { value -> InstallerDownload? in
                guard bytes >= 1_048_576, value.bytes == 0 else { return nil }
                value.bytes = bytes
                return value.transfer
            }
            cancel?.cancel()
        }
        observed.withLock { $0.transfer = transfer }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForResource = 15
        let start = Date.now
        await #expect(throws: CancellationError.self) { try await transfer.start(url, configuration: configuration) }
        let bytes = observed.withLock { $0.bytes }
        #expect(bytes >= 1_048_576 && bytes < expected)
        #expect(transfer.hasTerminated)
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
        let evidence: [String: Any] = [
            "cancelRequestedAtBytes": bytes, "expectedBytes": expected,
            "fraction": Double(bytes) / Double(expected), "terminalCallbackObserved": transfer.hasTerminated,
            "ownedDirectoryEmpty": try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty,
            "seconds": Date.now.timeIntervalSince(start),
        ]
        try JSONSerialization.data(withJSONObject: evidence, options: [.prettyPrinted, .sortedKeys])
            .write(to: URL(filePath: "/private/tmp/relente-real-transfer-cancellation.json"))
        observed.withLock { $0.transfer = nil }
    }

    @Test func rejectedHTTPResponseNeverReportsAnAcceptedConnection() async throws {
        let directory = try directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let samples = OSAllocatedUnfairLock(initialState: 0)
        let transfer = InstallerDownload(
            origin: .package, destination: directory.appending(path: "bad.pkg"),
            maximumBytes: 4
        ) { _, _, _ in samples.withLock { $0 += 1 } }
        await #expect(throws: InstallerDownload.Failure.unexpectedResponse) {
            try await transfer.start(URL(string: "https://swcdn.apple.com/error")!, configuration: configuration)
        }
        #expect(samples.withLock { $0 } == 0)
        #expect(transfer.hasTerminated)
    }

    @Test func observedRateNeedsMonotonicTimeAndEnoughBytes() {
        var rate = InstallerTransferRate()
        #expect(rate.record(bytes: 100, at: 10) == nil)
        #expect(rate.record(bytes: 200, at: 10.1) == nil)
        #expect(rate.record(bytes: 400, at: 11) == 300)
        #expect(rate.record(bytes: 450, at: 11.1) == 300)
        #expect(rate.record(bytes: 399, at: 12) == nil)
        #expect(rate.record(bytes: 500, at: 10) == nil)
        #expect(rate.record(bytes: 600, at: 12) == 200)
    }

    @Test func existingItemIsNeverOverwrittenOrRemoved() async throws {
        let directory = try directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let destination = directory.appending(path: "retained.pkg")
        try Data("retained".utf8).write(to: destination)
        let transfer = InstallerDownload(origin: .package, destination: destination, maximumBytes: 4)
        await #expect(throws: InstallerDownload.Failure.invalidRequest) {
            try await transfer.start(URL(string: "https://swcdn.apple.com/success")!, configuration: configuration)
        }
        #expect(try Data(contentsOf: destination) == Data("retained".utf8))
    }
}

/// In-process transport: these unit tests do not contact Apple or other hosts.
private nonisolated final class InstallerDownloadProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url,
            let response = HTTPURLResponse(
                url: url, statusCode: url.path == "/error" ? 503 : 200, httpVersion: "HTTP/1.1",
                headerFields: ["Content-Length": "4"])
        else { return }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("test".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
