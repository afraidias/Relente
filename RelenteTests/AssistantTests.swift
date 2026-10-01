//
//  AssistantTests.swift
//  RelenteTests
//
//  Spec: specs/006-assistant-navigation/spec.md
//

import Foundation
import Testing

@testable import Relente

@MainActor
struct AssistantTests {

    // MARK: - Sample data

    /// Installers whose sizes make a 16 GB drive fit only the smallest one.
    private let tahoe = Self.installer("macOS Tahoe", size: 16_800_000_000)
    private let sonoma = Self.installer("macOS Sonoma", size: 13_400_000_000)

    /// 64 GB, fits every installer.
    private let big = Self.drive("Big", capacity: 64_000_000_000)
    /// 16 GB: fits Sonoma (needs 14.4 GB) but not Tahoe (needs 17.8 GB).
    private let medium = Self.drive("Medium", capacity: 16_000_000_000)
    /// 8 GB, fits none.
    private let tiny = Self.drive("Tiny", capacity: 8_000_000_000)
    /// 32 GB, fits every installer.
    private let large = Self.drive("Large", capacity: 32_000_000_000)

    private static func installer(_ name: String, size: Int64) -> InstallerSource {
        InstallerSource(
            url: URL(filePath: "/Applications/Install \(name).app"), name: name, version: "26.0", kind: .app, size: size
        )
    }

    private static func drive(_ name: String, capacity: Int64) -> Drive {
        Drive(
            id: name, bsdName: "disk9", name: name, model: name, kind: .usbDrive, capacity: capacity,
            usedSpace: .bytes(0))
    }

    /// An assistant whose screen changes end at once, as if every animation had finished.
    private func makeAssistant(
        installers: [InstallerSource]? = nil, drives: [Drive]? = nil, service: (any CreationService)? = nil
    ) -> Assistant {
        Assistant(
            installers: installers ?? [tahoe, sonoma], drives: drives ?? [big, tiny, medium, large],
            creationService: service)
    }

    /// Ends the screen change the last action started, as the view does when its animation ends.
    private func settle(_ assistant: Assistant) {
        assistant.screenChangeDidEnd()
    }

    /// Takes the assistant to Review with the first drive chosen.
    private func goToReview(_ assistant: Assistant) {
        assistant.continueToDrive()
        settle(assistant)
        assistant.selectDrive(big.id)
        assistant.continueToReview()
        settle(assistant)
    }

    // MARK: - Start

    @Test func `starts on the installer screen with the first installer and no drive`() {
        let assistant = makeAssistant()
        #expect(assistant.step == .installer)
        #expect(assistant.selectedInstallerID == tahoe.id)
        #expect(assistant.selectedDriveID == nil)
    }

    @Test func `starts with no installer selected when there are none`() {
        let assistant = makeAssistant(installers: [])
        #expect(assistant.selectedInstallerID == nil)
        assistant.continueToDrive()
        #expect(assistant.step == .installer)
    }

    @Test func `the footer counts four steps, Creating and Done sharing the last`() {
        let steps: [AssistantStep] = [.installer, .drive, .review, .creating, .done]
        #expect(steps.map(\.stepNumber) == [1, 2, 3, 4, 4])
        #expect(AssistantStep.stepCount == 4)
    }

    // MARK: - Flow

    @Test func `continue on installer goes to the drive screen, sliding forward`() {
        let assistant = makeAssistant()
        assistant.continueToDrive()
        #expect(assistant.step == .drive)
        #expect(assistant.lastChange == ScreenChange(direction: .forward, style: .slide))
    }

    @Test func `continue on the drive screen needs a pickable drive`() {
        let assistant = makeAssistant()
        assistant.continueToDrive()
        settle(assistant)

        assistant.continueToReview()
        #expect(assistant.step == .drive)

        assistant.selectDrive(tiny.id)
        #expect(assistant.selectedDriveID == nil)
        assistant.continueToReview()
        #expect(assistant.step == .drive)

        assistant.selectDrive(big.id)
        assistant.continueToReview()
        #expect(assistant.step == .review)
        #expect(assistant.lastChange == ScreenChange(direction: .forward, style: .slide))
    }

