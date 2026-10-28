import Foundation
import Testing

@testable import Relente

@Suite(.timeLimit(.minutes(1)))
struct HelperRequestHandlerTests {
    private nonisolated static let disk = DiskDescription(
        bsdName: "disk4", isWhole: true, isRemovable: true, deviceProtocol: "USB", mediaUUID: "uuid",
        serialNumber: "serial", size: 32_000_000_000)
    private nonisolated static let volumeURL = URL(filePath: "/Volumes/USB")

    private struct Authorization: AuthorizationChecking {
        func isAuthorized(_ externalForm: Data) async -> Bool { !externalForm.isEmpty }
    }

    private struct Disks: DiskReading {
        func describe(_ bsdName: String) async -> DiskDescription? {
            bsdName == HelperRequestHandlerTests.disk.bsdName ? HelperRequestHandlerTests.disk : nil
        }
        func bootDisks() async -> Set<String> { ["disk0"] }
    }

    private struct Volumes: VolumeReading {
        func describeVolume(at path: URL) async -> DiskDescription? {
            path == HelperRequestHandlerTests.volumeURL
                ? DiskDescription(bsdName: "disk4s1", isWhole: false, mountPoint: path)
                : nil
        }
    }

    private struct WriteChecker: VolumeWriteChecking {
        func canWrite(to volume: URL) async -> Bool { volume == HelperRequestHandlerTests.volumeURL }
    }

    private actor BlockingRunner: InstallMediaRunning {
        private var resultContinuation: CheckedContinuation<CreateInstallMediaRunResult, Never>?
        private var startContinuation: CheckedContinuation<Void, Never>?
        private(set) var didStart = false
        private(set) var didCancel = false

        func create(
            installerURL: URL, installerPackageURL: URL?, volumeURL: URL,
            cancellation: CreateInstallMediaCancellation,
            beforeLaunch: @escaping @Sendable () async -> CreateInstallMediaOutcome?,
            report: @escaping @Sendable (CreateInstallMediaUpdate) -> Void
        ) async -> CreateInstallMediaRunResult {
            guard await beforeLaunch() == nil else { return .failed }
            return await withCheckedContinuation { continuation in
                resultContinuation = continuation
                didStart = true
                startContinuation?.resume()
                startContinuation = nil
            }
        }

        func waitUntilStarted() async {
            if didStart { return }
            await withCheckedContinuation { startContinuation = $0 }
        }

        func cancel() async {
            didCancel = true
            resultContinuation?.resume(returning: .failed)
            resultContinuation = nil
        }
    }

    private struct ReportingRunner: InstallMediaRunning {
        func create(
            installerURL: URL, installerPackageURL: URL?, volumeURL: URL,
            cancellation: CreateInstallMediaCancellation,
            beforeLaunch: @escaping @Sendable () async -> CreateInstallMediaOutcome?,
            report: @escaping @Sendable (CreateInstallMediaUpdate) -> Void
        ) async -> CreateInstallMediaRunResult {
            guard await beforeLaunch() == nil else { return .failed }
            report(
                CreateInstallMediaUpdate(
                    progress: CreateInstallMediaProgress(phase: .copy, fraction: 0.5),
                    outputLine: "Copying to disk: 50%", timestamp: Date(timeIntervalSince1970: 1_798_000_000),
                    copyMeasurement: InstallerCopyMeasurement(copiedBytes: 500, totalBytes: 1_000),
                    copyBytesPerSecond: 100))
            return .created
        }

        func cancel() async {}
    }

    private struct Formatter: DiskFormatting {
        func format(_ bsdName: String) async -> Bool {
            bsdName == HelperRequestHandlerTests.disk.bsdName
        }
        func cancel() async {}
    }

    private func handler(runner: BlockingRunner) -> HelperRequestHandler {
        let format = FormatPipeline(
            authorization: Authorization(), disks: Disks(), formatter: Formatter())
        let create = CreateInstallMediaPipeline(
            authorization: Authorization(), disks: Disks(),
            volumes: Volumes(), runner: runner, volumeWriteChecker: WriteChecker())
        return HelperRequestHandler(pipeline: format, creationPipeline: create, progress: nil)
    }

    @Test func `connection loss cancels active creation and releases the operation gate`() async {
        let runner = BlockingRunner()
        let handler = handler(runner: runner)
        let creationReply = Task {
            await withCheckedContinuation { continuation in
                handler.createInstallMedia(
                    bsdName: "disk4", mediaUUID: "uuid", serialNumber: "serial", size: 32_000_000_000,
                    installerPath: "/Applications/Install macOS Test.app", installerPackagePath: nil,
                    volumePath: Self.volumeURL.path(percentEncoded: false),
                    authorization: Data([1])
                ) { continuation.resume(returning: $0) }
            }
        }

        await runner.waitUntilStarted()
        handler.connectionEnded()

        #expect(await creationReply.value == CreateInstallMediaOutcome.createFailed.rawValue)
        #expect(await runner.didCancel)

        let formatReply = Task {
            await withCheckedContinuation { continuation in
                handler.format(
                    bsdName: "disk4", mediaUUID: "uuid", serialNumber: "serial", size: 32_000_000_000,
                    authorization: Data([1]), reply: { continuation.resume(returning: $0) })
            }
        }
        #expect(await formatReply.value == FormatOutcome.formatted.rawValue)
    }

    @Test func `creation sends typed progress one way and replies with its terminal outcome`() async {
        let receiver = HelperProgressReceiver()
        let (stream, continuation) = AsyncStream.makeStream(of: HelperCreateEvent.self)
        receiver.set(continuation)
        let format = FormatPipeline(authorization: Authorization(), disks: Disks(), formatter: Formatter())
        let create = CreateInstallMediaPipeline(
            authorization: Authorization(), disks: Disks(), volumes: Volumes(), runner: ReportingRunner(),
            volumeWriteChecker: WriteChecker())
        let handler = HelperRequestHandler(pipeline: format, creationPipeline: create, progress: receiver)
        let result = await withCheckedContinuation { continuation in
            handler.createInstallMedia(
                bsdName: "disk4", mediaUUID: "uuid", serialNumber: "serial", size: 32_000_000_000,
                installerPath: "/Applications/Install macOS Test.app", installerPackagePath: nil,
                volumePath: Self.volumeURL.path(percentEncoded: false), authorization: Data([1]),
                reply: { continuation.resume(returning: $0) })
        }
        continuation.finish()

        var events: [HelperCreateEvent] = []
        for await event in stream { events.append(event) }
        #expect(result == CreateInstallMediaOutcome.created.rawValue)
        guard case .update(let update) = events.first else {
            Issue.record("The helper did not send the progress callback")
            return
        }
        #expect(events.count == 1)
        #expect(update.progress == CreateInstallMediaProgress(phase: .copy, fraction: 0.5))
        #expect(update.outputLine == "Copying to disk: 50%")
        #expect(update.copyMeasurement == InstallerCopyMeasurement(copiedBytes: 500, totalBytes: 1_000))
        #expect(update.copyBytesPerSecond == 100)
    }
}
