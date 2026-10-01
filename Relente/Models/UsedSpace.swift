//
//  UsedSpace.swift
//  Relente
//
//  How much is stored on a drive: a figure, or unknown when part of it can't be measured.
//  Spec: specs/007-real-detection/spec.md
//

import Foundation

nonisolated enum UsedSpace: Hashable, Sendable {
    /// The space used by every volume on the drive, in bytes.
    case bytes(Int64)
    /// Some of the drive holds data Relente can't measure (e.g. a Linux or locked volume).
    case unknown
}