    @Test func `back goes from the drive screen to the installer screen, sliding back`() {
        let assistant = makeAssistant()
        assistant.continueToDrive()
        settle(assistant)
        assistant.goBack()
        #expect(assistant.step == .installer)
        #expect(assistant.lastChange == ScreenChange(direction: .back, style: .slide))
    }

    @Test func `back goes from review to the drive screen and keeps both choices`() {
        let assistant = makeAssistant()
        assistant.selectInstaller(sonoma.id)
        goToReview(assistant)

        assistant.goBack()
        #expect(assistant.step == .drive)
        #expect(assistant.lastChange == ScreenChange(direction: .back, style: .slide))
        #expect(assistant.selectedInstallerID == sonoma.id)
        #expect(assistant.selectedDriveID == big.id)

        settle(assistant)
        assistant.goBack()
        #expect(assistant.step == .installer)
        #expect(assistant.selectedInstallerID == sonoma.id)
        #expect(assistant.selectedDriveID == big.id)
    }

    @Test func `back is offered only on the drive and review screens`() {
        let assistant = makeAssistant()
        #expect(assistant.canGoBack == false)
        assistant.continueToDrive()
        #expect(assistant.canGoBack)
        settle(assistant)
        assistant.selectDrive(big.id)
        assistant.continueToReview()
        #expect(assistant.canGoBack)
    }

    @Test func `back does nothing on the installer screen`() {
        let assistant = makeAssistant()
        assistant.goBack()
        #expect(assistant.step == .installer)
    }

    @Test func `actions that don't belong to the current screen do nothing`() {
        let assistant = makeAssistant()
        assistant.selectDrive(big.id)
        assistant.continueToReview()
        #expect(assistant.step == .installer)

        assistant.continueToDrive()
        settle(assistant)
        assistant.continueToDrive()
        #expect(assistant.step == .drive)
        #expect(assistant.isChangingScreen == false)
    }

    // MARK: - Confirmation

    @Test func `review always starts unconfirmed`() {
        let assistant = makeAssistant()
        goToReview(assistant)
        #expect(assistant.hasConfirmed == false)

        assistant.hasConfirmed = true
        assistant.goBack()
        settle(assistant)
        assistant.continueToReview()
        #expect(assistant.hasConfirmed == false)
    }

    // MARK: - Choosing

    @Test func `choosing an installer the drive is too small for clears the drive`() {
        let assistant = makeAssistant()
        assistant.selectInstaller(sonoma.id)
        assistant.continueToDrive()
        settle(assistant)
        assistant.selectDrive(medium.id)
        #expect(assistant.selectedDriveID == medium.id)

        assistant.goBack()
        settle(assistant)
        assistant.selectInstaller(tahoe.id)
        #expect(assistant.selectedDriveID == nil)
    }

    @Test func `choosing an installer the drive still fits keeps the drive`() {
        let assistant = makeAssistant()
        assistant.continueToDrive()
        settle(assistant)
        assistant.selectDrive(big.id)
        assistant.goBack()
        settle(assistant)
        assistant.selectInstaller(sonoma.id)
        #expect(assistant.selectedDriveID == big.id)
    }

    @Test func `unknown ids are ignored`() {
        let assistant = makeAssistant()
        assistant.selectInstaller(URL(filePath: "/nowhere.app"))
        #expect(assistant.selectedInstallerID == tahoe.id)
        assistant.continueToDrive()
        settle(assistant)
        assistant.selectDrive("missing")
        #expect(assistant.selectedDriveID == nil)
    }

    // MARK: - Arrow keys

    @Test func `arrows move between installers without wrapping`() {
        let assistant = makeAssistant()
        assistant.moveSelection(by: 1)
        #expect(assistant.selectedInstallerID == sonoma.id)
        assistant.moveSelection(by: 1)
        #expect(assistant.selectedInstallerID == sonoma.id)
        assistant.moveSelection(by: -1)
        #expect(assistant.selectedInstallerID == tahoe.id)
        assistant.moveSelection(by: -1)
        #expect(assistant.selectedInstallerID == tahoe.id)
    }

