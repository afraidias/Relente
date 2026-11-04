import Foundation

nonisolated enum AcquiredInstallerReader {
    /// Only for a candidate just derived from a verified package; it is never helper authority.
    @concurrent
    static func read(_ prepared: PreparedInstallerPackage, expected: InstallerOSIdentity) async throws
        -> InstallerSource
    {
        let app = prepared.appURL
        let executable = app.appending(path: "Contents/Resources/createinstallmedia")
        guard InstallerPathSafety.isSafe(app), InstallerPathSafety.isSafe(executable),
            AppleInstallerCodeSignature.isValid(app, validateResources: false),
            AppleInstallerCodeSignature.isValid(executable)
        else { throw InstallerAcquisitionError.verificationFailed }
        let identity = try await InstallerSupportMetadata.identity(
            in: app.appending(path: "Contents/SharedSupport/SharedSupport.dmg"),
            workingDirectory: prepared.temporaryDirectory)
        guard identity == expected, let version = MacOSVersion(identity.version) else {
            throw InstallerAcquisitionError.preparationFailed
        }
        let info = try InstallerMetadata.appInfo(
            fromInfoPlist: Data(contentsOf: app.appending(path: "Contents/Info.plist")))
        let bytes = try prepared.packageURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        return InstallerSource(
            url: app, name: info.name, version: version, kind: .app, size: Int64(bytes),
            build: identity.build, packageURL: prepared.packageURL)
    }
}
