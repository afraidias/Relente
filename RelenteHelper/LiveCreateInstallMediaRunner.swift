import Darwin
import Foundation
import Security
import os

#if RELENTE_TESTS
    @testable import Relente
#endif

nonisolated struct CreateInstallMediaInvocation: Sendable, Equatable {
    let executableURL: URL
    let volumeURL: URL

    var arguments: [String] {
        ["--volume", volumeURL.path(percentEncoded: false), "--nointeraction"]
    }
}

nonisolated protocol CreateInstallMediaProcessRunning: Sendable {
    func run(
        _ invocation: CreateInstallMediaInvocation,
        reportOutput: @escaping @Sendable (String) -> Void
    ) async -> Int32
    func cancel() async
}

actor LiveCreateInstallMediaRunner: InstallMediaRunning {
    private static let logger = Logger(subsystem: "com.afraidias.Relente", category: "helper")
    private let processRunner: any CreateInstallMediaProcessRunning
    private let verifyAppleSignature: @Sendable (URL, Bool) -> Bool
    private let readIdentity: @Sendable (URL, CreateInstallMediaCancellation) async throws -> InstallerOSIdentity

    init(
        processRunner: any CreateInstallMediaProcessRunning = PseudoTerminalCreateInstallMediaProcess(),
        verifyAppleSignature: @escaping @Sendable (URL, Bool) -> Bool = { url, resources in
            AppleInstallerCodeSignature.isValid(url, validateResources: resources)
        },
        readIdentity: @escaping @Sendable (URL, CreateInstallMediaCancellation) async throws -> InstallerOSIdentity = {
            app, cancellation in try await LiveCreateInstallMediaRunner.readOSIdentity(app, cancellation: cancellation)
        }
    ) {
        self.processRunner = processRunner
        self.verifyAppleSignature = verifyAppleSignature
        self.readIdentity = readIdentity
    }

    func create(
        installerURL: URL, installerPackageURL: URL?, expectedIdentity: InstallerOSIdentity? = nil, volumeURL: URL,
        cancellation: CreateInstallMediaCancellation,
        beforeLaunch: @escaping @Sendable () async -> CreateInstallMediaOutcome?,
        report: @escaping @Sendable (CreateInstallMediaUpdate) -> Void
    ) async -> CreateInstallMediaRunResult {
        let installer: URL
        var preparedPackage: PreparedInstallerPackage?
        var mount: InstallerImageMount?

        if let installerPackageURL {
            let prepared: PreparedInstallerPackage
            do {
                prepared = try await InstallerPackagePreparer.prepare(
                    installerPackageURL, isCancelled: { cancellation.isRequested })
            } catch InstallerPackagePreparer.PreparationError.cancelled {
                return .failed
            } catch InstallerPackagePreparer.PreparationError.recoveryRequired {
                return .recoveryRequired
            } catch InstallerPackagePreparer.PreparationError.cleanupFailed {
                return .recoveryRequired
            } catch {
                return .invalidInstaller
            }
            preparedPackage = prepared
            guard !cancellation.isRequested else { return prepared.remove() ? .failed : .recoveryRequired }
            let matchesSelectedPath =
                prepared.appURL.lastPathComponent == installerURL.lastPathComponent
                || (installerURL.pathExtension.lowercased() == "pkg" && installerURL == installerPackageURL)
            guard Self.isRootOwnedPreparedPackage(prepared), matchesSelectedPath else {
                return prepared.remove() ? .invalidInstaller : .recoveryRequired
            }
            installer = prepared.appURL
        } else {
            guard let resolved = await installerApp(at: installerURL) else { return .invalidInstaller }
            installer = resolved.app
            mount = resolved.mount
            guard !cancellation.isRequested else { return .failed }
        }

        let stagedPackageURL = preparedPackage?.packageURL
        let result = await InstallerImageMounter.withCleanup(of: mount, run: Self.run) {
            await self.create(
                installer: installer, installerPackageURL: stagedPackageURL, expectedIdentity: expectedIdentity,
                volumeURL: volumeURL,
                cancellation: cancellation, beforeLaunch: beforeLaunch, report: report)
        }
        if case .recoveryRequired = result { return result }
        guard preparedPackage?.remove() ?? true else { return .recoveryRequired }
        return result
    }

    private func create(
        installer: URL, installerPackageURL: URL?, expectedIdentity: InstallerOSIdentity?, volumeURL: URL,
        cancellation: CreateInstallMediaCancellation,
        beforeLaunch: @escaping @Sendable () async -> CreateInstallMediaOutcome?,
        report: @escaping @Sendable (CreateInstallMediaUpdate) -> Void
    ) async -> CreateInstallMediaRunResult {
        let executable = installer.appending(path: "Contents/Resources/createinstallmedia")
        if let failure = await installerValidationFailure(
            installer, executable: executable, packageURL: installerPackageURL, cancellation: cancellation)
        {
            return failure
        }
        if let expectedIdentity {
            do {
                let actual = try await readIdentity(installer, cancellation)
                guard actual == expectedIdentity else { return .invalidInstaller }
            } catch InstallerSupportMetadata.Failure.recoveryRequired {
                return .recoveryRequired
            } catch is CancellationError { return .failed } catch { return .invalidInstaller }
        }
        let refusal = await beforeLaunch()
        guard !cancellation.isRequested else { return .failed }
        if let refusal { return .refused(refusal) }
        if let failure = await installerValidationFailure(
            installer, executable: executable, packageURL: installerPackageURL, cancellation: cancellation)
        {
            return failure
        }

        Self.logger.info("Starting createinstallmedia for \(volumeURL.lastPathComponent, privacy: .public)")
        let copyPhase = OSAllocatedUnfairLock<CreateInstallMediaPhase?>(initialState: nil)
        let reportOutput: @Sendable (CreateInstallMediaUpdate) -> Void = { update in
            if let phase = update.progress?.phase {
                copyPhase.withLock { $0 = phase }
            }
            report(update)
        }
        let copyMonitor = Task {
            await Self.monitorCopyProgress(
                installer: installer, volume: volumeURL, phase: copyPhase, report: reportOutput)
        }
        let status = await processRunner.run(
            CreateInstallMediaInvocation(executableURL: executable, volumeURL: volumeURL)
        ) { line in
            let update = CreateInstallMediaUpdate(
                progress: CreateInstallMediaOutputParser.progress(in: line), outputLine: line, timestamp: .now)
            reportOutput(update)
        }
        copyMonitor.cancel()
        await copyMonitor.value
        Self.logger.info("createinstallmedia ended with status \(status, privacy: .public)")
        return status == 0 ? .created : .failed
    }

    func cancel() async {
        await processRunner.cancel()
    }

    private func installerApp(at source: URL) async -> (app: URL, mount: InstallerImageMount?)? {
        guard InstallerPathSafety.isSafe(source) else { return nil }
        if source.pathExtension.lowercased() == "app" { return (source, nil) }
        guard source.pathExtension.lowercased() == "dmg", let mounted = await mountImage(source) else { return nil }
        guard
            let app = try? FileManager.default.contentsOfDirectory(
                at: mounted.url, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles]
            ).first(where: { $0.pathExtension == "app" && $0.lastPathComponent.hasPrefix("Install ") })
        else {
            detach(mounted)
            return nil
        }
        return (app, mounted.isOwned ? mounted : nil)
    }

    private func mountImage(_ image: URL) async -> InstallerImageMount? {
        InstallerImageMounter.mount(image, run: Self.run)
    }

    private func detach(_ mount: InstallerImageMount?) {
        InstallerImageMounter.detach(mount, run: Self.run)
    }

    private static func monitorCopyProgress(
        installer: URL, volume: URL, phase: OSAllocatedUnfairLock<CreateInstallMediaPhase?>,
        report: @escaping @Sendable (CreateInstallMediaUpdate) -> Void
    ) async {
        var rateEstimator = InstallerCopyRateEstimator()
        while !Task.isCancelled {
            do {
                try await Task.sleep(for: .seconds(1))
            } catch {
                return
            }
            guard phase.withLock({ $0 == .copy }),
                let measurement = InstallerCopyProgressReader.measure(
                    sourceInstaller: installer, destinationVolume: volume)
            else { continue }
            let timestamp = Date.now
            let rate = rateEstimator.record(measurement, at: timestamp)
            let update = CreateInstallMediaUpdate(
                progress: CreateInstallMediaProgress(phase: .copy, fraction: measurement.fraction),
                outputLine: nil, timestamp: timestamp,
                copyMeasurement: measurement, copyBytesPerSecond: rate)
            report(update)
        }
    }

    @concurrent
    private static func readOSIdentity(_ app: URL, cancellation: CreateInstallMediaCancellation) async throws
        -> InstallerOSIdentity
    {
        let folder = try InstallerPrivateDirectory.create()
        do {
            let identity = try await InstallerSupportMetadata.identity(
                in: app.appending(path: "Contents/SharedSupport/SharedSupport.dmg"), workingDirectory: folder,
                isCancelled: { cancellation.isRequested })
            try FileManager.default.removeItem(at: folder)
            return identity
        } catch InstallerSupportMetadata.Failure.recoveryRequired {
            throw InstallerSupportMetadata.Failure.recoveryRequired(folder)
        } catch {
            do { try FileManager.default.removeItem(at: folder) } catch {
                throw InstallerSupportMetadata.Failure.recoveryRequired(folder)
            }
            throw error
        }
    }

    private func installerValidationFailure(
        _ installer: URL, executable: URL, packageURL: URL?,
        cancellation: CreateInstallMediaCancellation
    ) async
        -> CreateInstallMediaRunResult?
    {
        do {
            let packageBacked: Bool
            if let packageURL {
                guard
                    try await Self.isTrustedPreparedPackage(
                        packageURL, app: installer, isCancelled: { cancellation.isRequested })
                else {
                    return .invalidInstaller
                }
                packageBacked = true
            } else {
                packageBacked = false
            }
            return InstallerCodeSignaturePolicy.isValid(
                installer: installer, executable: executable, packageBacked: packageBacked,
                verifyAppleSignature: verifyAppleSignature) ? nil : .invalidInstaller
        } catch InstallerCommand.Failure.lostProcess { return .recoveryRequired } catch is CancellationError {
            return .failed
        } catch { return .invalidInstaller }
    }

    private static func isTrustedPreparedPackage(
        _ package: URL, app: URL,
        isCancelled: @Sendable () -> Bool
    ) async throws -> Bool {
        guard InstallerPackageProvenance.hasExpectedPreparedLayout(package: package, app: app),
            isRootOwnedPrivateDirectory(package.deletingLastPathComponent()), isRootOwned(package), isRootOwned(app),
            InstallerPathSafety.isSafe(package)
        else { return false }
        let output = try await InstallerCommand.verifyPackage(package)
            .run(in: package.deletingLastPathComponent(), timeout: 60, isCancelled: isCancelled)
        guard let text = String(data: output, encoding: .utf8) else { return false }
        return InstallerPackageProvenance.hasAppleSoftwareUpdateSignature(text)
    }

    private static func isRootOwnedPreparedPackage(_ prepared: PreparedInstallerPackage) -> Bool {
        InstallerPackageProvenance.hasExpectedPreparedLayout(package: prepared.packageURL, app: prepared.appURL)
            && isRootOwnedPrivateDirectory(prepared.temporaryDirectory)
            && isRootOwned(prepared.packageURL)
            && isRootOwned(prepared.appURL)
    }

    private static func isRootOwnedPrivateDirectory(_ url: URL) -> Bool {
        var info = stat()
        return lstat(url.path, &info) == 0
            && InstallerPackageOwnershipPolicy.isPrivateRootDirectory(owner: info.st_uid, mode: info.st_mode)
    }

    private static func isRootOwned(_ url: URL) -> Bool {
        var info = stat()
        return lstat(url.path, &info) == 0
            && InstallerPackageOwnershipPolicy.isRootOwnedEntry(owner: info.st_uid, mode: info.st_mode)
    }

    private static func run(_ executable: String, _ arguments: [String]) -> Data? {
        let process = Process()
        process.executableURL = URL(filePath: executable)
        var environment = ProcessInfo.processInfo.environment
        environment["LC_ALL"] = "C"
        environment["LANG"] = "C"
        process.environment = environment
        process.arguments = arguments
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return nil }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return process.terminationStatus == 0 ? data : nil
    }
}

