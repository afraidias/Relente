import Foundation

/// Fetches bounded official metadata and intersects it with this Mac's full-installer listing.
nonisolated struct AppleInstallerCatalog: Sendable {
    static let catalogURL = URL(
        string:
            "https://swscan.apple.com/content/catalogs/others/index-26-15-14-13-12-10.16-10.15-10.14-10.13-10.12-10.11-10.10-10.9-mountainlion-lion-snowleopard-leopard.merged-1.sucatalog"
    )!

    enum Failure: Error {
        case invalidListing, tooManyProducts, cleanupFailed
        case recoveryRequired(URL)
    }

    @concurrent
    func products(in folder: URL) async throws -> [AppleInstallerProduct.Resolved] {
        do {
            let listingData = try await InstallerCommand.listCompatible.run(in: folder, timeout: 90)
            guard let listing = String(data: listingData, encoding: .utf8) else { throw Failure.invalidListing }
            let compatible = try SoftwareUpdateOutputParser.fullInstallers(from: listing)
            let catalog = try await fetch(
                Self.catalogURL, origin: .catalog, limit: 32 * 1_024 * 1_024,
                destination: folder.appending(path: "catalog.plist"))
            let candidates = try AppleInstallerCatalogParser.candidates(from: catalog)
            guard candidates.count <= 128 else { throw Failure.tooManyProducts }
            var resolved: [AppleInstallerProduct.Resolved] = []
            for candidate in candidates {
                try Task.checkCancellation()
                let metadata = try await fetch(
                    candidate.distributionURL, origin: .metadata, limit: 1_024 * 1_024,
                    destination: folder.appending(path: "distribution.xml"))
                if let result = try? AppleInstallerCatalogParser.resolve(candidate, distribution: metadata) {
                    resolved.append(result)
                }
                try FileManager.default.removeItem(at: folder.appending(path: "distribution.xml"))
            }
            let products = AppleInstallerCatalogParser.compatible(resolved, with: compatible)
            try FileManager.default.removeItem(at: folder)
            return products
        } catch InstallerCommand.Failure.lostProcess {
            // Keep evidence and working files; a lost process is not terminal cancellation.
            throw Failure.recoveryRequired(folder)
        } catch {
            do { try FileManager.default.removeItem(at: folder) } catch { throw Failure.cleanupFailed }
            throw error
        }
    }

    private func fetch(_ url: URL, origin: AppleInstallerOrigin, limit: Int64, destination: URL) async throws -> Data {
        let transfer = InstallerDownload(origin: origin, destination: destination, maximumBytes: limit)
        let file = try await transfer.start(url)
        return try Data(contentsOf: file)
    }
}
