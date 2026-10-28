import Foundation

nonisolated struct HelperCreationService: CreationService {
    let client: any HelperClient
    private let verifiesVolume: @Sendable (URL, InstallerSource) -> Bool

    init(
        client: any HelperClient,
        verifiesVolume: @escaping @Sendable (URL, InstallerSource) -> Bool = Self.verifiesInstallerVolume
    ) {
        self.client = client
        self.verifiesVolume = verifiesVolume
    }

    var simulation: CreationSimulation? { nil }

    func create(installer: InstallerSource, drive: Drive, authorization: EraseAuthorization?)
        -> AsyncStream<CreationEvent>
    {
        AsyncStream { continuation in
            Task {
                var latestProgress = Self.initialProgress(installer)
                var availableVolume: URL?
                var mentionedMediaCookie = false
                var reportedPermissionError = false
                let events = await client.createInstallMedia(
                    installerURL: installer.url,
                    installerPackageURL: installer.kind == .package ? installer.url : nil,
                    drive: drive, authorization: authorization?.externalForm ?? Data())
                withExtendedLifetime(authorization) {}
                for await event in events {
                    switch event {
                    case .update(let update):
                        let outputProgress = update.outputLine.flatMap {
                            CreateInstallMediaOutputParser.progress(in: $0)
                        }
                        if let progress = update.progress ?? outputProgress {
                            latestProgress = Self.progress(
                                progress, update: update, previous: latestProgress, installerSize: installer.size)
                            continuation.yield(.progress(latestProgress))
                        } else if let measurement = update.copyMeasurement {
                            let copyProgress = CreateInstallMediaProgress(phase: .copy, fraction: measurement.fraction)
                            latestProgress = Self.progress(
                                copyProgress, update: update, previous: latestProgress, installerSize: installer.size)
                            continuation.yield(.progress(latestProgress))
                        }
                        if let line = update.outputLine {
                            mentionedMediaCookie =
                                mentionedMediaCookie || line.localizedCaseInsensitiveContains(".IAPhysicalMedia")
                            reportedPermissionError =
                                reportedPermissionError
                                || line.localizedCaseInsensitiveContains("Operation not permitted")
                            continuation.yield(.output(CreationOutputLine(timestamp: update.timestamp, text: line)))
                            availableVolume =
                                CreateInstallMediaOutputParser.availableVolume(in: line)
                                ?? availableVolume
                        }
                    case .finished(let outcome):
                        if outcome == .created {
                            if let availableVolume, verifiesVolume(availableVolume, installer) {
                                continuation.yield(.finished)
                            } else {
                                continuation.yield(
                                    .failed(CreationFailure(reason: .verificationFailed, progress: latestProgress)))
                            }
                        } else {
                            let reason: CreationFailure.Reason =
                                outcome == .volumeAccessDenied
                                    || (outcome == .createFailed && mentionedMediaCookie && reportedPermissionError)
                                ? .volumeAccessDenied : (outcome.map(Self.failure) ?? .helperUnavailable)
                            continuation.yield(.failed(CreationFailure(reason: reason, progress: latestProgress)))
                        }
                        continuation.finish()
                        return
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { termination in
                guard case .cancelled = termination else { return }
                Task { await client.cancel() }
            }
        }
    }

    private static func initialProgress(_ installer: InstallerSource) -> CreationProgress {
        CreationProgress(
            phase: .format, phaseFraction: nil, installerSize: installer.size, isLive: true,
            isPreparingInstaller: true)
    }

    private static func progress(
        _ update: CreateInstallMediaProgress, update event: CreateInstallMediaUpdate,
        previous: CreationProgress, installerSize: Int64
    ) -> CreationProgress {
        let phase: CreationPhase =
            switch update.phase {
            case .erase: .format
            case .copy: .copy
            case .makeBootable: .makeBootable
            }
        let measurement = event.copyMeasurement
        let fraction =
            update.fraction ?? measurement?.fraction
            ?? (phase == previous.phase ? previous.phaseFraction : nil)
        let hasMeasuredCopyProgress = measurement != nil || previous.hasMeasuredCopyProgress
        return CreationProgress(
            phase: phase,
            phaseFraction: fraction,
            copiedBytes: measurement?.copiedBytes ?? previous.copiedBytes,
            installerSize: measurement?.totalBytes
                ?? (hasMeasuredCopyProgress ? previous.installerSize : installerSize),
            bytesPerSecond: event.copyBytesPerSecond ?? previous.bytesPerSecond,
            isLive: true,
            hasMeasuredCopyProgress: hasMeasuredCopyProgress)
    }

    private static func failure(_ outcome: CreateInstallMediaOutcome) -> CreationFailure.Reason {
        switch outcome {
        case .created: .unknown
        case .notAuthorized, .busy: .unknown
        case .invalidIdentifier, .driveNotAllowed: .driveNotAllowed
        case .driveChanged: .driveChanged
        case .driveDisconnected: .driveDisconnected
        case .invalidInstaller: .installerDamaged
        case .createFailed, .invalidVolume, .volumeAccessDenied: .createFailed
        }
    }

    private static func verifiesInstallerVolume(_ url: URL, _ installer: InstallerSource) -> Bool {
        guard url.path.hasPrefix("/Volumes/"), url.lastPathComponent == "Install \(installer.name)" else {
            return false
        }
        return containsExpectedInstaller(in: url, installer: installer)
    }

    static func containsExpectedInstaller(in volume: URL, installer: InstallerSource) -> Bool {
        let app = volume.appending(path: "Install \(installer.name).app", directoryHint: .isDirectory)
        guard let values = try? app.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
            values.isDirectory == true, values.isSymbolicLink != true
        else { return false }
        return FileManager.default.fileExists(atPath: app.appending(path: "Contents/Info.plist").path)
    }
}
