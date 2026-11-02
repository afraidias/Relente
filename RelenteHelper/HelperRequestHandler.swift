//
//  HelperRequestHandler.swift
//  RelenteHelper
//
//  The object the app talks to over one XPC connection. It handles typed erase/create requests,
//  and stops the active operation if the app goes away.
//  Spec: specs/008-system-helper/spec.md
//

import Darwin
import Foundation
import os

#if RELENTE_TESTS
    @testable import Relente
#endif

nonisolated final class HelperRequestHandler: NSObject, HelperProtocol, Sendable {

    private static let logger = Logger(subsystem: "com.afraidias.Relente", category: "helper")
    private static let operationGate = HelperOperationGate()
    private let connectionID = UUID()
    private let pipeline: FormatPipeline
    private let creationPipeline: CreateInstallMediaPipeline
    private let progress: OSAllocatedUnfairLock<ProgressProxy?>
    private let callerUID: UInt32

    init(
        pipeline: FormatPipeline, creationPipeline: CreateInstallMediaPipeline,
        progress: HelperProgressProtocol?, callerUID: UInt32 = 0
    ) {
        self.pipeline = pipeline
        self.creationPipeline = creationPipeline
        self.progress = OSAllocatedUnfairLock(initialState: progress.map(ProgressProxy.init))
        self.callerUID = callerUID
    }

    func protocolVersion(reply: @escaping @Sendable (Int) -> Void) {
        Self.logger.info("Version requested")
        reply(HelperIdentity.protocolVersion)
    }

    func format(
        bsdName: String, mediaUUID: String?, serialNumber: String?, size: Int64, authorization: Data,
        reply: @escaping @Sendable (Int) -> Void
    ) {
        let request = FormatRequest(
            bsdName: bsdName,
            fingerprint: DiskFingerprint(mediaUUID: mediaUUID, serialNumber: serialNumber, size: size),
            authorization: authorization)
        Self.logger.info("Format requested for \(bsdName, privacy: .public)")
        guard Self.operationGate.begin(owner: connectionID) else {
            reply(FormatOutcome.busy.rawValue)
            return
        }
        Task {
            let outcome = await pipeline.format(request)
            Self.operationGate.end(owner: connectionID)
            Self.logger.info(
                "Format of \(bsdName, privacy: .public) ended: \(String(describing: outcome), privacy: .public)")
            reply(outcome.rawValue)
        }
    }

    func createInstallMedia(
        bsdName: String, mediaUUID: String?, serialNumber: String?, size: Int64,
        installerPath: String, installerPackagePath: String?, volumePath: String, authorization: Data,
        reply: @escaping @Sendable (Int) -> Void
    ) {
        let request = CreateInstallMediaRequest(
            bsdName: bsdName,
            fingerprint: DiskFingerprint(mediaUUID: mediaUUID, serialNumber: serialNumber, size: size),
            installerURL: URL(filePath: installerPath),
            installerPackageURL: installerPackagePath.map { URL(filePath: $0) },
            volumeURL: URL(filePath: volumePath),
            authorization: authorization)
        Self.logger.info("createinstallmedia requested for \(bsdName, privacy: .public)")
        guard Self.operationGate.begin(owner: connectionID) else {
            reply(CreateInstallMediaOutcome.busy.rawValue)
            return
        }
        Task {
            defer { Self.operationGate.end(owner: connectionID) }
            let outcome = await creationPipeline.create(request) { update in
                self.progress.withLock { wrapper in
                    wrapper?.proxy.report(
                        phase: update.progress?.phase.rawValue ?? -1,
                        fraction: update.progress?.fraction ?? -1,
                        output: update.outputLine ?? "", timestamp: update.timestamp,
                        copiedBytes: update.copyMeasurement?.copiedBytes ?? -1,
                        totalBytes: update.copyMeasurement?.totalBytes ?? -1,
                        bytesPerSecond: update.copyBytesPerSecond ?? -1)
                }
            }
            Self.logger.info("createinstallmedia ended: \(outcome.rawValue, privacy: .public)")
            reply(outcome.rawValue)
        }
    }

    func checkVolumeWriteAccess(
        bsdName: String, mediaUUID: String?, serialNumber: String?, size: Int64,
        volumePath: String, authorization: Data, reply: @escaping @Sendable (Int) -> Void
    ) {
        guard Self.operationGate.begin(owner: connectionID) else {
            reply(CreateInstallMediaOutcome.busy.rawValue)
            return
        }
        let request = CreateInstallMediaRequest(
            bsdName: bsdName,
            fingerprint: DiskFingerprint(mediaUUID: mediaUUID, serialNumber: serialNumber, size: size),
            installerURL: URL(filePath: "/"), installerPackageURL: nil,
            volumeURL: URL(filePath: volumePath), authorization: authorization)
        Task {
            defer { Self.operationGate.end(owner: connectionID) }
            let outcome = await creationPipeline.checkWriteAccess(request)
            Self.logger.info("Volume access preflight ended: \(outcome.rawValue, privacy: .public)")
            reply(outcome.rawValue)
        }
    }

    func moveIncompleteInstallerToTrash(
        installerPath: String, snapshot: String, reply: @escaping @Sendable (Int) -> Void
    ) {
        let requestID = connectionID
        guard Self.operationGate.begin(owner: requestID) else {
            reply(IncompleteInstallerTrashOutcome.failed.rawValue)
            return
        }
        Task {
            let outcome = Self.moveIncompleteInstaller(
                at: URL(filePath: installerPath), snapshot: snapshot, callerUID: callerUID)
            Self.operationGate.end(owner: requestID)
            reply(outcome.rawValue)
        }
    }

    private static func moveIncompleteInstaller(
        at url: URL, snapshot: String, callerUID: UInt32
    ) -> IncompleteInstallerTrashOutcome {
        let applications = URL(filePath: "/Applications", directoryHint: .isDirectory)
        let item = url.standardizedFileURL
        guard callerUID != 0, item.deletingLastPathComponent() == applications,
            item.pathExtension == "app", item.lastPathComponent.hasPrefix("Install macOS "),
            InstallerPathSafety.isSafe(item),
            let current = InstallerBundleSnapshot.capture(at: item), current.value == snapshot,
            isIncompleteInstaller(item), let home = getpwuid(callerUID).map({ String(cString: $0.pointee.pw_dir) })
        else { return .changed }

        let trash = URL(filePath: home).appending(path: ".Trash", directoryHint: .isDirectory)
        guard !isSymbolicLink(trash),
            let attributes = try? FileManager.default.attributesOfItem(atPath: trash.path(percentEncoded: false)),
            (attributes[.ownerAccountID] as? NSNumber)?.uint32Value == callerUID,
            let destination = uniqueTrashDestination(for: item, in: trash)
        else { return .refused }

        do {
            try FileManager.default.moveItem(at: item, to: destination)
            return .moved
        } catch {
            Self.logger.error("Move incomplete installer failed: \(String(describing: error), privacy: .private)")
            return .failed
        }
    }

    private static func isIncompleteInstaller(_ url: URL) -> Bool {
        let infoURL = url.appending(path: "Contents/Info.plist")
        let createInstallMedia = url.appending(path: "Contents/Resources/createinstallmedia")
        let sharedSupport = url.appending(path: "Contents/SharedSupport/SharedSupport.dmg")
        guard InstallerPathSafety.isSafe(url), InstallerPathSafety.isSafe(infoURL),
            let data = try? Data(contentsOf: infoURL),
            let info = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
            let identifier = info["CFBundleIdentifier"] as? String,
            identifier.hasPrefix("com.apple.InstallAssistant."),
            let version = info["CFBundleShortVersionString"] as? String,
            Int(version.split(separator: ".").first ?? "") ?? 0 >= 16
        else { return false }
        return !isNonemptyRegularFile(createInstallMedia) || !isNonemptyRegularFile(sharedSupport)
    }

    private static func isNonemptyRegularFile(_ url: URL) -> Bool {
        guard InstallerPathSafety.isSafe(url),
            let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        else { return false }
        return values.isRegularFile == true && (values.fileSize ?? 0) > 0
    }

    private static func isSymbolicLink(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true
    }

    private static func uniqueTrashDestination(for item: URL, in trash: URL) -> URL? {
        let destination = trash.appending(path: item.lastPathComponent)
        guard !FileManager.default.fileExists(atPath: destination.path(percentEncoded: false)) else { return nil }
        return destination
    }

    func cancel() {
        guard Self.operationGate.owns(connectionID) else { return }
        Self.logger.info("Cancel requested")
        Task {
            async let formatting: Void = pipeline.cancel()
            async let creating: Void = creationPipeline.cancel()
            _ = await (formatting, creating)
        }
    }

    /// The app closed the connection or quit: stop its format, if one is running.
    func connectionEnded() {
        guard Self.operationGate.owns(connectionID) else { return }
        Self.logger.info("Connection ended during an operation")
        cancel()
    }
}

private nonisolated final class ProgressProxy: @unchecked Sendable {
    let proxy: HelperProgressProtocol

    init(_ proxy: HelperProgressProtocol) {
        self.proxy = proxy
    }
}
