//
//  InstallerAcquisitionPolicy.swift
//  Relente
//
//  Decides whether a catalog entry can be reused or downloaded without a collision.
//  Design: intent/direct-installer-download/spec.md
//

import Foundation

nonisolated enum InstallerAcquisitionPolicy {
    enum Decision: Hashable, Sendable {
        case use(InstallerSource)
        case download
        case unavailable(Reason)
    }

    enum Reason: Hashable, Sendable {
        case multipleLocalMatches
        case ambiguousBuild
        case catalogChanged
        case localStateUnavailable
        case destinationOccupied

        var message: LocalizedStringResource {
            switch self {
            case .multipleLocalMatches:
                LocalizedStringResource(
                    "More than one matching installer is available. Choose one on the Installer screen.",
                    comment: "Download screen: multiple local installers match; return so the user can choose manually."
                )
            case .ambiguousBuild, .catalogChanged:
                LocalizedStringResource(
                    "Apple’s installer list changed or has indistinguishable builds. Try refreshing the list.",
                    comment: "Download screen: a catalog entry cannot be safely requested by version and build.")
            case .localStateUnavailable:
                LocalizedStringResource(
                    "Relente couldn’t check the installers already on this Mac.",
                    comment: "Download screen: the local installer list could not be refreshed before downloading.")
            case .destinationOccupied:
                LocalizedStringResource(
                    "An item is already at Apple’s installer location. Resolve it in Finder before downloading.",
                    comment: "Download screen: Apple’s destination is occupied by an incomplete or unreadable item.")
            }
        }
    }

    /// Checks a matching complete local installer before considering download ambiguity or paths.
    static func decision(
        for selected: AvailableInstaller,
        among catalog: [AvailableInstaller],
        localInstallers: [InstallerSource],
        destinationOccupied: Bool
    ) -> Decision {
        switch selected.localMatch(in: localInstallers) {
        case .unique(let installer): return .use(installer)
        case .ambiguous: return .unavailable(.multipleLocalMatches)
        case .none: break
        }

        guard catalog.contains(selected) else { return .unavailable(.catalogChanged) }
        guard let build = selected.build, !build.isEmpty,
            catalog.filter({ $0.version == selected.version && $0.build == build }).count == 1
        else { return .unavailable(.ambiguousBuild) }
        guard !destinationOccupied else { return .unavailable(.destinationOccupied) }
        return .download
    }

}
