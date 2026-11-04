import Foundation

/// Exact delivery roles; a public Apple-looking hostname or redirect is not an implicit grant.
nonisolated enum AppleInstallerOrigin: Sendable {
    case catalog, metadata, package

    func allows(_ url: URL) -> Bool {
        guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
            parts.scheme == "https", parts.user == nil, parts.password == nil,
            parts.port == nil || parts.port == 443, parts.fragment == nil
        else { return false }
        let host: String
        switch self {
        case .catalog: host = "swscan.apple.com"
        case .metadata: host = "swdist.apple.com"
        case .package: host = "swcdn.apple.com"
        }
        return parts.host?.lowercased() == host
    }
}
