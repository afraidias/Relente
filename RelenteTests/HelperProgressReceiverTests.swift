import Foundation
import Testing

@testable import Relente

struct HelperProgressReceiverTests {
    @Test func `the helper reports typed progress and one-way output`() async {
        let receiver = HelperProgressReceiver()
        let (stream, continuation) = AsyncStream.makeStream(of: HelperCreateEvent.self)
        let timestamp = Date(timeIntervalSince1970: 1_798_000_000)
        receiver.set(continuation)
        receiver.report(
            phase: 1, fraction: 0.25, output: "Copying to disk: 25%", timestamp: timestamp,
            copiedBytes: 250, totalBytes: 1_000, bytesPerSecond: 100)
        continuation.finish()

        var events: [HelperCreateEvent] = []
        for await event in stream { events.append(event) }

        guard case .update(let update) = events.first else {
            Issue.record("The progress callback did not produce an update")
            return
        }
        #expect(events.count == 1)
        #expect(update.progress == CreateInstallMediaProgress(phase: .copy, fraction: 0.25))
        #expect(update.outputLine == "Copying to disk: 25%")
        #expect(update.timestamp == timestamp)
        #expect(update.copyMeasurement == InstallerCopyMeasurement(copiedBytes: 250, totalBytes: 1_000))
        #expect(update.copyBytesPerSecond == 100)
    }

    @Test func `unknown progress sentinels stay unknown and empty output is omitted`() async {
        let receiver = HelperProgressReceiver()
        let (stream, continuation) = AsyncStream.makeStream(of: HelperCreateEvent.self)
        let timestamp = Date(timeIntervalSince1970: 1_798_000_000)
        receiver.set(continuation)
        receiver.report(
            phase: -1, fraction: -1, output: "", timestamp: timestamp,
            copiedBytes: -1, totalBytes: -1, bytesPerSecond: -1)
        continuation.finish()

        var firstEvent: HelperCreateEvent?
        for await event in stream {
            firstEvent = event
            break
        }
        guard case .update(let update) = firstEvent else {
            Issue.record("The progress callback did not produce an update")
            return
        }
        #expect(update.progress == nil)
        #expect(update.outputLine == nil)
        #expect(update.timestamp == timestamp)
        #expect(update.copyMeasurement == nil)
        #expect(update.copyBytesPerSecond == nil)
    }
}
