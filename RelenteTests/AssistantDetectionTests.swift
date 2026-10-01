//
//  AssistantDetectionTests.swift
//  RelenteTests
//
//  The assistant following the installers and drives on the Mac, with sample services.
//  Spec: specs/007-real-detection/spec.md
//

import Foundation
import Testing

@testable import Relente

@MainActor
struct AssistantDetectionTests {

    // MARK: - Sample data

    private let tahoe = Self.installer("macOS Tahoe", "26.0")
    private let sequoia = Self.installer("macOS Sequoia", "15.6")
    private let catalina = Self.installer("macOS Catalina", "10.15.7")

    private let stick = Self.drive("Stick")
    private let card = Self.drive("Card")

    private static func installer(_ name: String, _ version: MacOSVersion) -> InstallerSource {
        InstallerSource(
            url: URL(filePath: "/Applications/Install \(name).app"), name: name, version: version, kind: .app,
            size: 16_800_000_000)
    }

    private static func drive(_ name: String) -> Drive {
        Drive(
            id: name, bsdName: "disk9", name: name, model: name, kind: .usbDrive, capacity: 64_000_000_000,
            usedSpace: .bytes(0))
    }

    /// Waits until `condition` holds, letting the assistant's tasks run. Fails after about 2 s.
    private func waitUntil(_ condition: () -> Bool, sourceLocation: SourceLocation = #_sourceLocation) async {
        for _ in 0..<200 {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
        Issue.record("The condition never held", sourceLocation: sourceLocation)
    }

    // MARK: - Following the services

    @Test func `starts empty and follows the services' lists`() async {
        let installers = SampleInstallerService(installers: [sequoia])
        let drives = SampleDriveService(drives: [])
        let assistant = Assistant(installerService: installers, driveService: drives)
        #expect(assistant.installers.isEmpty)

        let following = Task { await assistant.start() }
        defer { following.cancel() }
        await waitUntil { assistant.installers == [sequoia] }
        #expect(assistant.selectedInstaller == sequoia)
        #expect(assistant.drives.isEmpty)

        installers.send([sequoia, tahoe])
        drives.send([stick, card])
        await waitUntil { assistant.installers.count == 2 && assistant.drives.count == 2 }
        #expect(assistant.installers == [tahoe, sequoia])
        #expect(assistant.drives == [stick, card])
    }

    @Test func `the newest supported installer is selected when the list first fills`() {
        let assistant = Assistant(installers: [catalina, sequoia, tahoe], drives: [])
        #expect(assistant.installers == [tahoe, sequoia, catalina])
        #expect(assistant.selectedInstaller == tahoe)
    }
}

// MARK: - Unplugging and installers disappearing

extension AssistantDetectionTests {

    /// An assistant on USB Drive with `stick` chosen, or on Review when `toReview`.
    private func assistantWithStick(toReview: Bool = false) -> Assistant {
        let assistant = Assistant(installers: [tahoe, sequoia], drives: [stick, card])
        assistant.continueToDrive()
        assistant.screenChangeDidEnd()
        assistant.selectDrive(stick.id)
        if toReview {
            assistant.continueToReview()
            assistant.screenChangeDidEnd()
        }
        return assistant
    }

    @Test func `unplugging the chosen drive on USB Drive clears the selection`() {
        let assistant = assistantWithStick()
        assistant.updateDrives([card])
        #expect(assistant.step == .drive)
        #expect(assistant.selectedDriveID == nil)
        #expect(!assistant.canContinueToReview)
    }

    @Test func `unplugging another drive keeps the selection`() {
        let assistant = assistantWithStick()
        assistant.updateDrives([stick])
        #expect(assistant.selectedDrive == stick)
    }

    @Test func `a drive plugged in is never selected by itself`() {
        let assistant = Assistant(installers: [tahoe], drives: [])
        assistant.continueToDrive()
        assistant.updateDrives([stick])
        #expect(assistant.selectedDriveID == nil)
    }

    @Test func `unplugging the chosen drive on Review goes back to USB Drive and says so`() {
        let assistant = assistantWithStick(toReview: true)
        assistant.updateDrives([card])
        #expect(assistant.step == .drive)
        #expect(assistant.lastChange == ScreenChange(direction: .back, style: .slide))
        #expect(assistant.selectedDriveID == nil)
        #expect(assistant.disconnection?.driveName == "Stick")
    }