    @Test func `arrows move between pickable drives, skipping the others, without wrapping`() {
        // With Tahoe, `tiny` and `medium` can't be picked: the order is big, tiny, medium, large.
        let assistant = makeAssistant()
        assistant.continueToDrive()
        settle(assistant)

        assistant.moveSelection(by: 1)
        #expect(assistant.selectedDriveID == big.id)
        assistant.moveSelection(by: 1)
        #expect(assistant.selectedDriveID == large.id)
        assistant.moveSelection(by: 1)
        #expect(assistant.selectedDriveID == large.id)
        assistant.moveSelection(by: -1)
        #expect(assistant.selectedDriveID == big.id)
        assistant.moveSelection(by: -1)
        #expect(assistant.selectedDriveID == big.id)
    }

    @Test func `the first arrow on the drive screen picks a drive whichever the direction`() {
        let assistant = makeAssistant()
        assistant.continueToDrive()
        settle(assistant)
        assistant.moveSelection(by: -1)
        #expect(assistant.selectedDriveID == big.id)
    }

    @Test func `arrows do nothing on other screens`() {
        let assistant = makeAssistant()
        goToReview(assistant)
        assistant.moveSelection(by: 1)
        #expect(assistant.selectedDriveID == big.id)
        #expect(assistant.selectedInstallerID == tahoe.id)
    }

    // MARK: - Double-click guard

    @Test func `screen changes are ignored until the current one ends`() {
        let assistant = makeAssistant()
        assistant.continueToDrive()
        #expect(assistant.isChangingScreen)

        assistant.selectDrive(big.id)
        assistant.continueToReview()
        #expect(assistant.step == .drive)
        assistant.goBack()
        #expect(assistant.step == .drive)

        settle(assistant)
        #expect(assistant.isChangingScreen == false)
        assistant.continueToReview()
        #expect(assistant.step == .review)
    }

    @Test func `choosing still works while the screen changes`() {
        let assistant = makeAssistant()
        assistant.continueToDrive()
        assistant.selectDrive(big.id)
        #expect(assistant.selectedDriveID == big.id)
    }

    // MARK: - Creating

    /// Progress snapshots of a run that is halfway through Copy.
    private var copying: CreationProgress {
        CreationProgress(phase: .copy, phaseFraction: 0.5, copiedBytes: 8_400_000_000, installerSize: tahoe.size)
    }

    /// Takes the assistant to Review, confirmed, and starts the creation.
    private func startCreating(_ assistant: Assistant) {
        goToReview(assistant)
        assistant.hasConfirmed = true
        assistant.eraseAndCreate()
    }

