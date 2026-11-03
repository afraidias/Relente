import Foundation

/// A full package candidate. Compatibility is established separately by exact version/build.
nonisolated struct AppleInstallerProduct: Hashable, Sendable, Identifiable {
    let id: String
    let distributionURL: URL
    let packageURL: URL
    let size: Int64

    struct Resolved: Hashable, Sendable {
        let product: AppleInstallerProduct
        let version: MacOSVersion
        let build: String
    }
}
