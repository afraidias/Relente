//
//  CreationState.swift
//  Relente
//
//  What the Creating screen shows: the process running, or where and why it stopped.
//  Both share one layout, so the screen doesn't jump when it fails.
//  Spec: specs/004-creating-screen/spec.md
//

import Foundation

nonisolated enum CreationState: Hashable, Sendable {
    case running(CreationProgress)
    case failed(CreationFailure)

    /// The progress to draw: the live one, or the one frozen when it stopped.
    var progress: CreationProgress {
        switch self {
        case .running(let progress): progress
        case .failed(let failure): failure.progress
        }
    }

    /// Why it stopped, or `nil` while it's running.
    var failure: CreationFailure? {
        switch self {
        case .running: nil
        case .failed(let failure): failure
        }
    }
}