    /// Lets the creation task read the stub's events.
    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<1_000 {
            if condition() { return }
            await Task.yield()
        }
    }

    @Test func `without a service the drive can't be erased`() {
        let assistant = makeAssistant()
        #expect(assistant.canCreate == false)
        startCreating(assistant)
        #expect(assistant.step == .review)
        #expect(assistant.isSimulated == false)
    }

    @Test func `erase and create needs the confirmation`() {
        let assistant = makeAssistant(service: StubCreationService(events: []))
        #expect(assistant.canCreate)
        goToReview(assistant)
        assistant.eraseAndCreate()
        #expect(assistant.step == .review)
    }

    @Test func `erase and create slides forward to creating and shows the progress`() async {
        let assistant = makeAssistant(service: StubCreationService(events: [.progress(copying)], finishes: false))
        startCreating(assistant)
        #expect(assistant.step == .creating)
        #expect(assistant.lastChange == ScreenChange(direction: .forward, style: .slide))
        #expect(assistant.creation?.failure == nil)
        #expect(assistant.creationInstaller == tahoe)
        #expect(assistant.creationDrive == big)

        await waitUntil { assistant.creation == .running(copying) }
        #expect(assistant.creation == .running(copying))
    }

    @Test func `a finished creation crossfades to done with the chosen installer and drive`() async {
        let assistant = makeAssistant(service: StubCreationService(events: [.progress(copying), .finished]))
        startCreating(assistant)
        await waitUntil { assistant.step == .done }

        #expect(assistant.step == .done)
        #expect(assistant.lastChange.style == .crossfade)
        #expect(assistant.result?.installer == tahoe)
        #expect(assistant.result?.drive == big)
        #expect((assistant.result?.duration ?? .seconds(-1)) >= .zero)
    }

    @Test func `the creation ends in done even if a screen change is still running`() async {
        let assistant = makeAssistant(service: StubCreationService(events: [.finished]))
        startCreating(assistant)
        #expect(assistant.isChangingScreen)
        await waitUntil { assistant.step == .done }
        #expect(assistant.step == .done)
    }

    @Test func `a failed creation stays on creating with the failure`() async {
        let failure = CreationFailure(reason: .driveDisconnected, progress: copying)
        let assistant = makeAssistant(service: StubCreationService(events: [.progress(copying), .failed(failure)]))
        startCreating(assistant)
        await waitUntil { assistant.creation?.failure != nil }

        #expect(assistant.step == .creating)
        #expect(assistant.creation == .failed(failure))
    }

    @Test func `stop fails with cancelled at the last progress and stops the run`() async {
        let assistant = makeAssistant(service: StubCreationService(events: [.progress(copying)], finishes: false))
        startCreating(assistant)
        await waitUntil { assistant.creation == .running(copying) }

        assistant.stop()
        #expect(assistant.creation == .failed(CreationFailure(reason: .cancelled, progress: copying)))
        #expect(assistant.step == .creating)
    }

    @Test func `try again slides back to review, unconfirmed`() async {
        let failure = CreationFailure(reason: .driveDisconnected, progress: copying)
        let assistant = makeAssistant(service: StubCreationService(events: [.failed(failure)]))
        startCreating(assistant)
        await waitUntil { assistant.creation?.failure != nil }
        settle(assistant)

        assistant.tryAgain()
        #expect(assistant.step == .review)
        #expect(assistant.lastChange == ScreenChange(direction: .back, style: .slide))
        #expect(assistant.hasConfirmed == false)
        #expect(assistant.selectedDriveID == big.id)
    }

    @Test func `start over crossfades to the installer screen, keeping the installer only`() async {
        let failure = CreationFailure(reason: .driveDisconnected, progress: copying)
        let assistant = makeAssistant(service: StubCreationService(events: [.failed(failure)]))
        assistant.selectInstaller(sonoma.id)
        startCreating(assistant)
        await waitUntil { assistant.creation?.failure != nil }
        settle(assistant)

        assistant.startOver()
        #expect(assistant.step == .installer)
        #expect(assistant.lastChange.style == .crossfade)
        #expect(assistant.selectedInstallerID == sonoma.id)
        #expect(assistant.selectedDriveID == nil)
        // Creating can still be drawn while it fades out.
        #expect(assistant.creationDrive == big)
    }

    @Test func `try again and start over do nothing while it's running`() async {
        let assistant = makeAssistant(service: StubCreationService(events: [.progress(copying)], finishes: false))
        startCreating(assistant)
        settle(assistant)
        assistant.tryAgain()
        assistant.startOver()
        #expect(assistant.step == .creating)
    }

    @Test func `eject crossfades to the installer screen, keeping the installer only`() async {
        let assistant = makeAssistant(service: StubCreationService(events: [.finished]))
        startCreating(assistant)
        await waitUntil { assistant.step == .done }
        settle(assistant)

        await assistant.eject()
        #expect(assistant.step == .installer)
        #expect(assistant.lastChange.style == .crossfade)
        #expect(assistant.selectedInstallerID == tahoe.id)
        #expect(assistant.selectedDriveID == nil)
    }

    @Test func `the simulation label follows the service`() {
        #expect(makeAssistant(service: StubCreationService(events: [], isSimulated: true)).isSimulated)
        #expect(makeAssistant(service: StubCreationService(events: [], isSimulated: false)).isSimulated == false)
    }
}

// MARK: - Stub service

/// Replays fixed events at once. With `finishes: false` the stream stays open, like a run in
/// progress, until the reading task is cancelled.
nonisolated private struct StubCreationService: CreationService {
    let events: [CreationEvent]
    var finishes = true
    var isSimulated = true

    func create(installer: InstallerSource, drive: Drive) -> AsyncStream<CreationEvent> {
        AsyncStream { continuation in
            for event in events {
                continuation.yield(event)
            }
            if finishes {
                continuation.finish()
            }
        }
    }
}