    @Test func `unplugging the drive while creating fails the run`() async {
        let assistant = Assistant(
            installerService: SampleInstallerService(installers: [tahoe]),
            driveService: SampleDriveService(drives: [stick]),
            creationService: NeverEndingCreationService())
        assistant.updateInstallers([tahoe])
        assistant.updateDrives([stick])
        assistant.continueToDrive()
        assistant.screenChangeDidEnd()
        assistant.selectDrive(stick.id)
        assistant.continueToReview()
        assistant.screenChangeDidEnd()
        assistant.hasConfirmed = true
        assistant.eraseAndCreate()
        assistant.screenChangeDidEnd()

        assistant.updateDrives([])
        #expect(assistant.step == .creating)
        #expect(assistant.creation?.failure?.reason == .driveDisconnected)
    }

    @Test func `the chosen installer disappearing on USB Drive or Review goes back to Installer`() {
        for toReview in [false, true] {
            let assistant = assistantWithStick(toReview: toReview)
            assistant.updateInstallers([sequoia])
            #expect(assistant.step == .installer)
            #expect(assistant.selectedInstaller == sequoia)
            #expect(assistant.selectedDriveID == nil)
        }
    }

    @Test func `the chosen installer disappearing on Installer selects the newest supported one`() {
        let assistant = Assistant(installers: [tahoe, sequoia, catalina], drives: [])
        assistant.updateInstallers([sequoia, catalina])
        #expect(assistant.step == .installer)
        #expect(assistant.selectedInstaller == sequoia)
    }

    @Test func `another installer disappearing keeps the selection`() {
        let assistant = assistantWithStick()
        assistant.updateInstallers([tahoe])
        #expect(assistant.step == .drive)
        #expect(assistant.selectedInstaller == tahoe)
    }

    // MARK: Unsupported installers

    @Test func `an unsupported installer can't be selected`() {
        let assistant = Assistant(installers: [tahoe, catalina], drives: [])
        assistant.selectInstaller(catalina.id)
        #expect(assistant.selectedInstaller == tahoe)
    }

    @Test func `arrow keys skip unsupported installers`() {
        let assistant = Assistant(installers: [tahoe, catalina, sequoia], drives: [])
        assistant.moveSelection(by: 1)
        #expect(assistant.selectedInstaller == sequoia)
        assistant.moveSelection(by: 1)
        #expect(assistant.selectedInstaller == sequoia)
    }

    @Test func `with only unsupported installers nothing is selected`() {
        let assistant = Assistant(installers: [catalina], drives: [])
        #expect(assistant.selectedInstaller == nil)
        assistant.continueToDrive()
        #expect(assistant.step == .installer)
    }
}

// MARK: - Stub service

/// A run that never ends on its own, like one in progress.
nonisolated private struct NeverEndingCreationService: CreationService {
    var isSimulated: Bool { true }

    func create(installer: InstallerSource, drive: Drive) -> AsyncStream<CreationEvent> {
        AsyncStream { _ in }
    }
}

// MARK: - Choosing an installer

extension AssistantDetectionTests {

    @Test func `a chosen installer is added and selected`() async {
        let chosen = InstallerSource(
            url: URL(filePath: "/Users/Shared/macOS Sequoia.dmg"), name: "macOS Sequoia", version: "15.6",
            kind: .diskImage, size: 15_200_000_000)
        let assistant = Assistant(
            installerService: SampleInstallerService(installers: [tahoe], choosable: [chosen]),
            driveService: SampleDriveService(drives: []))
        assistant.updateInstallers([tahoe])

        await assistant.chooseInstaller(at: chosen.url)
        #expect(assistant.installers == [tahoe, chosen])
        #expect(assistant.selectedInstaller == chosen)
        #expect(assistant.installerError == nil)
    }

