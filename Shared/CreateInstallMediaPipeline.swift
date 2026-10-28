import Darwin
import Foundation
import os

nonisolated struct CreateInstallMediaRequest: Sendable {
    let bsdName: String
    let fingerprint: DiskFingerprint
    let installerURL: URL
    var installerPackageURL: URL? = nil
    let volumeURL: URL
    let authorization: Data
}

nonisolated enum InstallerPackageProvenance {
    static func hasAppleSoftwareUpdateSignature(_ output: String) -> Bool {
        let lines = output.lowercased().split(whereSeparator: \.isNewline).map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        return lines.contains("status: signed apple software")
            && lines.contains(where: { $0.hasPrefix("1. software update") })
            && lines.contains(where: { $0.hasPrefix("2. apple software update certification authority") })
            && lines.contains(where: { $0.hasPrefix("3. apple root ca") })
    }

    static func hasExpectedPreparedLayout(package: URL, app: URL) -> Bool {
        let directory = package.deletingLastPathComponent()
        return package.lastPathComponent == "InstallAssistant.pkg"
            && directory.lastPathComponent.hasPrefix("Relente-")
            && app.path.hasPrefix(directory.appending(path: "expanded").path + "/")
    }
}

nonisolated enum InstallerPathSafety {
    static func isSafe(_ url: URL) -> Bool {
        guard url.isFileURL else { return false }
        let path = url.path
        let components = path.split(separator: "/")
        guard path.hasPrefix("/"), !components.contains("."), !components.contains("..") else { return false }
        var current = "/"
        for component in components {
            current = current == "/" ? "/\(component)" : "\(current)/\(component)"
            var info = stat()
            guard lstat(current, &info) == 0, (info.st_mode & S_IFMT) != S_IFLNK else { return false }
        }
        return true
    }
}

nonisolated struct InstallerImageMount: Sendable {
    let url: URL
    let device: String?
    let isOwned: Bool

    var deviceToDetach: String? {
        isOwned ? device : nil
    }

    func detach(using action: (String) -> Void) {
        guard let deviceToDetach else { return }
        action(deviceToDetach)
    }
}

nonisolated final class HelperOperationGate: Sendable {
    private let active = OSAllocatedUnfairLock<UUID?>(initialState: nil)

    func begin(owner: UUID) -> Bool {
        active.withLock { activeOwner in
            guard activeOwner == nil else { return false }
            activeOwner = owner
            return true
        }
    }

    func end(owner: UUID) {
        active.withLock { activeOwner in
            guard activeOwner == owner else { return }
            activeOwner = nil
        }
    }

    var isActive: Bool {
        active.withLock { $0 != nil }
    }

    func owns(_ owner: UUID) -> Bool {
        active.withLock { $0 == owner }
    }
}

nonisolated enum CreateInstallMediaRunResult: Sendable {
    case created
    case invalidInstaller
    case refused(CreateInstallMediaOutcome)
    case failed
}

nonisolated final class CreateInstallMediaCancellation: Sendable {
    private let requested = OSAllocatedUnfairLock(initialState: false)

    var isRequested: Bool { requested.withLock { $0 } }

    func cancel() {
        requested.withLock { $0 = true }
    }
}

nonisolated protocol InstallMediaRunning: Sendable {
    func create(
        installerURL: URL, installerPackageURL: URL?, volumeURL: URL,
        cancellation: CreateInstallMediaCancellation,
        beforeLaunch: @escaping @Sendable () async -> CreateInstallMediaOutcome?,
        report: @escaping @Sendable (CreateInstallMediaUpdate) -> Void
    ) async -> CreateInstallMediaRunResult
    func cancel() async
}

nonisolated protocol VolumeReading: Sendable {
    func describeVolume(at path: URL) async -> DiskDescription?
}

nonisolated protocol VolumeWriteChecking: Sendable {
    func canWrite(to volume: URL) async -> Bool
}

