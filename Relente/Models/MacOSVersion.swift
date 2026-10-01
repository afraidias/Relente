//
//  MacOSVersion.swift
//  Relente
//
//  A macOS version number such as "15.6" or "10.15.7", compared part by part.
//  Spec: specs/007-real-detection/spec.md
//

import Foundation

nonisolated struct MacOSVersion: Hashable, Sendable, Comparable, CustomStringConvertible {
    let major: Int
    let minor: Int
    let patch: Int

    init(major: Int, minor: Int = 0, patch: Int = 0) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    /// Parses "15", "15.6" or "10.15.7". Returns `nil` for anything else.
    init?(_ text: String) {
        let parts = text.trimmingCharacters(in: .whitespaces).split(separator: ".", omittingEmptySubsequences: false)
        guard (1...3).contains(parts.count) else { return nil }
        var numbers: [Int] = []
        for part in parts {
            guard !part.isEmpty, part.allSatisfy(\.isASCII), let number = Int(part), number >= 0 else { return nil }
            numbers.append(number)
        }
        self.init(
            major: numbers[0], minor: numbers.count > 1 ? numbers[1] : 0, patch: numbers.count > 2 ? numbers[2] : 0)
    }

    /// The oldest version Relente supports: macOS Big Sur.
    static let bigSur = MacOSVersion(major: 11)

    static func < (lhs: MacOSVersion, rhs: MacOSVersion) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }

    /// "15.6", "26.0" or "10.15.7": the patch only when it isn't 0, the minor always.
    var description: String {
        patch == 0 ? "\(major).\(minor)" : "\(major).\(minor).\(patch)"
    }
}

// MARK: - Literals

nonisolated extension MacOSVersion: ExpressibleByStringLiteral {
    /// For sample data and tests, e.g. `version: "15.6"`. An invalid literal is a programming error.
    init(stringLiteral value: String) {
        guard let version = MacOSVersion(value) else { preconditionFailure("Invalid macOS version: \(value)") }
        self = version
    }
}
