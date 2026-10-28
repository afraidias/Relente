import Foundation
import Testing

@testable import Relente

@Suite(.timeLimit(.minutes(1)))
struct CreateInstallMediaPipelineTests {

    @Test func `only an app extracted beside the staged package has package provenance`() {
        let temporary = URL(filePath: "/private/tmp/Relente-123")
        let package = temporary.appending(path: "InstallAssistant.pkg")
        let extractedApp = temporary.appending(path: "expanded/Payload/Applications/Install macOS Test.app")
        let directApp = URL(filePath: "/Applications/Install macOS Test.app")
        let mountedDMGApp = URL(filePath: "/Volumes/Install macOS Test/Install macOS Test.app")

        #expect(InstallerPackageProvenance.hasExpectedPreparedLayout(package: package, app: extractedApp))
        #expect(!InstallerPackageProvenance.hasExpectedPreparedLayout(package: package, app: directApp))
        #expect(!InstallerPackageProvenance.hasExpectedPreparedLayout(package: package, app: mountedDMGApp))
    }

    @Test func `only mounts created by this operation may be detached`() {
        let mountURL = URL(filePath: "/Volumes/Installer")
        let owned = InstallerImageMount(url: mountURL, device: "/dev/disk4", isOwned: true)
        let preexisting = InstallerImageMount(url: mountURL, device: "/dev/disk4", isOwned: false)
        let missingDevice = InstallerImageMount(url: mountURL, device: nil, isOwned: true)

        #expect(owned.deviceToDetach == "/dev/disk4")
        #expect(preexisting.deviceToDetach == nil)
        #expect(missingDevice.deviceToDetach == nil)

        var detached: [String] = []
        owned.detach { detached.append($0) }
        preexisting.detach { detached.append($0) }
        missingDevice.detach { detached.append($0) }
        #expect(detached == ["/dev/disk4"])
    }

    private actor CallLog {
        private(set) var entries: [String] = []
        func add(_ entry: String) { entries.append(entry) }
    }

    private struct Authorization: AuthorizationChecking {
        let allowed: Bool
        let calls: CallLog
        func isAuthorized(_ externalForm: Data) async -> Bool {
            await calls.add("authorization")
            return allowed && !externalForm.isEmpty
        }
    }

    private struct Disks: DiskReading {
        let disk: DiskDescription?
        let calls: CallLog
        func describe(_ bsdName: String) async -> DiskDescription? {
            await calls.add("disk")
            return disk
        }
        func bootDisks() async -> Set<String> { ["disk0"] }
    }

    private struct Volumes: VolumeReading {
        let volume: DiskDescription?
        let calls: CallLog
        func describeVolume(at path: URL) async -> DiskDescription? {
            await calls.add("volume")
            return volume
        }
    }

    private struct WriteChecker: VolumeWriteChecking {
        let allowed: Bool
        let calls: CallLog
        func canWrite(to volume: URL) async -> Bool {
            await calls.add("write")
            return allowed
        }
    }

