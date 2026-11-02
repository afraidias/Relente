//
//  IncompleteInstallerTrashOutcome.swift
//  Relente
//
//  Result of the helper's single-purpose incomplete installer recovery operation.
//  Spec: specs/011-installer-acquisition/spec.md
//

import Foundation

nonisolated enum IncompleteInstallerTrashOutcome: Int, Sendable {
    case moved
    case changed
    case refused
    case failed
}
