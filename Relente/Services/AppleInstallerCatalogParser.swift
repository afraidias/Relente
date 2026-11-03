import CoreFoundation
import Foundation

nonisolated enum AppleInstallerCatalogParser {
    struct ParseError: Error {}

    static func candidates(from data: Data) throws -> [AppleInstallerProduct] {
        guard data.count <= 32 * 1_024 * 1_024,
            let root = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
            let products = root["Products"] as? [String: [String: Any]]
        else { throw ParseError() }
        return products.compactMap { id, product in
            guard let info = product["ExtendedMetaInfo"] as? [String: Any],
                let identifiers = info["InstallAssistantPackageIdentifiers"] as? [String: String],
                let shared = identifiers["SharedSupport"], shared.hasPrefix("com.apple.pkg.InstallAssistant.macOS"),
                let distributions = product["Distributions"] as? [String: String],
                let text = distributions["English"], let distribution = URL(string: text),
                AppleInstallerOrigin.metadata.allows(distribution),
                let packages = product["Packages"] as? [[String: Any]]
            else { return nil }
            let assistants = packages.filter {
                ($0["URL"] as? String).flatMap(URL.init(string:))?.lastPathComponent == "InstallAssistant.pkg"
            }
            guard assistants.count == 1, let package = assistants.first,
                let text = package["URL"] as? String, let url = URL(string: text),
                AppleInstallerOrigin.package.allows(url),
                let size = package["Size"] as? NSNumber, CFGetTypeID(size) != CFBooleanGetTypeID(),
                size.int64Value > 0, size.doubleValue == Double(size.int64Value)
            else { return nil }
            return AppleInstallerProduct(id: id, distributionURL: distribution, packageURL: url, size: size.int64Value)
        }.sorted { $0.id < $1.id }
    }

    /// Read identity as XML data, never evaluate Distribution JavaScript or external entities.
    static func resolve(_ product: AppleInstallerProduct, distribution data: Data) throws
        -> AppleInstallerProduct.Resolved
    {
        guard data.count <= 1_024 * 1_024, let text = String(data: data, encoding: .utf8),
            !text.uppercased().contains("<!DOCTYPE"), !text.uppercased().contains("<!ENTITY")
        else { throw ParseError() }
        let document = try XMLDocument(data: data, options: .nodeLoadExternalEntitiesNever)
        func field(_ name: String) throws -> String {
            let nodes = try document.nodes(
                forXPath: "/installer-gui-script/auxinfo/dict/key[.='\(name)']/following-sibling::*[1]")
            guard nodes.count == 1, nodes[0].name == "string", let value = nodes[0].stringValue,
                !value.isEmpty, value == value.trimmingCharacters(in: .whitespacesAndNewlines)
            else { throw ParseError() }
            return value
        }
        guard let version = MacOSVersion(try field("VERSION")), version >= .bigSur else { throw ParseError() }
        let build = try field("BUILD")
        guard build.range(of: "^[0-9]{2,3}[A-Z][0-9]+[a-z]?$", options: .regularExpression) != nil else {
            throw ParseError()
        }
        return AppleInstallerProduct.Resolved(product: product, version: version, build: build)
    }

    /// Reject duplicate identities; selecting an arbitrary product would hide catalog ambiguity.
    static func compatible(_ products: [AppleInstallerProduct.Resolved], with listed: [AvailableInstaller])
        -> [AppleInstallerProduct.Resolved]
    {
        let groups = Dictionary(grouping: products) { "\($0.version)|\($0.build)" }
        return products.filter { product in
            let identity = "\(product.version)|\(product.build)"
            return groups[identity]?.count == 1
                && listed.filter {
                    $0.version == product.version && $0.build == product.build
                }.count == 1
        }.sorted { $0.version > $1.version }
    }
}
