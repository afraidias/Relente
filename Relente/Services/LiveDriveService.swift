//
//  LiveDriveService.swift
//  Relente
//
//  Follows the Mac's disks with DiskArbitration and turns them into drives with `DriveCatalog`;
//  ejects them by unmounting every volume and ejecting the media. Its session runs on the main
//  run loop, so callbacks arrive on the main actor without any dispatch queue. It only reads:
//  nothing here writes to a disk.
//  Spec: specs/007-real-detection/spec.md
//

import DiskArbitration
import Foundation
import IOKit
import os

@MainActor
final class LiveDriveService: DriveService {

    private let logger = Logger(subsystem: "com.afraidias.Relente", category: "disk")
    private var session: DASession?
    /// Every disk, partition and volume macOS reports, by BSD name.
    private var disks: [String: DiskDescription] = [:]
    /// The physical whole disks behind the startup volume.
    private var bootDisks: Set<String> = []
    private var drives: [Drive]?
    private var listeners: [UUID: AsyncStream<[Drive]>.Continuation] = [:]
    private var pendingUpdate: Task<Void, Never>?
    private var remeasuring: Task<Void, Never>?

    // MARK: - DriveService

    nonisolated func updates() -> AsyncStream<[Drive]> {
        let (stream, continuation) = AsyncStream.makeStream(of: [Drive].self, bufferingPolicy: .bufferingNewest(1))
        Task { @MainActor in self.addListener(continuation) }
        return stream
    }

    nonisolated func eject(_ drive: Drive, force: Bool) async throws(EjectError) {
        try await ejectOnMain(drive, force: force)
    }

    // MARK: - Following the disks

    private func addListener(_ continuation: AsyncStream<[Drive]>.Continuation) {
        let id = UUID()
        listeners[id] = continuation
        continuation.onTermination = { _ in Task { @MainActor in self.listeners[id] = nil } }
        if let drives { continuation.yield(drives) }
        startIfNeeded()
    }

