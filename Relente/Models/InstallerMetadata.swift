//
//  InstallerMetadata.swift
//  Relente
//
//  Reads what Relente shows about an installer from the files inside it: the installer app's
//  Info.plist, the software update catalog in its SharedSupport disk image, and an
//  InstallAssistant.pkg's Distribution file. Pure functions on the files' contents; reading the
//  files themselves is the installer service's job.
//  Spec: specs/007-real-detection/spec.md
//

import Foundation

nonisolated enum InstallerMetadata {

    /// The contents aren't what a macOS installer has.
    struct ParseError: Error, Hashable {}

    /// What the installer app's Info.plist says.
    struct AppInfo: Hashable, Sendable {
        /// e.g. "macOS Sequoia".
        let name: String
        /// The macOS version the installer's own version number points to. Only the major version
        /// is known this way; the full one is in the SharedSupport catalog.
        let version: MacOSVersion
    }

    // MARK: - Installer app

    /// Every installer from Apple has a bundle identifier starting like this, e.g.
    /// "com.apple.InstallAssistant.macOSSequoia".
    static let bundleIdentifierPrefix = "com.apple.InstallAssistant."

    /// Reads an `Install macOS *.app`'s Info.plist.
    static func appInfo(fromInfoPlist data: Data) throws(ParseError) -> AppInfo {
        guard
            let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
            let identifier = plist["CFBundleIdentifier"] as? String, identifier.hasPrefix(bundleIdentifierPrefix),
            let displayName = (plist["CFBundleDisplayName"] as? String) ?? (plist["CFBundleName"] as? String),
            let bundleVersion = (plist["CFBundleShortVersionString"] as? String).flatMap(MacOSVersion.init)
        else { throw ParseError() }

        let name = displayName.hasPrefix("Install ") ? String(displayName.dropFirst("Install ".count)) : displayName
        let version = knownVersion(forName: name) ?? macOSVersion(forInstallerVersion: bundleVersion)
        return AppInfo(name: name, version: version)
    }

    /// The macOS version an installer app's own version number stands for. Apple numbers them
    /// 16.x for Big Sur (11) up to 20.x for Sequoia (15), 21.x for Tahoe (26) onwards, and 15.x,
    /// 14.x… for Catalina (10.15), Mojave (10.14)…
    static func macOSVersion(forInstallerVersion installerVersion: MacOSVersion) -> MacOSVersion {
        switch installerVersion.major {
        case ...15: MacOSVersion(major: 10, minor: installerVersion.major)
        case 16...20: MacOSVersion(major: installerVersion.major - 5)
        default: MacOSVersion(major: installerVersion.major + 5)
        }
    }

    // MARK: - SharedSupport catalog

    /// Where the catalog lives inside `Contents/SharedSupport/SharedSupport.dmg`, once mounted.
    static let catalogPath = "com_apple_MobileAsset_MacSoftwareUpdate/com_apple_MobileAsset_MacSoftwareUpdate.xml"

    /// The full macOS version, e.g. 15.6, from the software update catalog.
    static func version(fromCatalog data: Data) throws(ParseError) -> MacOSVersion {
        guard
            let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
            let assets = plist["Assets"] as? [[String: Any]],
            let version = assets.lazy.compactMap({ ($0["OSVersion"] as? String).flatMap(MacOSVersion.init) }).first
        else { throw ParseError() }
        return version
    }

    // MARK: - InstallAssistant.pkg

    /// What an InstallAssistant.pkg's Distribution file says.
    struct PackageInfo: Hashable, Sendable {
        let version: MacOSVersion
        /// What it installs, in bytes.
        let installedSize: Int64
    }

    /// Reads the Distribution file of an InstallAssistant.pkg: the macOS version in its
    /// `auxinfo` and the size of what it installs.
    static func packageInfo(fromDistribution data: Data) throws(ParseError) -> PackageInfo {
        guard let document = try? XMLDocument(data: data) else { throw ParseError() }
        guard
            let versionNodes = try? document.nodes(
                forXPath: "/installer-gui-script/auxinfo/dict/key[.='VERSION']/following-sibling::string[1]"),
            let versionText = versionNodes.first?.stringValue, let version = MacOSVersion(versionText),
            let sizes = try? document.nodes(forXPath: "/installer-gui-script/pkg-ref/@installKBytes"),
            !sizes.isEmpty
        else { throw ParseError() }
        let kilobytes = sizes.compactMap { $0.stringValue.flatMap { Int64($0) } }.reduce(0, +)
        guard kilobytes > 0 else { throw ParseError() }
        return PackageInfo(version: version, installedSize: kilobytes * 1024)
    }

    // MARK: - Names

    /// Marketing names Apple gave each version, from El Capitan on.
    private static let names: [(name: String, version: MacOSVersion)] = [
        ("OS X El Capitan", "10.11"), ("macOS Sierra", "10.12"), ("macOS High Sierra", "10.13"),
        ("macOS Mojave", "10.14"), ("macOS Catalina", "10.15"), ("macOS Big Sur", "11.0"),
        ("macOS Monterey", "12.0"), ("macOS Ventura", "13.0"), ("macOS Sonoma", "14.0"),
        ("macOS Sequoia", "15.0"), ("macOS Tahoe", "26.0"), ("macOS Golden Gate", "27.0"),
    ]

    /// The version an installer's name stands for, e.g. "macOS Sonoma" → 14.0.
    static func knownVersion(forName name: String) -> MacOSVersion? {
        names.first { $0.name == name }?.version
    }

    /// The name of a macOS version, e.g. 15.6 → "macOS Sequoia"; "macOS 28" for one not known yet.
    static func name(for version: MacOSVersion) -> String {
        let release =
            version.major == 10 ? MacOSVersion(major: 10, minor: version.minor) : MacOSVersion(major: version.major)
        return names.first { $0.version == release }?.name ?? "macOS \(version.major)"
    }
}
