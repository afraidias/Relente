import Foundation
import Testing
import os

@testable import Relente

struct LiveCreateInstallMediaRunnerTests {

    @Test func `runs the validated executable with fixed arguments and reports output`() async throws {
        let installer = try InstallerFixture()
        defer { installer.remove() }
        let volume = URL(filePath: "/Volumes/Relente Test")
        let process = FakeInstallMediaProcess(
            status: 0, output: ["Erasing disk: 0%...", "Copying to disk: 25%"])
        let runner = LiveCreateInstallMediaRunner(
            processRunner: process, verifyAppleSignature: { _, _ in true })
        let updates = OSAllocatedUnfairLock<[CreateInstallMediaUpdate]>(initialState: [])

        let result = await runner.create(
            installerURL: installer.appURL, installerPackageURL: nil, volumeURL: volume,
            cancellation: CreateInstallMediaCancellation(), beforeLaunch: { nil },
            report: { update in updates.withLock { $0.append(update) } })

        guard case .created = result else {
            Issue.record("A zero process status should create the installer")
            return
        }
        let invocation = try #require(await process.invocation())
        #expect(invocation.executableURL == installer.executableURL)
        #expect(invocation.arguments == ["--volume", volume.path, "--nointeraction"])
        let reported = updates.withLock { $0 }
        #expect(reported.map(\.outputLine) == ["Erasing disk: 0%...", "Copying to disk: 25%"])
        #expect(reported.map(\.progress?.phase) == [.erase, .copy])
        #expect(reported.map(\.progress?.fraction) == [0, 0.25])
    }

    @Test func `a nonzero process status becomes a failed run`() async throws {
        let installer = try InstallerFixture()
        defer { installer.remove() }
        let process = FakeInstallMediaProcess(status: 2, output: [])
        let runner = LiveCreateInstallMediaRunner(
            processRunner: process, verifyAppleSignature: { _, _ in true })

        let result = await runner.create(
            installerURL: installer.appURL, installerPackageURL: nil,
            volumeURL: URL(filePath: "/Volumes/Relente Test"),
            cancellation: CreateInstallMediaCancellation(), beforeLaunch: { nil }, report: { _ in })

        guard case .failed = result else {
            Issue.record("A nonzero process status must fail creation")
            return
        }
    }

    @Test func `cancellation terminates the active process`() async throws {
        let installer = try InstallerFixture()
        defer { installer.remove() }
        let process = BlockingInstallMediaProcess()
        let runner = LiveCreateInstallMediaRunner(
            processRunner: process, verifyAppleSignature: { _, _ in true })
        let creation = Task {
            await runner.create(
                installerURL: installer.appURL, installerPackageURL: nil,
                volumeURL: URL(filePath: "/Volumes/Relente Test"),
                cancellation: CreateInstallMediaCancellation(), beforeLaunch: { nil }, report: { _ in })
        }

        await process.waitUntilStarted()
        await runner.cancel()
        let result = await creation.value

        guard case .failed = result else {
            Issue.record("A terminated process must fail creation")
            return
        }
        #expect(await process.cancelCount() == 1)
    }
}

private struct InstallerFixture {
    let rootURL: URL
    let appURL: URL
    let executableURL: URL

    init() throws {
        rootURL = URL(filePath: "/private/tmp/Relente-Runner-\(UUID().uuidString)")
        appURL = rootURL.appending(path: "Install macOS Sample.app", directoryHint: .isDirectory)
        executableURL = appURL.appending(path: "Contents/Resources/createinstallmedia")
        try FileManager.default.createDirectory(
            at: executableURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data().write(to: executableURL)
    }

    func remove() {
        try? FileManager.default.removeItem(at: rootURL)
    }
}

private actor FakeInstallMediaProcess: CreateInstallMediaProcessRunning {
    private let status: Int32
    private let output: [String]
    private var lastInvocation: CreateInstallMediaInvocation?

    init(status: Int32, output: [String]) {
        self.status = status
        self.output = output
    }

    func run(
        _ invocation: CreateInstallMediaInvocation,
        reportOutput: @escaping @Sendable (String) -> Void
    ) async -> Int32 {
        lastInvocation = invocation
        output.forEach(reportOutput)
        return status
    }

    func invocation() -> CreateInstallMediaInvocation? {
        lastInvocation
    }

    func cancel() async {}
}

private actor BlockingInstallMediaProcess: CreateInstallMediaProcessRunning {
    private let (started, startedContinuation) = AsyncStream.makeStream(of: Void.self)
    private var completion: CheckedContinuation<Int32, Never>?
    private var cancellations = 0

    func run(
        _ invocation: CreateInstallMediaInvocation,
        reportOutput: @escaping @Sendable (String) -> Void
    ) async -> Int32 {
        startedContinuation.yield(())
        return await withCheckedContinuation { completion = $0 }
    }

    func cancel() async {
        cancellations += 1
        completion?.resume(returning: -1)
        completion = nil
    }

    func waitUntilStarted() async {
        for await _ in started { break }
    }

    func cancelCount() -> Int {
        cancellations
    }
}