    private actor BlockingWriteChecker: VolumeWriteChecking {
        private var resultContinuation: CheckedContinuation<Bool, Never>?
        private var startContinuation: CheckedContinuation<Void, Never>?
        private(set) var didStart = false

        func canWrite(to volume: URL) async -> Bool {
            await withCheckedContinuation { continuation in
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

        func allow() {
            resultContinuation?.resume(returning: true)
            resultContinuation = nil
        }
    }

    private struct Runner: InstallMediaRunning {
        let result: CreateInstallMediaRunResult
        let calls: CallLog
        func create(
            installerURL: URL, installerPackageURL: URL?, volumeURL: URL,
            cancellation: CreateInstallMediaCancellation,
            beforeLaunch: @escaping @Sendable () async -> CreateInstallMediaOutcome?,
            report: @escaping @Sendable (CreateInstallMediaUpdate) -> Void
        ) async -> CreateInstallMediaRunResult {
            await calls.add("prepare")
            if case .invalidInstaller = result {
                await calls.add("invalid installer")
                return .invalidInstaller
            }
            if let refusal = await beforeLaunch() { return .refused(refusal) }
            await calls.add("run")
            return result
        }
        func cancel() async {}
    }

    private actor BlockingRunner: InstallMediaRunning {
        private var resultContinuation: CheckedContinuation<CreateInstallMediaRunResult, Never>?
        private var startContinuation: CheckedContinuation<Void, Never>?
        private(set) var didStart = false
        private(set) var didCancel = false
        private(set) var cancellation: CreateInstallMediaCancellation?

        func create(
            installerURL: URL, installerPackageURL: URL?, volumeURL: URL,
            cancellation: CreateInstallMediaCancellation,
            beforeLaunch: @escaping @Sendable () async -> CreateInstallMediaOutcome?,
            report: @escaping @Sendable (CreateInstallMediaUpdate) -> Void
        ) async -> CreateInstallMediaRunResult {
            if let refusal = await beforeLaunch() { return .refused(refusal) }
            return await withCheckedContinuation { continuation in
                resultContinuation = continuation
                self.cancellation = cancellation
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

    private static let disk = DiskDescription(
        bsdName: "disk4", isWhole: true, isRemovable: true, deviceProtocol: "USB", mediaUUID: "uuid",
        serialNumber: "serial", size: 32_000_000_000)
    private static let volumeURL = URL(filePath: "/Volumes/USB")

    private func pipeline(
        authorized: Bool = true, disk: DiskDescription? = Self.disk,
        volume: DiskDescription? = DiskDescription(
            bsdName: "disk4s1", isWhole: false, mountPoint: Self.volumeURL),
        result: CreateInstallMediaRunResult = .created, writeAllowed: Bool = true, calls: CallLog,
        runner: (any InstallMediaRunning)? = nil
    ) -> CreateInstallMediaPipeline {
        CreateInstallMediaPipeline(
            authorization: Authorization(allowed: authorized, calls: calls), disks: Disks(disk: disk, calls: calls),
            volumes: Volumes(volume: volume, calls: calls), runner: runner ?? Runner(result: result, calls: calls),
            volumeWriteChecker: WriteChecker(allowed: writeAllowed, calls: calls))
    }

    private func request(volumeURL: URL = Self.volumeURL, bsdName: String = "disk4") -> CreateInstallMediaRequest {
        CreateInstallMediaRequest(
            bsdName: bsdName, fingerprint: DiskFingerprint(Self.disk),
            installerURL: URL(filePath: "/Applications/Install macOS Test.app"), volumeURL: volumeURL,
            authorization: Data([1]))
    }

    @Test func `authorization is checked before disk, volume, or process`() async {
        let calls = CallLog()
        #expect(await pipeline(authorized: false, calls: calls).create(request(), report: { _ in }) == .notAuthorized)
        #expect(await calls.entries == ["authorization"])
    }

    @Test func `invalid installer stops before the runner launches a command`() async {
        let calls = CallLog()
        #expect(
            await pipeline(result: .invalidInstaller, calls: calls).create(request(), report: { _ in })
                == .invalidInstaller)
        #expect(
            await calls.entries == ["authorization", "disk", "volume", "write", "prepare", "invalid installer"])
    }

    @Test func `invalid disk identifier is rejected before disk access`() async {
        let calls = CallLog()
        let result = await pipeline(calls: calls).create(request(bsdName: "disk4s1"), report: { _ in })
        #expect(result == .invalidIdentifier)
        #expect(await calls.entries == ["authorization"])
    }

    @Test func `create command failure remains a failure while the drive stays connected`() async {
        let calls = CallLog()
        #expect(await pipeline(result: .failed, calls: calls).create(request(), report: { _ in }) == .createFailed)
        #expect(await calls.entries.suffix(2) == ["run", "disk"])
    }

    @Test func `a disconnected drive is rejected before the command`() async {
        let calls = CallLog()
        #expect(await pipeline(disk: nil, calls: calls).create(request(), report: { _ in }) == .driveDisconnected)
        #expect(await calls.entries == ["authorization", "disk"])
    }

    @Test func `a volume from another disk never reaches the installer process`() async {
        let calls = CallLog()
        let otherVolume = DiskDescription(
            bsdName: "disk5s1", isWhole: false, mountPoint: Self.volumeURL)
        #expect(await pipeline(volume: otherVolume, calls: calls).create(request(), report: { _ in }) == .invalidVolume)
        #expect(await calls.entries == ["authorization", "disk", "volume"])
    }

    @Test func `valid authorized disk and mounted volume reach createinstallmedia`() async {
        let calls = CallLog()
        #expect(await pipeline(calls: calls).create(request(), report: { _ in }) == .created)
        #expect(
            await calls.entries == [
                "authorization", "disk", "volume", "write", "prepare", "authorization", "disk", "volume",
                "write", "run",
            ])
    }

    @Test func `a denied helper write check prevents createinstallmedia`() async {
        let calls = CallLog()
        #expect(
            await pipeline(writeAllowed: false, calls: calls).create(request(), report: { _ in }) == .volumeAccessDenied
        )
        #expect(await calls.entries == ["authorization", "disk", "volume", "write"])
    }

    @Test func `the drive fingerprint is checked before the command`() async {
        let calls = CallLog()
        let replaced = DiskDescription(
            bsdName: "disk4", isWhole: true, isRemovable: true, deviceProtocol: "USB", mediaUUID: "other",
            serialNumber: "serial", size: 32_000_000_000)
        #expect(await pipeline(disk: replaced, calls: calls).create(request(), report: { _ in }) == .driveChanged)
        #expect(await calls.entries == ["authorization", "disk"])
    }

    @Test func `cancellation reaches the active installer runner`() async {
        let calls = CallLog()
        let runner = BlockingRunner()
        let pipeline = pipeline(calls: calls, runner: runner)
        let operation = Task { await pipeline.create(request(), report: { _ in }) }

        await runner.waitUntilStarted()
        await pipeline.cancel()

        #expect(await operation.value == .createFailed)
        #expect(await runner.didCancel)
        #expect(await runner.cancellation?.isRequested == true)
    }

    @Test func `cancellation while checking volume access prevents the runner from starting`() async {
        let calls = CallLog()
        let writer = BlockingWriteChecker()
        let runner = Runner(result: .created, calls: calls)
        let pipeline = CreateInstallMediaPipeline(
            authorization: Authorization(allowed: true, calls: calls), disks: Disks(disk: Self.disk, calls: calls),
            volumes: Volumes(
                volume: DiskDescription(bsdName: "disk4s1", isWhole: false, mountPoint: Self.volumeURL), calls: calls),
            runner: runner, volumeWriteChecker: writer)
        let operation = Task { await pipeline.create(request(), report: { _ in }) }

        await writer.waitUntilStarted()
        await pipeline.cancel()
        await writer.allow()

        #expect(await operation.value == .createFailed)
        #expect(await writer.didStart)
        #expect(await calls.entries == ["authorization", "disk", "volume"])
    }
}
