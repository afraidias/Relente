//
//  InstallerMetadataTests.swift
//  RelenteTests
//
//  The fixtures copy the parts of Apple's files that Relente reads.
//

import Foundation
import Testing

@testable import Relente

struct InstallerMetadataTests {

    private func infoPlist(identifier: String, displayName: String, version: String) -> Data {
        Data(
            """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
                <key>CFBundleDisplayName</key><string>\(displayName)</string>
                <key>CFBundleIdentifier</key><string>\(identifier)</string>
                <key>CFBundleShortVersionString</key><string>\(version)</string>
            </dict>
            </plist>
            """.utf8)
    }

    // MARK: - Installer app

    @Test func `reads the name without "Install" and the version from a known name`() throws {
        let info = try InstallerMetadata.appInfo(
            fromInfoPlist: infoPlist(
                identifier: "com.apple.InstallAssistant.macOSSequoia", displayName: "Install macOS Sequoia",
                version: "20.6.01"))
        #expect(info == InstallerMetadata.AppInfo(name: "macOS Sequoia", version: "15.0"))
    }

    @Test func `an unknown name takes its version from the installer's version`() throws {
        let info = try InstallerMetadata.appInfo(
            fromInfoPlist: infoPlist(
                identifier: "com.apple.InstallAssistant.macOSFuture", displayName: "Install macOS Future",
                version: "23.0.01"))
        #expect(info == InstallerMetadata.AppInfo(name: "macOS Future", version: "28.0"))
    }

    @Test func `an old installer is read, and isn't supported`() throws {
        let info = try InstallerMetadata.appInfo(
            fromInfoPlist: infoPlist(
                identifier: "com.apple.InstallAssistant.Catalina", displayName: "Install macOS Catalina",
                version: "15.7.03"))
        #expect(info.version == "10.15")
        #expect(info.version < .bigSur)
    }

    @Test(
        arguments: [
            ("15.7.03", "10.15"), ("14.6.06", "10.14"), ("16.4.12", "11.0"), ("19.6.02", "14.0"),
            ("20.6.01", "15.0"), ("21.0.01", "26.0"), ("22.0.01", "27.0"),
        ] as [(MacOSVersion, MacOSVersion)])
    func `maps installer versions to macOS versions`(installer: MacOSVersion, macOS: MacOSVersion) {
        #expect(InstallerMetadata.macOSVersion(forInstallerVersion: installer) == macOS)
    }

    @Test func `an app that isn't Apple's installer is rejected`() {
        #expect(throws: InstallerMetadata.ParseError.self) {
            try InstallerMetadata.appInfo(
                fromInfoPlist: infoPlist(
                    identifier: "com.example.Installer", displayName: "Install macOS", version: "1.0"))
        }
    }

    @Test func `a damaged Info.plist is rejected`() {
        #expect(throws: InstallerMetadata.ParseError.self) {
            try InstallerMetadata.appInfo(fromInfoPlist: Data("not a plist".utf8))
        }
    }

    // MARK: - SharedSupport catalog

    @Test func `reads the full version from the software update catalog`() throws {
        let catalog = Data(
            """
            <?xml version="1.0" encoding="UTF-8"?>
            <plist version="1.0">
            <dict>
                <key>Assets</key>
                <array>
                    <dict>
                        <key>Build</key><string>24G84</string>
                        <key>OSVersion</key><string>15.6</string>
                    </dict>
                </array>
            </dict>
            </plist>
            """.utf8)
        #expect(try InstallerMetadata.version(fromCatalog: catalog) == "15.6")
    }

    @Test func `a catalog without a version is rejected`() {
        let catalog = Data(#"<plist version="1.0"><dict><key>Assets</key><array/></dict></plist>"#.utf8)
        #expect(throws: InstallerMetadata.ParseError.self) {
            try InstallerMetadata.version(fromCatalog: catalog)
        }
    }

    // MARK: - InstallAssistant.pkg

    @Test func `reads the version and the installed size from a Distribution file`() throws {
        let distribution = Data(
            """
            <?xml version="1.0" encoding="utf-8"?>
            <installer-gui-script minSpecVersion="2">
                <title>SU_TITLE</title>
                <auxinfo>
                    <dict>
                        <key>BUILD</key>
                        <string>24G84</string>
                        <key>VERSION</key>
                        <string>15.6</string>
                    </dict>
                </auxinfo>
                <pkg-ref id="com.apple.pkg.InstallAssistant.macOSSequoia" installKBytes="15000000" version="20.6.01">#InstallAssistant.pkg</pkg-ref>
            </installer-gui-script>
            """.utf8)
        let info = try InstallerMetadata.packageInfo(fromDistribution: distribution)
        #expect(info == InstallerMetadata.PackageInfo(version: "15.6", installedSize: 15_360_000_000))
    }

    @Test func `a package without a version is rejected`() {
        let distribution = Data(
            #"<installer-gui-script><pkg-ref id="x" installKBytes="10"/></installer-gui-script>"#.utf8)
        #expect(throws: InstallerMetadata.ParseError.self) {
            try InstallerMetadata.packageInfo(fromDistribution: distribution)
        }
    }

    // MARK: - Names

    @Test func `names versions, and versions it doesn't know yet`() {
        #expect(InstallerMetadata.name(for: "15.6") == "macOS Sequoia")
        #expect(InstallerMetadata.name(for: "10.15.7") == "macOS Catalina")
        #expect(InstallerMetadata.name(for: "26.1") == "macOS Tahoe")
        #expect(InstallerMetadata.name(for: "28.0") == "macOS 28")
    }
}
