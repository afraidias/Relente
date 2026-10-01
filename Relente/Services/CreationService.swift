//
//  CreationService.swift
//  Relente
//
//  Makes the bootable installer on the chosen drive and reports how it goes. Until roadmap
//  step 7 only a Debug-only simulation exists (`SimulatedCreationService`); Release builds have
//  no service, so "Erase and Create" stays disabled.
//  Spec: specs/006-assistant-navigation/spec.md
//

import Foundation

/// What a creation reports, in order: progress snapshots, then `finished` or `failed`.
nonisolated enum CreationEvent: Hashable, Sendable {
    case progress(CreationProgress)
    case finished
    case failed(CreationFailure)
}

nonisolated protocol CreationService: Sendable {
    /// Whether it only pretends: the screens then say nothing is erased.
    var isSimulated: Bool { get }

    /// Starts making the installer. Cancelling the task that reads the stream stops it.
    func create(installer: InstallerSource, drive: Drive) -> AsyncStream<CreationEvent>
}
