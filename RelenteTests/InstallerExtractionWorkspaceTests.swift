import Darwin
import Foundation
import Testing

@testable import Relente

struct InstallerExtractionWorkspaceTests {
    @Test func volumeBudgetIsBoundedAndRejectsOversizedInputs() throws {
        #expect(try InstallerExtractionWorkspace.capacity(for: 12_205_110_942) == 27)
        #expect(try InstallerExtractionWorkspace.capacity(for: 18_389_893_051) == 39)
        #expect(throws: InstallerExtractionWorkspace.Failure.self) { try InstallerExtractionWorkspace.capacity(for: 0) }
        #expect(throws: InstallerExtractionWorkspace.Failure.self) {
            try InstallerExtractionWorkspace.capacity(for: Int64.max)
        }
    }

    @Test func onlyTheReturnedImageWithTheExpectedMountpointMayBeDetached() throws {
        let mount = URL(filePath: "/private/tmp/owned-workspace")
        func response(_ device: String, _ path: String) throws -> Data {
            try PropertyListSerialization.data(
                fromPropertyList: [
                    "system-entities": [
                        ["content-hint": "GUID_partition_scheme", "dev-entry": device], ["mount-point": path],
                    ]
                ], format: .xml, options: 0)
        }
        #expect(
            try InstallerExtractionWorkspace.ownedDevice(from: response("/dev/disk99", mount.path), mount: mount)
                == "/dev/disk99")
        #expect(
            try InstallerExtractionWorkspace.ownedDevice(from: response("/dev/disk99s1", mount.path), mount: mount)
                == nil)
        #expect(
            try InstallerExtractionWorkspace.ownedDevice(from: response("/dev/disk99", "/Volumes/other"), mount: mount)
                == nil)
        let ambiguous = try PropertyListSerialization.data(
            fromPropertyList: [
                "system-entities": [
                    ["content-hint": "GUID_partition_scheme", "dev-entry": "/dev/disk99"],
                    ["content-hint": "GUID_partition_scheme", "dev-entry": "/dev/disk100"],
                    ["mount-point": mount.path],
                ]
            ], format: .xml, options: 0)
        #expect(InstallerExtractionWorkspace.ownedDevice(from: ambiguous, mount: mount) == nil)

    }
    @Test func rootRecoveryDiscoveryDoesNotTrustNamesOrFollowLinks() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let target = root.appending(path: "unrelated")
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: false)
        let alias = root.appending(path: "Relente-ABC123")
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: target)
        #expect(try !InstallerPrivateDirectory.hasUnfinishedWork(in: root, ownedBy: getuid()))
        try FileManager.default.removeItem(at: alias)
        try FileManager.default.createDirectory(at: alias, withIntermediateDirectories: false)
        #expect(try InstallerPrivateDirectory.hasUnfinishedWork(in: root, ownedBy: getuid()))
        #expect(try FileManager.default.contentsOfDirectory(atPath: alias.path).isEmpty)
    }

}
