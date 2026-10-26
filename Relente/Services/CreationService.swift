//
//  CreationService.swift
//  Relente
//
//  Makes the bootable installer on the chosen drive and reports how it goes. Until roadmap
//  step 7 only Debug builds have one: `HelperCreationService` really formats the drive through the
//  helper and pretends the rest; `SimulatedCreationService` pretends everything, for sample data
//  and the UI test. Release builds have none, so "Erase and Create" stays disabled.
//  Spec: specs/006-assistant-navigation/spec.md, specs/008-system-helper/spec.md
//

import Foundation

/// What a creation reports, in order: progress snapshots, then `finished` or `failed`.
nonisolated enum CreationEvent: Hashable, Sendable {
    case progress(CreationProgress)
    case finished
    case failed(CreationFailure)
}

/// How much of a creation is only pretended; the screens say so.
nonisolated enum CreationSimulation: Hashable, Sendable {
    /// Nothing is erased (sample data, previews, the UI test).
    case everything
    /// The drive is really formatted; copying, making it bootable and verifying are pretended.
    case afterFormat
}

nonisolated protocol CreationService: Sendable {
    /// What it only pretends, or `nil` when it does everything for real.
    var simulation: CreationSimulation? { get }

    /// Starts making the installer. Cancelling the task that reads the stream stops it.
    /// - Parameter authorization: the administrator's authorization for this erase, when the
    ///   service erases the drive (`erasesDrive`).
    func create(installer: InstallerSource, drive: Drive, authorization: EraseAuthorization?)
        -> AsyncStream<CreationEvent>
}

nonisolated extension CreationService {
    /// Whether it really erases the drive through the helper, so "Erase and Create" first asks for
    /// the administrator's authorization.
    var erasesDrive: Bool {
        simulation != .everything
    }
}
