//
//  AssistantHelperTests.swift
//  RelenteTests
//
//  The assistant installing and uninstalling the system helper, with the sample helper service:
//  nothing is registered with macOS.
//  Spec: specs/008-system-helper/spec.md
//

import Foundation
import Testing

@testable import Relente

@MainActor
struct AssistantHelperTests {

    private func makeAssistant(_ helper: SampleHelperService) -> Assistant {
        Assistant(installers: InstallerSource.samples, drives: Drive.samples, helperService: helper)
    }

    /// Ends the screen change the last action started, as the view does when its animation ends.
    private func settle(_ assistant: Assistant) {
        assistant.screenChangeDidEnd()
    }

    // MARK: - Start

    @Test func `starts on Permissions when the helper isn't installed`() {
        let assistant = makeAssistant(SampleHelperService(status: .notInstalled))
        #expect(assistant.step == .permissions)
        #expect(assistant.helperStatus == .notInstalled)
    }

    @Test func `starts on Permissions when the helper waits for approval`() {
        #expect(makeAssistant(SampleHelperService(status: .needsApproval)).step == .permissions)
    }

    @Test func `starts on Installer when the helper is ready`() {
        let assistant = makeAssistant(SampleHelperService(status: .ready))
        #expect(assistant.step == .installer)
    }

    @Test func `Permissions has no step number`() {
        #expect(AssistantStep.permissions.stepNumber == nil)
        #expect(AssistantStep.installer.stepNumber == 1)
    }

    // MARK: - Installing

    @Test func `installing waits for approval, then the helper is ready`() async {
        let helper = SampleHelperService(status: .notInstalled, approvalDelay: nil)
        let assistant = makeAssistant(helper)

        await assistant.installHelper()
        #expect(assistant.helperStatus == .needsApproval)

        assistant.refreshHelperStatus()
        #expect(assistant.helperStatus == .needsApproval)

        helper.approve()
        assistant.refreshHelperStatus()
        #expect(assistant.helperStatus == .ready)
    }

    @Test func `Continue only works once the helper is ready, and crossfades to Installer`() async {
        let helper = SampleHelperService(status: .notInstalled, approvalDelay: nil)
        let assistant = makeAssistant(helper)

        assistant.continueFromPermissions()
        #expect(assistant.step == .permissions)

        await assistant.installHelper()
        helper.approve()
        assistant.refreshHelperStatus()
        assistant.continueFromPermissions()
        #expect(assistant.step == .installer)
        #expect(assistant.lastChange == ScreenChange(direction: .forward, style: .crossfade))
    }

    @Test func `a failed registration shows the failure until trying again`() async {
        let error = HelperError.registrationFailed(reason: "Operation not permitted")
        let assistant = makeAssistant(SampleHelperService(status: .notInstalled, registerError: error))

        await assistant.installHelper()
        #expect(assistant.helperStatus == .failed(error))

        // The periodic refresh doesn't hide it.
        assistant.refreshHelperStatus()
        #expect(assistant.helperStatus == .failed(error))
    }

    @Test func `installing does nothing outside Permissions`() async {
        let helper = SampleHelperService(status: .ready)
        let assistant = makeAssistant(helper)
        await assistant.installHelper()
        #expect(assistant.step == .installer)
        #expect(assistant.helperStatus == .ready)
    }

    // MARK: - Turned off while the app runs

    /// Takes a ready assistant to `step` with the first installer and drive chosen.
    private func goTo(_ step: AssistantStep, _ assistant: Assistant) {
        if step == .installer { return }
        assistant.continueToDrive()
        settle(assistant)
        assistant.selectDrive(Drive.samples[0].id)
        if step == .review {
            assistant.continueToReview()
            settle(assistant)
        }
    }

    @Test(arguments: [AssistantStep.installer, .drive, .review])
    func `turning the helper off goes back to Permissions, keeping the choices`(step: AssistantStep) async {
        let helper = SampleHelperService(status: .ready)
        let assistant = makeAssistant(helper)
        goTo(step, assistant)
        let installer = assistant.selectedInstallerID
        let drive = assistant.selectedDriveID

        try? await helper.unregister()
        assistant.refreshHelperStatus()
        #expect(assistant.step == .permissions)
        #expect(assistant.lastChange == ScreenChange(direction: .back, style: .crossfade))
        #expect(assistant.helperTurnedOff != nil)
        #expect(assistant.selectedInstallerID == installer)
        #expect(assistant.selectedDriveID == drive)
    }

