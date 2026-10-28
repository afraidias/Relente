import Foundation
import Testing

@testable import Relente

@Suite(.timeLimit(.minutes(1)))
struct HelperCreationServiceTests {

    private actor FakeClient: HelperClient {
        let outcome: CreateInstallMediaOutcome?
        let updates: [CreateInstallMediaUpdate]
        private(set) var installerURLs: [URL] = []
        private(set) var packageURLs: [URL?] = []
        private(set) var drives: [String] = []
        private(set) var authorizations: [Data] = []
        private(set) var cancels = 0
        private var eventContinuation: AsyncStream<HelperCreateEvent>.Continuation?
        private var createWaiter: CheckedContinuation<Void, Never>?
        private var cancelWaiter: CheckedContinuation<Void, Never>?
        private let holdsOpen: Bool

        init(
            outcome: CreateInstallMediaOutcome?, updates: [CreateInstallMediaUpdate] = [], holdsOpen: Bool = false
        ) {
            self.outcome = outcome
            self.updates = updates
            self.holdsOpen = holdsOpen
        }

        func connectsToCurrentHelper() async -> Bool { true }
        func format(_ drive: Drive, authorization: Data) async -> FormatOutcome? { .formatted }

        func createInstallMedia(installerURL: URL, installerPackageURL: URL?, drive: Drive, authorization: Data)
            async -> AsyncStream<HelperCreateEvent>
        {
            installerURLs.append(installerURL)
            packageURLs.append(installerPackageURL)
            drives.append(drive.bsdName)
            authorizations.append(authorization)
            if holdsOpen {
                let (stream, continuation) = AsyncStream.makeStream(of: HelperCreateEvent.self)
                eventContinuation = continuation
                createWaiter?.resume()
                createWaiter = nil
                return stream
            }
            let updates = updates
            let outcome = outcome
            return AsyncStream { continuation in
                for update in updates { continuation.yield(.update(update)) }
                continuation.yield(.finished(outcome))
                continuation.finish()
            }
        }

        func cancel() async {
            cancels += 1
            eventContinuation?.finish()
            eventContinuation = nil
            cancelWaiter?.resume()
            cancelWaiter = nil
        }

        func waitUntilCreateStarts() async {
            if !installerURLs.isEmpty { return }
            await withCheckedContinuation { createWaiter = $0 }
        }

        func waitUntilCancelled() async {
            if cancels > 0 { return }
            await withCheckedContinuation { cancelWaiter = $0 }
        }
    }

    private let installer = InstallerSource.samples[0]
    private let drive = Drive.samples[0]

    private func run(_ client: FakeClient, authorization: EraseAuthorization? = nil) async -> [CreationEvent] {
        var events: [CreationEvent] = []
        for await event in HelperCreationService(client: client, verifiesVolume: Self.hasExpectedContents).create(
            installer: installer, drive: drive, authorization: authorization)
        {
            events.append(event)
        }
        return events
    }

    nonisolated private static func hasExpectedContents(_ url: URL, _ installer: InstallerSource) -> Bool {
        guard url.lastPathComponent == "Install \(installer.name)",
            let contents = try? FileManager.default.contentsOfDirectory(atPath: url.path(percentEncoded: false))
        else { return false }
        return !contents.isEmpty
    }

    @Test func `real helper service has no simulation and requires authorization`() {
        let service = HelperCreationService(client: FakeClient(outcome: .created))
        #expect(service.simulation == nil)
        #expect(service.erasesDrive)
    }

    @Test func `cancelling creation forwards the selected package to the helper`() async {
        let source = InstallerSource(
            url: URL(filePath: "/private/tmp/Source.pkg"), name: "macOS Tahoe", version: "26.0", kind: .package,
            size: 1)
        let client = FakeClient(outcome: nil, holdsOpen: true)
        let service = HelperCreationService(client: client)
        let stream = service.create(installer: source, drive: drive, authorization: nil)
        let consumer = Task { for await _ in stream {} }

        await client.waitUntilCreateStarts()
        consumer.cancel()
        await client.waitUntilCancelled()
        await consumer.value

        #expect(await client.installerURLs == [source.url])
        #expect(await client.packageURLs == [Optional(source.url)])
    }

