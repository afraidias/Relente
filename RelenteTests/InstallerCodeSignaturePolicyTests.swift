import Foundation
import Testing

@testable import Relente

@Suite struct InstallerCodeSignaturePolicyTests {
    @Test func `direct installer and executable both require resource verification`() throws {
        let (installer, executable, directory) = try makeInstaller()
        defer { try? FileManager.default.removeItem(at: directory) }
        var checks: [(URL, Bool)] = []

        let valid = InstallerCodeSignaturePolicy.isValid(
            installer: installer, executable: executable, packageBacked: false
        ) { url, validateResources in
            checks.append((url, validateResources))
            return true
        }

        #expect(valid)
        #expect(checks.count == 2)
        #expect(checks[0].0 == installer && checks[0].1)
        #expect(checks[1].0 == executable && checks[1].1)
    }

    @Test func `a verified package can skip only the app resource envelope`() throws {
        let (installer, executable, directory) = try makeInstaller()
        defer { try? FileManager.default.removeItem(at: directory) }
        var checks: [(URL, Bool)] = []

        let valid = InstallerCodeSignaturePolicy.isValid(
            installer: installer, executable: executable, packageBacked: true
        ) { url, validateResources in
            checks.append((url, validateResources))
            return true
        }

        #expect(valid)
        #expect(checks.count == 2)
        #expect(checks[0].0 == installer && !checks[0].1)
        #expect(checks[1].0 == executable && checks[1].1)
    }

    @Test func `a missing createinstallmedia executable is rejected before signature checks`() throws {
        let (installer, executable, directory) = try makeInstaller()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.removeItem(at: executable)
        var signatureChecks = 0

        let valid = InstallerCodeSignaturePolicy.isValid(
            installer: installer, executable: executable, packageBacked: false
        ) { _, _ in
            signatureChecks += 1
            return true
        }

        #expect(!valid)
        #expect(signatureChecks == 0)
    }

    @Test func `replaced executable symlink fails the second prelaunch validation`() throws {
        let (installer, executable, directory) = try makeInstaller()
        defer { try? FileManager.default.removeItem(at: directory) }
        let verifier: (URL, Bool) -> Bool = { _, _ in true }
        #expect(
            InstallerCodeSignaturePolicy.isValid(
                installer: installer, executable: executable, packageBacked: false,
                verifyAppleSignature: verifier))

        try FileManager.default.removeItem(at: executable)
        try FileManager.default.createSymbolicLink(at: executable, withDestinationURL: directory)

        #expect(
            !InstallerCodeSignaturePolicy.isValid(
                installer: installer, executable: executable, packageBacked: false,
                verifyAppleSignature: verifier))
    }

    private func makeInstaller() throws -> (URL, URL, URL) {
        let directory = URL(filePath: "/private/tmp/Relente-" + UUID().uuidString)
        let installer = directory.appending(path: "Install macOS Test.app")
        let executable = installer.appending(path: "Contents/Resources/createinstallmedia")
        try FileManager.default.createDirectory(
            at: executable.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data().write(to: executable)
        return (installer, executable, directory)
    }
}