actor PseudoTerminalCreateInstallMediaProcess: CreateInstallMediaProcessRunning {
    private var process: Process?

    func run(
        _ invocation: CreateInstallMediaInvocation,
        reportOutput: @escaping @Sendable (String) -> Void
    ) async -> Int32 {
        var masterDescriptor: Int32 = -1
        var slaveDescriptor: Int32 = -1
        guard openpty(&masterDescriptor, &slaveDescriptor, nil, nil, nil) == 0 else { return -1 }
        let master = FileHandle(fileDescriptor: masterDescriptor, closeOnDealloc: true)
        let slave = FileHandle(fileDescriptor: slaveDescriptor, closeOnDealloc: true)
        let process = Process()
        process.executableURL = invocation.executableURL
        process.arguments = invocation.arguments
        process.standardInput = slave
        process.standardOutput = slave
        process.standardError = slave
        self.process = process
        defer { self.process = nil }

        let reader = Task { await Self.readOutput(from: master, report: reportOutput) }
        let status = await withCheckedContinuation { continuation in
            process.terminationHandler = { process in
                continuation.resume(returning: process.terminationReason == .exit ? process.terminationStatus : -1)
            }
            do {
                try process.run()
                try? slave.close()
            } catch {
                try? slave.close()
                process.terminationHandler = nil
                continuation.resume(returning: -1)
            }
        }
        await reader.value
        try? master.close()
        return status
    }

    func cancel() {
        guard let process, process.isRunning else { return }
        process.terminate()
    }

    private static func readOutput(from handle: FileHandle, report: @escaping @Sendable (String) -> Void) async {
        var line = Data()
        do {
            for try await byte in handle.bytes {
                if byte == 10 || byte == 13 {
                    emit(line, report: report)
                    line.removeAll(keepingCapacity: true)
                } else if line.count < 8192 {
                    line.append(byte)
                }
            }
        } catch {
            emit(line, report: report)
        }
        emit(line, report: report)
    }

    private static func emit(_ data: Data, report: @Sendable (String) -> Void) {
        guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
        report(text)
    }
}