actor CreateInstallMediaPipeline {
    private let authorization: any AuthorizationChecking
    private let disks: any DiskReading
    private let volumes: any VolumeReading
    private let runner: any InstallMediaRunning
    private let volumeWriteChecker: any VolumeWriteChecking
    private var isRunning = false
    private var activeCancellation: CreateInstallMediaCancellation?

    init(
        authorization: any AuthorizationChecking, disks: any DiskReading,
        volumes: any VolumeReading, runner: any InstallMediaRunning, volumeWriteChecker: any VolumeWriteChecking
    ) {
        self.authorization = authorization
        self.disks = disks
        self.volumes = volumes
        self.runner = runner
        self.volumeWriteChecker = volumeWriteChecker
    }

    func checkWriteAccess(_ request: CreateInstallMediaRequest) async -> CreateInstallMediaOutcome {
        guard !isRunning else { return .busy }
        guard await authorization.isAuthorized(request.authorization) else { return .notAuthorized }
        guard EraseRequestCheck.isValidIdentifier(request.bsdName) else { return .invalidIdentifier }
        guard let disk = await disks.describe(request.bsdName) else { return .driveDisconnected }
        if let refusal = await diskRefusal(disk, request: request) { return refusal }
        guard await validVolume(request.volumeURL, on: request.bsdName) else { return .invalidVolume }
        return await volumeWriteChecker.canWrite(to: request.volumeURL) ? .created : .volumeAccessDenied
    }

    func create(
        _ request: CreateInstallMediaRequest,
        report: @escaping @Sendable (CreateInstallMediaUpdate) -> Void
    ) async -> CreateInstallMediaOutcome {
        guard !isRunning else { return .busy }
        isRunning = true
        let cancellation = CreateInstallMediaCancellation()
        activeCancellation = cancellation
        defer {
            activeCancellation = nil
            isRunning = false
        }

        guard await authorization.isAuthorized(request.authorization) else { return .notAuthorized }
        guard EraseRequestCheck.isValidIdentifier(request.bsdName) else { return .invalidIdentifier }
        guard let disk = await disks.describe(request.bsdName) else { return .driveDisconnected }
        if let refusal = await diskRefusal(disk, request: request) { return refusal }
        guard await validVolume(request.volumeURL, on: request.bsdName) else { return .invalidVolume }
        guard await volumeWriteChecker.canWrite(to: request.volumeURL) else { return .volumeAccessDenied }
        guard !cancellation.isRequested else { return .createFailed }

        let result = await runner.create(
            installerURL: request.installerURL, installerPackageURL: request.installerPackageURL,
            volumeURL: request.volumeURL, cancellation: cancellation,
            beforeLaunch: { await self.preflightFailure(for: request) }, report: report)
        switch result {
        case .created:
            return .created
        case .invalidInstaller:
            return .invalidInstaller
        case .refused(let refusal):
            return refusal
        case .failed:
            return await disks.describe(request.bsdName) == nil ? .driveDisconnected : .createFailed
        }
    }

    func cancel() async {
        guard isRunning else { return }
        activeCancellation?.cancel()
        await runner.cancel()
    }

    private func diskRefusal(_ disk: DiskDescription, request: CreateInstallMediaRequest) async
        -> CreateInstallMediaOutcome?
    {
        guard
            let refusal = EraseRequestCheck.check(
                disk, requested: request.bsdName, confirmed: request.fingerprint, bootDisks: await disks.bootDisks())
        else { return nil }
        return switch refusal {
        case .formatted: .createFailed
        case .driveNotAllowed: .driveNotAllowed
        case .driveChanged: .driveChanged
        case .driveDisconnected: .driveDisconnected
        case .invalidIdentifier: .invalidIdentifier
        case .formatFailed, .notAuthorized, .busy: .createFailed
        }
    }

    private func preflightFailure(for request: CreateInstallMediaRequest) async -> CreateInstallMediaOutcome? {
        guard await authorization.isAuthorized(request.authorization) else { return .notAuthorized }
        guard EraseRequestCheck.isValidIdentifier(request.bsdName) else { return .invalidIdentifier }
        guard let disk = await disks.describe(request.bsdName) else { return .driveDisconnected }
        if let refusal = await diskRefusal(disk, request: request) { return refusal }
        guard await validVolume(request.volumeURL, on: request.bsdName) else { return .invalidVolume }
        guard await volumeWriteChecker.canWrite(to: request.volumeURL) else { return .volumeAccessDenied }
        return nil
    }

    private func validVolume(_ path: URL, on diskName: String) async -> Bool {
        guard let volume = await volumes.describeVolume(at: path),
            volume.mountPoint?.standardizedFileURL == path.standardizedFileURL
        else { return false }
        return volume.wholeDiskName == diskName || volume.physicalWholeDisk == diskName
    }
}