    @Test func `volume verification requires the expected installer app`() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "Relente-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data([1]).write(to: directory.appending(path: "unrelated-file"))
        #expect(!HelperCreationService.containsExpectedInstaller(in: directory, installer: installer))
        let contents = directory.appending(path: "Install \(installer.name).app/Contents", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        try Data([1]).write(to: contents.appending(path: "Info.plist"))
        #expect(HelperCreationService.containsExpectedInstaller(in: directory, installer: installer))
    }

    @Test func `media cookie permission error suggests checking disk access`() async {
        let updates = [
            CreateInstallMediaUpdate(progress: nil, outputLine: "Failed to write .IAPhysicalMedia", timestamp: .now),
            CreateInstallMediaUpdate(progress: nil, outputLine: "Operation not permitted", timestamp: .now),
        ]
        let events = await run(FakeClient(outcome: .createFailed, updates: updates))
        guard case .failed(let failure) = events.last else {
            Issue.record("The run didn't fail")
            return
        }
        #expect(failure.reason == .volumeAccessDenied)
    }

    @Test(arguments: ["Failed to write .IAPhysicalMedia", "Operation not permitted"])
    func `an incomplete permission signature remains a generic failure`(line: String) async {
        let update = CreateInstallMediaUpdate(progress: nil, outputLine: line, timestamp: .now)
        let events = await run(FakeClient(outcome: .createFailed, updates: [update]))
        guard case .failed(let failure) = events.last else {
            Issue.record("The run didn't fail")
            return
        }
        #expect(failure.reason == .createFailed)
    }

