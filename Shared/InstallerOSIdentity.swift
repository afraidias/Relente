import Foundation

/// Exact selected OS identity, independent of installer UI/package version numbering.
nonisolated struct InstallerOSIdentity: Hashable, Sendable {
    let version: String
    let build: String
    static let catalogPath = "com_apple_MobileAsset_MacSoftwareUpdate/com_apple_MobileAsset_MacSoftwareUpdate.xml"
    enum Failure: Error { case invalid }

    init(version: String, build: String) throws {
        guard version.range(of: "^[0-9]+(\\.[0-9]+){0,2}$", options: .regularExpression) != nil,
            build.range(of: "^[0-9]{2,3}[A-Z][0-9]+[a-z]?$", options: .regularExpression) != nil
        else { throw Failure.invalid }
        let parts = version.split(separator: ".").compactMap { Int($0) }
        guard parts.count == version.split(separator: ".").count, let major = parts.first, major >= 11 else {
            throw Failure.invalid
        }
        let minor = parts.count > 1 ? parts[1] : 0
        let patch = parts.count > 2 ? parts[2] : 0
        self.version = patch == 0 ? "\(major).\(minor)" : "\(major).\(minor).\(patch)"
        self.build = build
    }

    static func read(from data: Data) throws -> Self {
        guard data.count <= 8 * 1_024 * 1_024,
            let root = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
            let assets = root["Assets"] as? [[String: Any]], !assets.isEmpty
        else { throw Failure.invalid }
        let identities = try Set(
            assets.map { asset in
                guard let version = asset["OSVersion"] as? String, let build = asset["Build"] as? String else {
                    throw Failure.invalid
                }
                return try Self(version: version, build: build)
            })
        guard identities.count == 1, let identity = identities.first else { throw Failure.invalid }
        return identity
    }
}
