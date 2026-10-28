//
//  HelperContractTests.swift
//  RelenteTests
//
//  The fixed values the app and the helper agree on: code-signing requirements (helper rule 2),
//  the diskutil command (rule 1) and the erase right (rule 5).
//

import Foundation
import Security
import Testing

@testable import Relente

struct HelperContractTests {

    // MARK: - Code signing (rule 2)

    @Test func `the helper only accepts the Relente app signed by the team`() {
        #expect(
            CodeSigningRequirement.app
                == #"identifier "com.afraidias.Relente" and anchor apple generic and certificate leaf[subject.OU] = "99TLZFAX53""#
        )
    }

    @Test func `the app only talks to the helper signed by the team`() {
        #expect(
            CodeSigningRequirement.helper
                == #"identifier "com.afraidias.Relente.Helper" and anchor apple generic and certificate leaf[subject.OU] = "99TLZFAX53""#
        )
    }

    @Test(arguments: [CodeSigningRequirement.app, CodeSigningRequirement.helper])
    func `both requirements are valid for the Security framework`(requirement: String) {
        var compiled: SecRequirement?
        #expect(SecRequirementCreateWithString(requirement as CFString, [], &compiled) == errSecSuccess)
        #expect(compiled != nil)
    }

    // MARK: - diskutil (rule 1)

    @Test func `diskutil runs from its fixed path`() {
        #expect(DiskutilCommand.executable == URL(filePath: "/usr/sbin/diskutil"))
    }

    @Test func `the drive is erased as MyVolume, Mac OS Extended (Journaled), GPT`() {
        #expect(DiskutilCommand.eraseArguments(for: "disk4") == ["eraseDisk", "JHFS+", "MyVolume", "GPT", "disk4"])
    }

    @Test(arguments: ["disk4s1", "disk4; rm -rf /", "-force", ""])
    func `no arguments for anything but a whole disk`(identifier: String) {
        #expect(DiskutilCommand.eraseArguments(for: identifier) == nil)
    }

    // MARK: - Authorization right (rule 5)

    @Test func `the erase right has its own name`() {
        #expect(EraseRight.name == "com.afraidias.Relente.erase")
    }

    @Test func `every erase asks an administrator, through macOS's non-shared admin rule`() {
        let rule = EraseRight.rule
        #expect(rule["class"] as? String == "rule")
        #expect(rule["rule"] as? [String] == ["authenticate-admin-nonshared"])
        #expect(rule["version"] as? Int == 2)
    }

    // MARK: - Protocol

    @Test func `the protocol has a version the app checks`() {
        #expect(HelperIdentity.protocolVersion == 5)
        #expect(HelperIdentity.supports(HelperIdentity.protocolVersion))
        #expect(!HelperIdentity.supports(HelperIdentity.protocolVersion - 1))
        #expect(!HelperIdentity.supports(nil))
    }

    @Test func `package resource exception requires root-owned private extraction`() {
        #expect(InstallerPackageOwnershipPolicy.isPrivateRootDirectory(owner: 0, mode: 0o40700))
        #expect(!InstallerPackageOwnershipPolicy.isPrivateRootDirectory(owner: 501, mode: 0o40700))
        #expect(!InstallerPackageOwnershipPolicy.isPrivateRootDirectory(owner: 0, mode: 0o40777))
        #expect(InstallerPackageOwnershipPolicy.isRootOwnedEntry(owner: 0, mode: 0o100600))
        #expect(!InstallerPackageOwnershipPolicy.isRootOwnedEntry(owner: 501, mode: 0o100600))
    }

    @Test func `helper operations cannot overlap and the gate releases`() async {
        let gate = HelperOperationGate()
        let owner = UUID()
        let results = await withTaskGroup(of: Bool.self, returning: [Bool].self) { group in
            for _ in 0..<32 { group.addTask { gate.begin(owner: owner) } }
            var results: [Bool] = []
            for await result in group { results.append(result) }
            return results
        }

        #expect(results.filter { $0 }.count == 1)
        #expect(gate.isActive)
        #expect(gate.owns(owner))
        let otherConnection = UUID()
        #expect(!gate.owns(otherConnection))
        gate.end(owner: otherConnection)
        #expect(gate.owns(owner))
        gate.end(owner: owner)
        #expect(!gate.isActive)
        #expect(gate.begin(owner: otherConnection))
    }

    @Test func `the daemon plist uses the current launchd label`() throws {
        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let plistURL = repositoryURL.appending(path: "Config/com.afraidias.Relente.Helper.LiveCreation.plist")
        let data = try Data(contentsOf: plistURL)
        let plist = try #require(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])

        #expect(plist["Label"] as? String == "com.afraidias.Relente.Helper.LiveCreation")
        let machServices = try #require(plist["MachServices"] as? [String: Bool])
        #expect(machServices[HelperIdentity.machServiceName] == true)
    }
}