    private func startIfNeeded() {
        guard session == nil, let session = DASessionCreate(kCFAllocatorDefault) else { return }
        self.session = session
        bootDisks = Self.bootDisks(session: session)
        let context = Unmanaged.passUnretained(self).toOpaque()

        DARegisterDiskAppearedCallback(
            session, nil,
            { disk, context in
                MainActor.assumeIsolated { LiveDriveService.from(context)?.diskChanged(disk) }
            }, context)
        DARegisterDiskDescriptionChangedCallback(
            session, nil, nil,
            { disk, _, context in
                MainActor.assumeIsolated { LiveDriveService.from(context)?.diskChanged(disk) }
            }, context)
        DARegisterDiskDisappearedCallback(
            session, nil,
            { disk, context in
                MainActor.assumeIsolated { LiveDriveService.from(context)?.diskDisappeared(disk) }
            }, context)
        DASessionScheduleWithRunLoop(session, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)

        scheduleUpdate()
        // Files written to a drive change no disk description, so its figures are read again
        // every few seconds.
        remeasuring = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                self?.scheduleUpdate()
            }
        }
    }

    private nonisolated static func from(_ context: UnsafeMutableRawPointer?) -> LiveDriveService? {
        context.map { Unmanaged<LiveDriveService>.fromOpaque($0).takeUnretainedValue() }
    }

    private func diskChanged(_ disk: DADisk) {
        guard let description = Self.describe(disk) else { return }
        disks[description.bsdName] = description
        scheduleUpdate()
    }

    private func diskDisappeared(_ disk: DADisk) {
        guard let name = DADiskGetBSDName(disk).map({ String(cString: $0) }) else { return }
        disks[name] = nil
        scheduleUpdate()
    }

    /// Callbacks come in bursts (a drive brings several partitions); one update follows them.
    private func scheduleUpdate() {
        guard pendingUpdate == nil else { return }
        pendingUpdate = Task {
            try? await Task.sleep(for: .milliseconds(200))
            pendingUpdate = nil
            await update()
        }
    }

    private func update() async {
        let all = Array(disks.values)
        let mounted = all.reduce(into: [String: URL]()) { mounts, disk in
            if let mountPoint = disk.mountPoint { mounts[disk.bsdName] = mountPoint }
        }
        let usedBytes = await Self.usedBytes(of: mounted)
        let newDrives = DriveCatalog.drives(from: all, usedBytes: usedBytes, bootDisks: bootDisks)
        guard newDrives != drives else { return }
        if newDrives.map(\.id) != drives?.map(\.id) {
            logger.info("Drives: \(newDrives.map(\.bsdName).joined(separator: ", "), privacy: .public)")
        }
        drives = newDrives
        for listener in listeners.values {
            listener.yield(newDrives)
        }
    }

    /// Space in use of each mounted volume, from its figures; its files are never listed.
    @concurrent
    private nonisolated static func usedBytes(of mounts: [String: URL]) async -> [String: Int64] {
        mounts.compactMapValues { url in
            guard
                let values = try? url.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey]),
                let total = values.volumeTotalCapacity, let available = values.volumeAvailableCapacity
            else { return nil }
            return Int64(max(total - available, 0))
        }
    }

    // MARK: - Ejecting

    private func ejectOnMain(_ drive: Drive, force: Bool) async throws(EjectError) {
        guard let session, let whole = disks[drive.bsdName], whole.isWhole,
            DriveCatalog.identity(of: whole) == drive.id,
            let disk = DADiskCreateFromBSDName(kCFAllocatorDefault, session, drive.bsdName)
        else { throw .notConnected }

        logger.info("Ejecting \(drive.bsdName, privacy: .public)\(force ? " (forced)" : "", privacy: .public)")
        var unmountOptions = DADiskUnmountOptions(kDADiskUnmountOptionWhole)
        if force { unmountOptions |= DADiskUnmountOptions(kDADiskUnmountOptionForce) }
        try await Self.run { done in
            DADiskUnmount(disk, unmountOptions, Self.completionCallback, done)
        }
        try await Self.run { done in
            DADiskEject(disk, DADiskEjectOptions(kDADiskEjectOptionDefault), Self.completionCallback, done)
        }
    }

    /// Carries a DiskArbitration request's result back to the task waiting for it.
    private final class Completion {
        let continuation: CheckedContinuation<EjectError?, Never>
        init(_ continuation: CheckedContinuation<EjectError?, Never>) { self.continuation = continuation }
    }

    /// Starts a DiskArbitration request and waits for its callback.
    private static func run(_ start: (UnsafeMutableRawPointer) -> Void) async throws(EjectError) {
        let error = await withCheckedContinuation { continuation in
            start(Unmanaged.passRetained(Completion(continuation)).toOpaque())
        }
        if let error { throw error }
    }

    private static let completionCallback: DADiskUnmountCallback = { _, dissenter, context in
        guard let context else { return }
        let completion = Unmanaged<Completion>.fromOpaque(context).takeRetainedValue()
        completion.continuation.resume(returning: dissenter.map(LiveDriveService.error(for:)))
    }

    private nonisolated static func error(for dissenter: DADissenter) -> EjectError {
        if DADissenterGetStatus(dissenter) == DAReturn(kDAReturnNotFound) { return .notConnected }
        let reason = DADissenterGetStatusString(dissenter).map { $0 as String }
        return .refused(reason: reason.flatMap { $0.isEmpty ? nil : $0 })
    }

    // MARK: - Reading descriptions

    private static func describe(_ disk: DADisk) -> DiskDescription? {
        guard let description = DADiskCopyDescription(disk) as? [CFString: Any],
            let bsdName = description[kDADiskDescriptionMediaBSDNameKey] as? String
        else { return nil }
        let uuid = description[kDADiskDescriptionMediaUUIDKey].flatMap { value -> String? in
            let object = value as CFTypeRef
            guard CFGetTypeID(object) == CFUUIDGetTypeID() else { return nil }
            return CFUUIDCreateString(kCFAllocatorDefault, unsafeDowncast(object, to: CFUUID.self)) as String
        }
        let isWhole = description[kDADiskDescriptionMediaWholeKey] as? Bool ?? false
        let ancestry = IOMediaAncestry(disk: disk)
        return DiskDescription(
            bsdName: bsdName,
            isWhole: isWhole,
            isInternal: description[kDADiskDescriptionDeviceInternalKey] as? Bool ?? true,
            isRemovable: description[kDADiskDescriptionMediaRemovableKey] as? Bool ?? false,
            deviceProtocol: description[kDADiskDescriptionDeviceProtocolKey] as? String,
            mediaUUID: uuid,
            vendor: description[kDADiskDescriptionDeviceVendorKey] as? String,
            model: description[kDADiskDescriptionDeviceModelKey] as? String,
            serialNumber: ancestry.serialNumber,
            size: (description[kDADiskDescriptionMediaSizeKey] as? NSNumber)?.int64Value ?? 0,
            content: description[kDADiskDescriptionMediaContentKey] as? String,
            volumeName: description[kDADiskDescriptionVolumeNameKey] as? String,
            mountPoint: description[kDADiskDescriptionVolumePathKey] as? URL,
            physicalWholeDisk: ancestry.physicalWholeDisk.flatMap { physical in
                let own = isWhole ? bsdName : DiskDescription(bsdName: bsdName, isWhole: false).wholeDiskName
                return physical == own ? nil : physical
            }
        )
    }

    /// The physical whole disks behind the startup volume and its data volume.
    private static func bootDisks(session: DASession) -> Set<String> {
        Set(
            ["/", "/System/Volumes/Data"].compactMap { path in
                DADiskCreateFromVolumePath(kCFAllocatorDefault, session, URL(filePath: path) as CFURL)
                    .flatMap { IOMediaAncestry(disk: $0).physicalWholeDisk }
            })
    }
}

// MARK: - IOKit

/// What the I/O Registry says above a disk: the outermost whole disk (the physical one behind an
/// APFS volume) and the USB serial number.
private struct IOMediaAncestry {
    var physicalWholeDisk: String?
    var serialNumber: String?

    init(disk: DADisk) {
        let media = DADiskCopyIOMedia(disk)
        guard media != IO_OBJECT_NULL else { return }
        var entry = media
        IOObjectRetain(entry)
        while entry != IO_OBJECT_NULL {
            if IOObjectConformsTo(entry, "IOMedia") != 0,
                Self.property("Whole", of: entry) as? Bool == true,
                let name = Self.property("BSD Name", of: entry) as? String
            {
                physicalWholeDisk = name
            }
            if serialNumber == nil {
                serialNumber = Self.property("USB Serial Number", of: entry) as? String
            }
            var parent: io_registry_entry_t = IO_OBJECT_NULL
            let result = IORegistryEntryGetParentEntry(entry, kIOServicePlane, &parent)
            IOObjectRelease(entry)
            entry = result == KERN_SUCCESS ? parent : IO_OBJECT_NULL
        }
        IOObjectRelease(media)
    }

    private static func property(_ key: String, of entry: io_registry_entry_t) -> Any? {
        IORegistryEntryCreateCFProperty(entry, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
    }
}
