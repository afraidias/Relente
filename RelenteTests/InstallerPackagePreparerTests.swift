import Foundation
import Testing

@testable import Relente

struct InstallerPackagePreparerTests {

    @Test func `accepts the Apple Software Update package signature`() {
        #expect(
            InstallerPackageProvenance.hasAppleSoftwareUpdateSignature(
                """
                Status: signed Apple Software
                Certificate Chain:
                   1. Software Update
                   2. Apple Software Update Certification Authority
                   3. Apple Root CA
                """))
    }

    @Test(arguments: [
        "Status: invalid signature",
        "Status: signed by a certificate trusted by macOS\nCertificate Chain:\n1. Developer ID Installer: Example\n3. Apple Root CA",
        "Status: signed Apple Software\nCertificate Chain:\n1. Developer ID Installer: Example\n3. Apple Root CA",
        "Status: signed Apple Software\nCertificate Chain:\n1. Software Update\n2. Untrusted Root CA",
    ])
    func `rejects invalid and non Apple package signatures`(output: String) {
        #expect(!InstallerPackageProvenance.hasAppleSoftwareUpdateSignature(output))
    }

    @Test func `copies verifies expands and links SharedSupport in a private directory`() async throws {
        let source = try makePackage()
        defer { try? FileManager.default.removeItem(at: source.deletingLastPathComponent()) }
        let tool = FakePackageTool()

        let prepared = try await InstallerPackagePreparer.prepare(source) { executable, arguments in
            tool.run(executable, arguments)
        }
        defer { prepared.remove() }

        let stagedPackage = prepared.temporaryDirectory.appending(path: "InstallAssistant.pkg")
        let sharedSupport = prepared.temporaryDirectory.appending(path: "expanded/SharedSupport.dmg")
        let linkedSharedSupport = prepared.appURL.appending(path: "Contents/SharedSupport/SharedSupport.dmg")
        let directoryAttributes = try FileManager.default.attributesOfItem(atPath: prepared.temporaryDirectory.path)
        let packageAttributes = try FileManager.default.attributesOfItem(atPath: stagedPackage.path)
        let supportAttributes = try FileManager.default.attributesOfItem(atPath: sharedSupport.path)
        let linkedAttributes = try FileManager.default.attributesOfItem(atPath: linkedSharedSupport.path)

        #expect(directoryAttributes[.posixPermissions] as? NSNumber == 0o700)
        #expect(packageAttributes[.posixPermissions] as? NSNumber == 0o600)
        #expect(try Data(contentsOf: stagedPackage) == Data("fixture package".utf8))
        #expect(supportAttributes[.systemFileNumber] as? NSNumber == linkedAttributes[.systemFileNumber] as? NSNumber)
        #expect(tool.arguments(for: "--check-signature") == [stagedPackage.path])
        #expect(
            tool.arguments(for: "--expand-full") == [
                stagedPackage.path, prepared.temporaryDirectory.appending(path: "expanded").path,
            ])
        #expect(tool.executables == ["/usr/sbin/pkgutil", "/usr/sbin/pkgutil"])

        let temporaryDirectory = prepared.temporaryDirectory
        prepared.remove()
        #expect(!FileManager.default.fileExists(atPath: temporaryDirectory.path))
    }

    @Test func `rejects an invalid package signature before expansion and cleans up`() async throws {
        let source = try makePackage()
        defer { try? FileManager.default.removeItem(at: source.deletingLastPathComponent()) }
        let tool = FakePackageTool(signatureOutput: "Status: invalid signature")

        await #expect(throws: InstallerPackagePreparer.PreparationError.self) {
            try await InstallerPackagePreparer.prepare(source) { executable, arguments in
                tool.run(executable, arguments)
            }
        }

        let checkPath = try #require(tool.arguments(for: "--check-signature").first)
        #expect(tool.arguments(for: "--expand-full").isEmpty)
        #expect(!FileManager.default.fileExists(atPath: URL(filePath: checkPath).deletingLastPathComponent().path))
    }

    @Test func `rejects a package without the required installer layout and cleans up`() async throws {
        let source = try makePackage()
        defer { try? FileManager.default.removeItem(at: source.deletingLastPathComponent()) }
        let tool = FakePackageTool(createsInstallerLayout: false)

        await #expect(throws: InstallerPackagePreparer.PreparationError.self) {
            try await InstallerPackagePreparer.prepare(source) { executable, arguments in
                tool.run(executable, arguments)
            }
        }

        let expandPath = try #require(tool.arguments(for: "--expand-full").last)
        #expect(!FileManager.default.fileExists(atPath: URL(filePath: expandPath).deletingLastPathComponent().path))
    }

    @Test func `cancellation after expansion removes the private extraction`() async throws {
        let source = try makePackage()
        defer { try? FileManager.default.removeItem(at: source.deletingLastPathComponent()) }
        let tool = FakePackageTool()
        let cancellation = CreateInstallMediaCancellation()

        await #expect(throws: InstallerPackagePreparer.PreparationError.cancelled) {
            try await InstallerPackagePreparer.prepare(
                source,
                run: { executable, arguments in
                    let output = tool.run(executable, arguments)
                    if arguments.first == "--expand-full" { cancellation.cancel() }
                    return output
                },
                isCancelled: { cancellation.isRequested })
        }

        let stagedPackage = try #require(tool.arguments(for: "--check-signature").first)
        #expect(!FileManager.default.fileExists(atPath: URL(filePath: stagedPackage).deletingLastPathComponent().path))
    }

    @Test func `rejects a symbolic link to the package`() async throws {
        let source = try makePackage()
        defer { try? FileManager.default.removeItem(at: source.deletingLastPathComponent()) }
        let link = source.deletingLastPathComponent().appending(path: "Linked.pkg")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: source)
        let tool = FakePackageTool()

        await #expect(throws: InstallerPackagePreparer.PreparationError.self) {
            try await InstallerPackagePreparer.prepare(link) { executable, arguments in
                tool.run(executable, arguments)
            }
        }

        #expect(tool.executables.isEmpty)
    }

    @Test func `rejects symlinks in a path ancestor`() throws {
        let directory = URL(filePath: "/private/tmp/RelentePathTest-\(UUID().uuidString)")
        let target = directory.appending(path: "target")
        let alias = directory.appending(path: "alias")
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: target)
        let package = target.appending(path: "InstallAssistant.pkg")
        try Data([1]).write(to: package)

        #expect(!InstallerPathSafety.isSafe(alias.appending(path: "InstallAssistant.pkg")))
        #expect(InstallerPathSafety.isSafe(package))
    }

    private func makePackage() throws -> URL {
        let directory = URL(filePath: "/private/tmp/RelentePackageTest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        let package = directory.appending(path: "Source.pkg")
        try Data("fixture package".utf8).write(to: package)
        return package
    }
}

