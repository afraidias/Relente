//
//  HelperCreationService.swift
//  Relente
//
//  Debug builds only, until roadmap step 7: really formats the drive through the helper, then
//  pretends to copy the installer, make it bootable and verify it, so the real erase can be tried
//  end to end before `createinstallmedia` exists. The screens say only the format is real.
//  Spec: specs/008-system-helper/spec.md
//

#if DEBUG
    import Foundation

    nonisolated struct HelperCreationService: CreationService {
        let client: any HelperClient
        /// How long the pretended phases after the format last.
        var simulatedDuration: Duration = .seconds(12)

        var simulation: CreationSimulation? { .afterFormat }

        func create(installer: InstallerSource, drive: Drive, authorization: EraseAuthorization?)
            -> AsyncStream<CreationEvent>
        {
            let client = client
            let simulatedDuration = simulatedDuration
            return AsyncStream { continuation in
                let task = Task {
                    // Format reports no percentage while diskutil works (spec 004 allows it).
                    let formatting = CreationProgress(phase: .format, phaseFraction: nil, installerSize: installer.size)
                    continuation.yield(.progress(formatting))

                    let outcome = await client.format(drive, authorization: authorization?.externalForm ?? Data())
                    // The authorization is kept until the helper answered; then it's destroyed.
                    withExtendedLifetime(authorization) {}
                    guard !Task.isCancelled else {
                        continuation.finish()
                        return
                    }
                    if let reason = Self.failure(for: outcome) {
                        continuation.yield(.failed(CreationFailure(reason: reason, progress: formatting)))
                        continuation.finish()
                        return
                    }

                    let rest = Self.afterFormat(SimulatedCreationService.timeline(for: installer, failure: nil))
                    for await event in SimulatedCreationService.play(rest, over: simulatedDuration) {
                        continuation.yield(event)
                    }
                    continuation.finish()
                }
                continuation.onTermination = { termination in
                    task.cancel()
                    // Stopping the creation stops diskutil too.
                    if case .cancelled = termination {
                        Task { await client.cancel() }
                    }
                }
            }
        }

        /// Why the run fails after the helper's answer, or `nil` once the drive is formatted.
        /// `nil` (no answer) means the helper didn't respond.
        static func failure(for outcome: FormatOutcome?) -> CreationFailure.Reason? {
            switch outcome {
            case .formatted: nil
            case nil: .helperUnavailable
            case .driveChanged: .driveChanged
            case .driveNotAllowed, .invalidIdentifier: .driveNotAllowed
            case .driveDisconnected: .driveDisconnected
            case .formatFailed: .formatFailed
            case .notAuthorized, .busy: .unknown
            }
        }

        /// The simulated events once the format is done: Copy, Make bootable, Verify and the end.
        static func afterFormat(_ timeline: [CreationEvent]) -> [CreationEvent] {
            timeline.filter { event in
                guard case .progress(let progress) = event else { return true }
                return progress.phase != .format
            }
        }
    }
#endif
