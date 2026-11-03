import Foundation
import Testing

@testable import Relente

struct AppleInstallerCatalogTests {
    private let product = AppleInstallerProduct(
        id: "093-22004",
        distributionURL: URL(string: "https://swdist.apple.com/product.English.dist")!,
        packageURL: URL(string: "https://swcdn.apple.com/InstallAssistant.pkg")!, size: 12_205_110_942)

    private func distribution(_ fields: String) -> Data {
        Data("<installer-gui-script><auxinfo><dict>\(fields)</dict></auxinfo></installer-gui-script>".utf8)
    }

    @Test func resolvesObservedOSIdentityWithoutPackageOrBundleVersion() throws {
        let result = try AppleInstallerCatalogParser.resolve(
            product,
            distribution: distribution(
                "<key>VERSION</key><string>13.7.8</string><key>BUILD</key><string>22H730</string>"))
        #expect(result.version == "13.7.8")
        #expect(result.build == "22H730")
    }

    @Test func rejectsAmbiguousIdentityAndEntityDeclarations() {
        let fields = "<key>VERSION</key><string>13.7.8</string><key>BUILD</key><string>22H730</string>"
        for data in [
            distribution(fields + "<key>BUILD</key><string>22H731</string>"),
            Data("<!DOCTYPE x [<!ENTITY name SYSTEM 'file:///etc/passwd'>]><x/>".utf8),
        ] {
            #expect(throws: (any Error).self) { try AppleInstallerCatalogParser.resolve(product, distribution: data) }
        }
    }

    @Test func exactCompatibilityRejectsUnknownBuildAndMultipleProducts() {
        let resolved = AppleInstallerProduct.Resolved(product: product, version: "13.7.8", build: "22H730")
        let listed = AvailableInstaller(title: "macOS Ventura", version: "13.7.8", build: "22H730")
        #expect(AppleInstallerCatalogParser.compatible([resolved], with: [listed]) == [resolved])
        #expect(AppleInstallerCatalogParser.compatible([resolved, resolved], with: [listed]).isEmpty)
        #expect(AppleInstallerCatalogParser.compatible([resolved], with: [listed, listed]).isEmpty)
        #expect(
            AppleInstallerCatalogParser.compatible(
                [resolved],
                with: [
                    AvailableInstaller(title: listed.title, version: listed.version, build: nil)
                ]
            ).isEmpty)
    }

    @Test func originPolicyRejectsCredentialsLookalikesAndRoleChanges() {
        #expect(AppleInstallerOrigin.package.allows(product.packageURL))
        for text in [
            "http://swcdn.apple.com/file", "https://swcdn.apple.com.example.org/file",
            "https://user@swcdn.apple.com/file", "https://swcdn.apple.com:444/file",
            "https://swdist.apple.com/InstallAssistant.pkg", "https://swcdn.apple.com/file#fragment",
        ] {
            #expect(!AppleInstallerOrigin.package.allows(URL(string: text)!))
        }
    }

    @Test func compatibilityListingExcludesDeferredAndMissingBuilds() throws {
        let output = """
            * Title: macOS Ventura, Version: 13.7.8, Size: 11919053KiB, Build: 22H730, Deferred: NO
            * Title: macOS Ventura, Version: 13.7.8, Size: 11919053KiB, Build: 22H731, Deferred: YES
            * Title: macOS Ventura, Version: 13.7.8, Size: 11919053KiB, Deferred: NO
            """
        let listed = try SoftwareUpdateOutputParser.fullInstallers(from: output)
        #expect(listed.count == 1)
        #expect(listed.first?.build == "22H730")
        #expect(listed.first?.sizeInBytes == 12_205_110_272)
    }
    @Test(.enabled(if: ProcessInfo.processInfo.environment["RELENTE_LIVE_CATALOG"] == "1"))
    func currentAppleCatalogAgreesWithThisMacAndLeavesNoPendingWork() async throws {
        let root = URL(filePath: "/private/tmp").appending(path: "Relente-catalog-proof-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = InstallerArtifactStore(root: root)
        let pending = try store.makePendingDirectory()
        let products = try await AppleInstallerCatalog().products(in: pending)
        #expect(!products.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: pending.path))
        #expect(try !store.hasPendingWork())
        let records = products.map {
            [
                "version": $0.version.description, "build": $0.build,
                "product": $0.product.id, "bytes": String($0.product.size),
            ]
        }
        try JSONSerialization.data(withJSONObject: records, options: [.prettyPrinted, .sortedKeys])
            .write(to: URL(filePath: "/private/tmp/relente-live-catalog-proof.json"))
    }

}