    @Test func `once ready again, Continue goes to Installer with the choices kept`() async {
        let helper = SampleHelperService(status: .ready, approvalDelay: nil)
        let assistant = makeAssistant(helper)
        goTo(.review, assistant)
        let drive = assistant.selectedDriveID

        try? await helper.unregister()
        assistant.refreshHelperStatus()
        settle(assistant)
        await assistant.installHelper()
        helper.approve()
        assistant.refreshHelperStatus()
        assistant.continueFromPermissions()
        #expect(assistant.step == .installer)
        #expect(assistant.selectedDriveID == drive)
    }

    @Test func `a creation is never interrupted`() async {
        let helper = SampleHelperService(status: .ready)
        let assistant = Assistant(
            installers: InstallerSource.samples, drives: Drive.samples, helperService: helper,
            creationService: SimulatedCreationService(speed: .normal, failure: nil))
        goTo(.review, assistant)
        assistant.hasConfirmed = true
        await assistant.eraseAndCreate()
        settle(assistant)

        try? await helper.unregister()
        assistant.refreshHelperStatus()
        #expect(assistant.step == .creating)
        #expect(assistant.helperTurnedOff == nil)
    }

    @Test func `turning the helper off does not interrupt Done`() async {
        let helper = SampleHelperService(status: .ready)
        let assistant = Assistant(
            installers: InstallerSource.samples, drives: Drive.samples, helperService: helper,
            creationService: SimulatedCreationService(speed: .fast, failure: nil))
        goTo(.review, assistant)
        assistant.hasConfirmed = true
        await assistant.eraseAndCreate()

        for _ in 0..<100 where assistant.step != .done {
            try? await Task.sleep(for: .milliseconds(50))
        }
        #expect(assistant.step == .done)

        try? await helper.unregister()
        assistant.refreshHelperStatus()
        #expect(assistant.step == .done)
    }

    @Test func `a status that stays ready changes nothing`() {
        let assistant = makeAssistant(SampleHelperService(status: .ready))
        assistant.refreshHelperStatus()
        #expect(assistant.step == .installer)
        #expect(assistant.helperTurnedOff == nil)
    }

    // MARK: - Uninstalling

    @Test func `uninstalling goes to Permissions, keeping the installer and forgetting the drive`() async {
        let assistant = makeAssistant(SampleHelperService(status: .ready))
        let installer = assistant.selectedInstallerID
        assistant.continueToDrive()
        settle(assistant)
        assistant.selectDrive(Drive.samples[0].id)

        await assistant.uninstallHelper()
        #expect(assistant.step == .permissions)
        #expect(assistant.helperStatus == .notInstalled)
        #expect(assistant.selectedInstallerID == installer)
        #expect(assistant.selectedDriveID == nil)
        #expect(assistant.lastChange == ScreenChange(direction: .back, style: .crossfade))
    }

    @Test func `the menu item asks for confirmation first`() async {
        let assistant = makeAssistant(SampleHelperService(status: .ready))
        assistant.requestHelperUninstall()
        #expect(assistant.isConfirmingHelperUninstall)
        #expect(assistant.step == .installer)

        await assistant.uninstallHelper()
        #expect(!assistant.isConfirmingHelperUninstall)
        #expect(assistant.step == .permissions)
    }

    @Test func `uninstalling isn't offered when the helper isn't installed`() async {
        let assistant = makeAssistant(SampleHelperService(status: .notInstalled))
        #expect(!assistant.canUninstallHelper)
        assistant.requestHelperUninstall()
        #expect(!assistant.isConfirmingHelperUninstall)
    }

    @Test func `uninstalling isn't offered while creating`() async {
        let assistant = Assistant(
            installers: InstallerSource.samples, drives: Drive.samples, helperService: SampleHelperService(),
            creationService: SimulatedCreationService(speed: .normal, failure: nil))
        assistant.continueToDrive()
        settle(assistant)
        assistant.selectDrive(Drive.samples[0].id)
        assistant.continueToReview()
        settle(assistant)
        assistant.hasConfirmed = true
        await assistant.eraseAndCreate()
        #expect(assistant.step == .creating)
        #expect(!assistant.canUninstallHelper)

        await assistant.uninstallHelper()
        #expect(assistant.step == .creating)
    }

    @Test func `a failed uninstall stays where it was and says why`() async {
        let error = HelperError.unregistrationFailed(reason: nil)
        let assistant = makeAssistant(SampleHelperService(status: .ready, unregisterError: error))

        await assistant.uninstallHelper()
        #expect(assistant.step == .installer)
        #expect(assistant.helperUninstallError == error)

        assistant.dismissHelperUninstallError()
        #expect(assistant.helperUninstallError == nil)
    }
}
