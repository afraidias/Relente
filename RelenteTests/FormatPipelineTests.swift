//
//  FormatPipelineTests.swift
//  RelenteTests
//
//  How the helper handles a format request, with fake authorization, disks and formatter: no real
//  disk is read or erased.
//

import Foundation
import Testing

@testable import Relente

@Suite(.timeLimit(.minutes(1)))
struct FormatPipelineTests {

    // MARK: - Fakes

    private actor Calls {
        private(set) var log: [String] = []
        func record(_ call: String) { log.append(call) }
    }

    private struct FakeAuthorization: AuthorizationChecking {
        let grants: Bool
        let calls: Calls
        func isAuthorized(_ externalForm: Data) async -> Bool {
            await calls.record("authorize")
            return grants && !externalForm.isEmpty
        }
    }

    private struct FakeDisks: DiskReading {
        /// What each read returns, in order; the last one repeats.
        let reads: [DiskDescription?]
        let calls: Calls
        private let index = Counter()

        init(_ reads: [DiskDescription?], calls: Calls) {
            self.reads = reads
            self.calls = calls
        }

        func describe(_ bsdName: String) async -> DiskDescription? {
            await calls.record("read \(bsdName)")
            let read = await index.next()
            return reads[min(read, reads.count - 1)]
        }

        func bootDisks() async -> Set<String> { ["disk0"] }
    }

    private actor Counter {
        private var value = 0
        func next() -> Int {
            defer { value += 1 }
            return value
        }
    }

    private actor FakeFormatter: DiskFormatting {
        let succeeds: Bool
        let calls: Calls
        /// Holds the format until `finish()`, to send a second request meanwhile.
        private var gate: CheckedContinuation<Void, Never>?
        private let waits: Bool

        init(succeeds: Bool = true, waits: Bool = false, calls: Calls) {
            self.succeeds = succeeds
            self.waits = waits
            self.calls = calls
        }

        func format(_ bsdName: String) async -> Bool {
            await calls.record("format \(bsdName)")
            if waits { await withCheckedContinuation { gate = $0 } }
            return succeeds
        }

        func cancel() async {
            await calls.record("cancel")
            finish()
        }

        func finish() {
            gate?.resume()
            gate = nil
        }

        var isWaiting: Bool { gate != nil }
    }

    // MARK: - Helpers

    private static let stick = DiskDescription(
        bsdName: "disk4", isWhole: true, isRemovable: true, deviceProtocol: "USB", mediaUUID: "UUID-4",
        serialNumber: "123", size: 32_000_000_000)
    private static let confirmed = DiskFingerprint(stick)

    private func request(_ bsdName: String = "disk4", authorization: Data = Data([1])) -> FormatRequest {
        FormatRequest(bsdName: bsdName, fingerprint: Self.confirmed, authorization: authorization)
    }

    private func pipeline(
        grants: Bool = true, disks: [DiskDescription?] = [stick], formatter: FakeFormatter? = nil, calls: Calls
    ) -> FormatPipeline {
        FormatPipeline(
            authorization: FakeAuthorization(grants: grants, calls: calls), disks: FakeDisks(disks, calls: calls),
            formatter: formatter ?? FakeFormatter(calls: calls))
    }

    // MARK: - Tests

    @Test func `a valid request is checked in order, then formatted`() async {
        let calls = Calls()
        let outcome = await pipeline(calls: calls).format(request())
        #expect(outcome == .formatted)
        #expect(await calls.log == ["authorize", "read disk4", "format disk4"])
    }

    @Test func `without authorization nothing is read or formatted`() async {
        let calls = Calls()
        #expect(await pipeline(grants: false, calls: calls).format(request()) == .notAuthorized)
        #expect(await pipeline(calls: calls).format(request(authorization: Data())) == .notAuthorized)
        #expect(await calls.log == ["authorize", "authorize"])
    }

    @Test func `an invalid identifier is refused before reading any disk`() async {
        let calls = Calls()
        #expect(await pipeline(calls: calls).format(request("disk4s1")) == .invalidIdentifier)
        #expect(await calls.log == ["authorize"])
    }

    @Test func `a disk that fails the checks is never formatted`() async {
        let calls = Calls()
        let internalDisk = DiskDescription(
            bsdName: "disk4", isWhole: true, isInternal: true, isRemovable: true, deviceProtocol: "USB",
            mediaUUID: "UUID-4", serialNumber: "123", size: 32_000_000_000)
        #expect(await pipeline(disks: [internalDisk], calls: calls).format(request()) == .driveNotAllowed)
        #expect(await calls.log == ["authorize", "read disk4"])
    }

    @Test func `a swapped drive is refused as changed`() async {
        let calls = Calls()
        let other = DiskDescription(
            bsdName: "disk4", isWhole: true, isRemovable: true, deviceProtocol: "USB", mediaUUID: "UUID-5",
            serialNumber: "456", size: 32_000_000_000)
        #expect(await pipeline(disks: [other], calls: calls).format(request()) == .driveChanged)
        #expect(!(await calls.log.contains("format disk4")))
    }

    @Test func `a disk that is gone is disconnected`() async {
        let calls = Calls()
        #expect(await pipeline(disks: [nil], calls: calls).format(request()) == .driveDisconnected)
    }

    @Test func `a failed format is disconnected if the disk is gone afterwards`() async {
        let calls = Calls()
        let failing = FakeFormatter(succeeds: false, calls: calls)
        #expect(
            await pipeline(disks: [Self.stick, nil], formatter: failing, calls: calls).format(request())
                == .driveDisconnected)
    }

    @Test func `a failed format with the disk still there is a format failure`() async {
        let calls = Calls()
        let failing = FakeFormatter(succeeds: false, calls: calls)
        #expect(await pipeline(formatter: failing, calls: calls).format(request()) == .formatFailed)
    }

    @Test func `a second request while one runs is busy, and cancel reaches the formatter`() async throws {
        let calls = Calls()
        let slow = FakeFormatter(succeeds: false, waits: true, calls: calls)
        let pipeline = pipeline(formatter: slow, calls: calls)

        let first = Task { await pipeline.format(request()) }
        while !(await slow.isWaiting) { await Task.yield() }

        #expect(await pipeline.format(request()) == .busy)
        await pipeline.cancel()
        #expect(await first.value == .formatFailed)
        #expect(await calls.log.contains("cancel"))

        // Once it's over, a new request reaches the formatter again.
        let third = Task { await pipeline.format(request()) }
        while !(await slow.isWaiting) { await Task.yield() }
        await slow.finish()
        #expect(await third.value == .formatFailed)
    }

    @Test func `cancel with nothing running does nothing`() async {
        let calls = Calls()
        await pipeline(calls: calls).cancel()
        #expect(await calls.log.isEmpty)
    }
}