private final class FakePackageTool: @unchecked Sendable {
    private let lock = NSLock()
    nonisolated(unsafe) private var calls: [(String, [String])] = []
    private let signatureOutput: String
    private let createsInstallerLayout: Bool

    init(signatureOutput: String? = nil, createsInstallerLayout: Bool = true) {
        self.signatureOutput = signatureOutput ?? Self.appleSignature
        self.createsInstallerLayout = createsInstallerLayout
    }

    var executables: [String] {
        lock.lock()
        defer { lock.unlock() }
        return calls.map(\.0)
    }

    func arguments(for option: String) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        guard let call = calls.first(where: { $0.1.first == option }) else { return [] }
        return Array(call.1.dropFirst())
    }

    nonisolated func run(_ executable: String, _ arguments: [String]) -> Data? {
        lock.lock()
        defer { lock.unlock() }
        calls.append((executable, arguments))
        if arguments.first == "--check-signature" { return Data(signatureOutput.utf8) }
        guard arguments.first == "--expand-full", arguments.count == 3, createsInstallerLayout else {
            return arguments.first == "--expand-full" ? Data() : nil
        }
        let expanded = URL(filePath: arguments[2])
        let app = expanded.appending(path: "Payload/Applications/Install macOS Test.app")
        do {
            try FileManager.default.createDirectory(
                at: app.appending(path: "Contents/Resources"), withIntermediateDirectories: true)
            try Data("tool".utf8).write(to: app.appending(path: "Contents/Resources/createinstallmedia"))
            try Data("shared support".utf8).write(to: expanded.appending(path: "SharedSupport.dmg"))
            return Data()
        } catch {
            return nil
        }
    }

    private static let appleSignature = """
        Status: signed Apple Software
        Certificate Chain:
           1. Software Update
           2. Apple Software Update Certification Authority
           3. Apple Root CA
        """
}