    @Test func `it sends the selected app, drive and authorization to create`() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "Relente-\(UUID().uuidString)")
        let volume = directory.appending(path: "Install macOS Tahoe")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        try FileManager.default.createDirectory(at: volume, withIntermediateDirectories: false)
        try Data([1]).write(to: volume.appending(path: "installer-data"))
        defer { try? FileManager.default.removeItem(at: directory) }
        let client = FakeClient(
            outcome: .created,
            updates: [
                CreateInstallMediaUpdate(
                    progress: nil,
                    outputLine: "Install media now available at \"\(volume.path(percentEncoded: false))\"",
                    timestamp: .now
                )
            ])
        let authorization = EraseAuthorization(reference: nil, externalForm: Data([1, 2, 3]))
        let events = await run(client, authorization: authorization)
        #expect(events.count == 2)
        #expect(events.last == .finished)
        #expect(await client.installerURLs == [installer.url])
        #expect(await client.drives == [drive.bsdName])
        #expect(await client.authorizations == [Data([1, 2, 3])])
    }

    @Test func `helper updates become progress and timestamped output events`() async {
        let timestamp = Date(timeIntervalSince1970: 123)
        let update = CreateInstallMediaUpdate(
            progress: .init(phase: .copy, fraction: 0.4), outputLine: "Copying to disk: 40%...", timestamp: timestamp)
        let markerDirectory = FileManager.default.temporaryDirectory.appending(path: "Relente-\(UUID().uuidString)")
        let volume = markerDirectory.appending(path: "Install macOS Tahoe")
        try? FileManager.default.createDirectory(at: volume, withIntermediateDirectories: true)
        try? Data([1]).write(to: volume.appending(path: "installer-data"))
        defer { try? FileManager.default.removeItem(at: markerDirectory) }
        let marker = CreateInstallMediaUpdate(
            progress: nil,
            outputLine: "Install media now available at \"\(volume.path(percentEncoded: false))\"",
            timestamp: timestamp)
        let events = await run(FakeClient(outcome: .created, updates: [update, marker]))
        #expect(events.count == 4)
        #expect(
            events[0]
                == .progress(
                    CreationProgress(
                        phase: .copy, phaseFraction: 0.4, installerSize: installer.size, isLive: true)))
        #expect(events[1] == .output(CreationOutputLine(timestamp: timestamp, text: "Copying to disk: 40%...")))
        #expect(events[2] == .output(CreationOutputLine(timestamp: timestamp, text: marker.outputLine!)))
        #expect(events[3] == .finished)
    }

    @Test func `app derives the phase when helper sends output without typed progress`() async {
        let timestamp = Date(timeIntervalSince1970: 123)
        let update = CreateInstallMediaUpdate(
            progress: nil, outputLine: "Copying essential files...", timestamp: timestamp)
        let events = await run(FakeClient(outcome: nil, updates: [update]))
        #expect(
            events.first
                == .progress(
                    CreationProgress(
                        phase: .copy, phaseFraction: nil, installerSize: installer.size, isLive: true)))
        #expect(events.dropFirst().first == .output(CreationOutputLine(timestamp: timestamp, text: update.outputLine!)))
    }

    @Test func `measured helper copy updates reach the live creation progress`() async {
        let update = CreateInstallMediaUpdate(
            progress: .init(phase: .copy, fraction: nil), outputLine: nil, timestamp: .now,
            copyMeasurement: InstallerCopyMeasurement(copiedBytes: 600, totalBytes: 1_000),
            copyBytesPerSecond: 100)
        let events = await run(FakeClient(outcome: nil, updates: [update]))

        #expect(
            events.first
                == .progress(
                    CreationProgress(
                        phase: .copy, phaseFraction: 0.6, copiedBytes: 600, installerSize: 1_000,
                        bytesPerSecond: 100, isLive: true, hasMeasuredCopyProgress: true)))
    }

    @Test func `measured image progress is retained while the drive is made bootable`() async {
        let measurement = CreateInstallMediaUpdate(
            progress: .init(phase: .copy, fraction: nil), outputLine: nil, timestamp: .now,
            copyMeasurement: InstallerCopyMeasurement(copiedBytes: 1_000, totalBytes: 1_000),
            copyBytesPerSecond: 100)
        let bootable = CreateInstallMediaUpdate(
            progress: .init(phase: .makeBootable, fraction: nil), outputLine: "Making disk bootable...", timestamp: .now
        )
        let events = await run(FakeClient(outcome: nil, updates: [measurement, bootable]))

        #expect(
            events[1]
                == .progress(
                    CreationProgress(
                        phase: .makeBootable, phaseFraction: nil, copiedBytes: 1_000, installerSize: 1_000,
                        bytesPerSecond: 100, isLive: true, hasMeasuredCopyProgress: true)))
    }

    @Test(arguments: [
        (CreateInstallMediaOutcome.driveChanged, CreationFailure.Reason.driveChanged),
        (.driveNotAllowed, .driveNotAllowed),
        (.invalidIdentifier, .driveNotAllowed),
        (.driveDisconnected, .driveDisconnected),
        (.invalidInstaller, .installerDamaged),
        (.invalidVolume, .createFailed),
        (.createFailed, .createFailed),
        (.notAuthorized, .unknown),
        (.busy, .unknown),
    ])
    func `helper failures become user-facing creation failures`(
        outcome: CreateInstallMediaOutcome, reason: CreationFailure.Reason
    ) async {
        let events = await run(FakeClient(outcome: outcome))
        guard case .failed(let failure) = events.last else {
            Issue.record("The run didn't fail")
            return
        }
        #expect(failure.reason == reason)
        #expect(failure.progress.phase == .format)
    }

    @Test func `no answer from the helper means it did not respond`() async {
        let events = await run(FakeClient(outcome: nil))
        guard case .failed(let failure) = events.last else {
            Issue.record("The run didn't fail")
            return
        }
        #expect(failure.reason == .helperUnavailable)
    }

    @Test func `helper success without an available volume marker does not show Done`() async {
        let events = await run(FakeClient(outcome: .created))
        guard case .failed(let failure) = events.last else {
            Issue.record("The run reported success without an available installer volume")
            return
        }
        #expect(failure.reason == .verificationFailed)
    }

    @Test func `the live service rejects a completion marker outside mounted volumes`() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "Relente-\(UUID().uuidString)")
        let volume = directory.appending(path: "Install macOS Tahoe")
        try FileManager.default.createDirectory(at: volume, withIntermediateDirectories: true)
        try Data([1]).write(to: volume.appending(path: "installer-data"))
        defer { try? FileManager.default.removeItem(at: directory) }
        let update = CreateInstallMediaUpdate(
            progress: nil,
            outputLine: "Install media now available at \"\(volume.path(percentEncoded: false))\"",
            timestamp: .now)
        var events: [CreationEvent] = []
        for await event in HelperCreationService(client: FakeClient(outcome: .created, updates: [update])).create(
            installer: installer, drive: drive, authorization: nil)
        {
            events.append(event)
        }
        guard case .failed(let failure) = events.last else {
            Issue.record("The live service accepted a non-volume marker")
            return
        }
        #expect(failure.reason == .verificationFailed)
    }
}
