//
//  AvailableInstaller.swift
//  Relente
//
//  A full macOS installer listed by Apple's Software Update catalog.
//  Design: intent/direct-installer-download/spec.md
//

import Foundation

nonisolated struct AvailableInstaller: Hashable, Identifiable, Sendable {
    enum LocalMatch: Hashable, Sendable {
        case none
        case unique(InstallerSource)
        case ambiguous
    }

    /// Apple's catalog title, for example "macOS Sequoia".
    let title: String
    let version: MacOSVersion
    /// Apple build identifier, when the catalog provides one.
    let build: String?
    /// Full installer download size in bytes, when Apple's catalog provides it.
    let sizeInBytes: Int64?

    init(title: String, version: MacOSVersion, build: String?, sizeInBytes: Int64? = nil) {
        self.title = title
        self.version = version
        self.build = build
        self.sizeInBytes = sizeInBytes
    }

    var id: String {
        "\(version)|\(build ?? "")|\(title)"
    }

    var isSupported: Bool {
        version >= .bigSur
    }

    /// Unknown builds never establish that a local installer is the requested product.
    func localMatch(in installers: [InstallerSource]) -> LocalMatch {
        let matches = installers.filter { installer in
            guard version == installer.version else { return false }
            guard let build, !build.isEmpty, let localBuild = installer.build else { return false }
            return build == localBuild
        }
        switch matches.count {
        case 0: return .none
        case 1: return .unique(matches[0])
        default: return .ambiguous
        }
    }

    /// Newest macOS first; entries for the same version preserve catalog order.
    static func sorted(_ installers: [AvailableInstaller]) -> [AvailableInstaller] {
        installers.enumerated()
            .sorted { lhs, rhs in
                lhs.element.version != rhs.element.version
                    ? lhs.element.version > rhs.element.version : lhs.offset < rhs.offset
            }
            .map(\.element)
    }
    /// Only one unambiguous newest eligible version per family is offered.
    static func latestPerFamily(_ installers: [AvailableInstaller]) -> [AvailableInstaller] {
        let eligible = sorted(installers.filter(\.isSupported))
        var seen = Set<String>()
        return eligible.compactMap { candidate in
            guard seen.insert(candidate.title).inserted else { return nil }
            let newest = eligible.filter { $0.title == candidate.title && $0.version == candidate.version }
            guard newest.count == 1, let build = candidate.build, !build.isEmpty else { return nil }
            return candidate
        }
    }

}
