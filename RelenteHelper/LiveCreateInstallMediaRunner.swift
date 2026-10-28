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

    init(
        processRunner: any CreateInstallMediaProcessRunning = PseudoTerminalCreateInstallMediaProcess(),
        verifyAppleSignature: @escaping @Sendable (URL, Bool) -> Bool = { url, resources in
            hasAppleCodeSignature(url, validateResources: resources)
        }
    ) {
        self.processRunner = processRunner
        self.verifyAppleSignature = verifyAppleSignature
    }

    func create(
        installerURL: URL, installerPackageURL: URL?, volumeURL: URL,
        cancellation: CreateInstallMediaCancellation,
        beforeLaunch: @escaping @Sendable () async -> CreateInstallMediaOutcome?,
        report: @escaping @Sendable (CreateInstallMediaUpdate) -> Void
    ) async -> CreateInstallMediaRunResult {
        let installer: URL
        var preparedPackage: PreparedInstallerPackage?
        var mount: InstallerImageMount?
        defer { preparedPackage?.remove() }

        if let installerPackageURL {
            let prepared: PreparedInstallerPackage
            do {
                prepared = try await InstallerPackagePreparer.prepare(
                    installerPackageURL, isCancelled: { cancellation.isRequested })
            } catch InstallerPackagePreparer.PreparationError.cancelled {
                return .failed
            } catch {
                return .invalidInstaller
            }
            preparedPackage = prepared
            guard !cancellation.isRequested else { return .failed }
            guard Self.isRootOwnedPreparedPackage(prepared),
                prepared.appURL.lastPathComponent == installerURL.lastPathComponent
            else {
                return .invalidInstaller
            }
            installer = prepared.appURL
        } else {
            guard let resolved = await installerApp(at: installerURL) else { return .invalidInstaller }
            installer = resolved.app
            mount = resolved.mount
            guard !cancellation.isRequested else { return .failed }
        }

        return await InstallerImageMounter.withCleanup(of: mount, run: Self.run) {
            await self.create(
                installer: installer, installerPackageURL: installerPackageURL, volumeURL: volumeURL,
                cancellation: cancellation, beforeLaunch: beforeLaunch, report: report)
        }
    }

    private func create(
        installer: URL, installerPackageURL: URL?, volumeURL: URL,
        cancellation: CreateInstallMediaCancellation,
        beforeLaunch: @escaping @Sendable () async -> CreateInstallMediaOutcome?,
        report: @escaping @Sendable (CreateInstallMediaUpdate) -> Void
    ) async -> CreateInstallMediaRunResult {
        let executable = installer.appending(path: "Contents/Resources/createinstallmedia")
        guard isValidInstaller(installer, executable: executable, packageURL: installerPackageURL) else {
            return .invalidInstaller
        }
        let refusal = await beforeLaunch()
        guard !cancellation.isRequested else { return .failed }
        if let refusal { return .refused(refusal) }
        guard isValidInstaller(installer, executable: executable, packageURL: installerPackageURL) else {
            return .invalidInstaller
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

    nonisolated private static func hasAppleCodeSignature(_ url: URL, validateResources: Bool) -> Bool {
        var staticCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &staticCode) == errSecSuccess,
            let staticCode
        else { return false }
        var requirement: SecRequirement?
        guard SecRequirementCreateWithString("anchor apple" as CFString, [], &requirement) == errSecSuccess,
            let requirement
        else { return false }
        let flags: SecCSFlags = validateResources ? [] : SecCSFlags(rawValue: kSecCSDoNotValidateResources)
        return SecStaticCodeCheckValidity(staticCode, flags, requirement) == errSecSuccess
    }

    private func isValidInstaller(_ installer: URL, executable: URL, packageURL: URL?) -> Bool {
        let packageBacked = packageURL.map { Self.isTrustedPreparedPackage($0, app: installer) } ?? false
        return InstallerCodeSignaturePolicy.isValid(
            installer: installer, executable: executable, packageBacked: packageBacked,
            verifyAppleSignature: verifyAppleSignature)
    }

    private static func isTrustedPreparedPackage(_ package: URL, app: URL) -> Bool {
        guard InstallerPackageProvenance.hasExpectedPreparedLayout(package: package, app: app),
            isRootOwnedPrivateDirectory(package.deletingLastPathComponent()), isRootOwned(package), isRootOwned(app),
            InstallerPathSafety.isSafe(package)
        else { return false }
        guard let output = run("/usr/sbin/pkgutil", ["--check-signature", package.path(percentEncoded: false)]),
            let text = String(data: output, encoding: .utf8)
        else { return false }
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