    @Test func `choosing an installer already listed selects it`() async {
        let assistant = Assistant(
            installerService: SampleInstallerService(installers: [tahoe, sequoia], choosable: [sequoia]),
            driveService: SampleDriveService(drives: []))
        assistant.updateInstallers([tahoe, sequoia])

        await assistant.chooseInstaller(at: sequoia.url)
        #expect(assistant.installers == [tahoe, sequoia])
        #expect(assistant.selectedInstaller == sequoia)
    }

    @Test func `a chosen installer too old is shown but not selected`() async {
        let assistant = Assistant(
            installerService: SampleInstallerService(installers: [tahoe], choosable: [catalina]),
            driveService: SampleDriveService(drives: []))
        assistant.updateInstallers([tahoe])

        await assistant.chooseInstaller(at: catalina.url)
        #expect(assistant.installers == [tahoe, catalina])
        #expect(assistant.selectedInstaller == tahoe)
    }

    @Test func `a file that isn't an installer shows the alert and adds nothing`() async {
        let assistant = Assistant(installers: [tahoe], drives: [])
        await assistant.chooseInstaller(at: URL(filePath: "/Users/Shared/Notes.txt"))
        #expect(assistant.installers == [tahoe])
        #expect(assistant.installerError == .notAnInstaller(fileName: "Notes.txt"))

        assistant.dismissInstallerError()
        #expect(assistant.installerError == nil)
    }
}

// MARK: - Ejecting

extension AssistantDetectionTests {

    /// An assistant on Done with `stick`, whose drive service ejects with `ejectError`.
    private func assistantOnDone(ejectError: EjectError? = nil) async -> Assistant {
        let assistant = Assistant(
            installerService: SampleInstallerService(installers: [tahoe]),
            driveService: SampleDriveService(drives: [stick], ejectError: ejectError),
            creationService: FinishingCreationService())
        assistant.updateInstallers([tahoe])
        assistant.updateDrives([stick])
        assistant.continueToDrive()
        assistant.screenChangeDidEnd()
        assistant.selectDrive(stick.id)
        assistant.continueToReview()
        assistant.screenChangeDidEnd()
        assistant.hasConfirmed = true
        assistant.eraseAndCreate()
        await waitUntil { assistant.step == .done }
        assistant.screenChangeDidEnd()
        return assistant
    }

    @Test func `eject goes back to the installer screen`() async {
        let assistant = await assistantOnDone()
        await assistant.eject()
        #expect(assistant.step == .installer)
        #expect(assistant.ejectFailure == nil)
        #expect(!assistant.isEjecting)
    }

    @Test func `when macOS refuses, eject stays on Done with the reason`() async {
        let assistant = await assistantOnDone(ejectError: .refused(reason: "The disk is in use by Finder."))
        await assistant.eject()
        #expect(assistant.step == .done)
        #expect(assistant.ejectFailure == .refused(reason: "The disk is in use by Finder."))
        #expect(!assistant.isEjecting)
    }

    @Test func `cancel keeps Done, try again asks again, force eject goes back`() async {
        let assistant = await assistantOnDone(ejectError: .refused(reason: nil))
        await assistant.eject()
        assistant.dismissEjectFailure()
        #expect(assistant.ejectFailure == nil)
        #expect(assistant.step == .done)

        await assistant.eject()
        #expect(assistant.ejectFailure == .refused(reason: nil))

        await assistant.forceEject()
        #expect(assistant.step == .installer)
        #expect(assistant.ejectFailure == nil)
    }

    @Test func `a drive already unplugged just goes back`() async {
        let assistant = await assistantOnDone(ejectError: .refused(reason: nil))
        assistant.updateDrives([])
        await assistant.eject()
        #expect(assistant.step == .installer)
        #expect(assistant.ejectFailure == nil)
    }

    @Test func `a drive the service no longer finds just goes back`() async {
        let assistant = await assistantOnDone(ejectError: .notConnected)
        await assistant.eject()
        #expect(assistant.step == .installer)
        #expect(assistant.ejectFailure == nil)
    }
}

/// A run that finishes at once.
nonisolated private struct FinishingCreationService: CreationService {
    var isSimulated: Bool { true }

    func create(installer: InstallerSource, drive: Drive) -> AsyncStream<CreationEvent> {
        AsyncStream { continuation in
            continuation.yield(.finished)
            continuation.finish()
        }
    }
}
