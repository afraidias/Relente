//
//  Assistant.swift
//  Relente
//
//  The assistant's shared state: the current screen, what was chosen, and how the last screen
//  change should animate. Every user action checks it's allowed on the current screen and does
//  nothing otherwise.
//  Spec: specs/006-assistant-navigation/spec.md
//

import Foundation
import Observation

@MainActor
@Observable
final class Assistant {
    let installers: [InstallerSource]
    let drives: [Drive]

    private(set) var step: AssistantStep = .installer
    private(set) var selectedInstallerID: InstallerSource.ID?
    private(set) var selectedDriveID: Drive.ID?
    /// The Review checkbox. Unchecked every time Review is shown.
    var hasConfirmed = false
    private(set) var lastChange = ScreenChange(direction: .forward, style: .crossfade)
    /// True from a screen change until its animation ends; screen changes are ignored meanwhile,
    /// so a double click can't skip a step.
    private(set) var isChangingScreen = false

    /// The run shown on Creating (and Error), or `nil` before the first one.
    private(set) var creation: CreationState?
    /// What that run is making. Kept apart from the selection, which Start Over clears while
    /// Creating is still fading out.
    private(set) var creationInstaller: InstallerSource?
    private(set) var creationDrive: Drive?
    /// What Done shows, once a run finishes.
    private(set) var result: CreationResult?

    /// `nil` in Release builds until roadmap step 7: "Erase and Create" is then disabled.
    private let creationService: (any CreationService)?
    private var creationTask: Task<Void, Never>?

    init(installers: [InstallerSource], drives: [Drive], creationService: (any CreationService)? = nil) {
        self.installers = installers
        self.drives = drives
        self.creationService = creationService
        selectedInstallerID = installers.first?.id
    }

    // MARK: - Choices

    var selectedInstaller: InstallerSource? {
        installers.first { $0.id == selectedInstallerID }
    }

    var selectedDrive: Drive? {
        drives.first { $0.id == selectedDriveID }
    }

    /// Whether the drive can be picked for the chosen installer.
    func isPickable(_ drive: Drive) -> Bool {
        guard let installer = selectedInstaller else { return false }
        return drive.status(forInstallerSize: installer.size).isSelectable
    }

    func selectInstaller(_ id: InstallerSource.ID) {
        guard installers.contains(where: { $0.id == id }) else { return }
        selectedInstallerID = id
        if let drive = selectedDrive, !isPickable(drive) {
            selectedDriveID = nil
        }
    }

    func selectDrive(_ id: Drive.ID) {
        guard let drive = drives.first(where: { $0.id == id }), isPickable(drive) else { return }
        selectedDriveID = id
    }

    /// Left and right arrows: the previous or next installer, or pickable drive, without wrapping.
    func moveSelection(by offset: Int) {
        switch step {
        case .installer:
            guard let index = installers.firstIndex(where: { $0.id == selectedInstallerID }) else { return }
            let next = min(max(index + offset, 0), installers.count - 1)
            selectInstaller(installers[next].id)
        case .drive:
            let pickable = drives.filter(isPickable)
            guard !pickable.isEmpty else { return }
            guard let index = pickable.firstIndex(where: { $0.id == selectedDriveID }) else {
                selectedDriveID = pickable[0].id
                return
            }
            selectedDriveID = pickable[min(max(index + offset, 0), pickable.count - 1)].id
        case .review, .creating, .done:
            break
        }
    }

    // MARK: - Moving between screens

    func continueToDrive() {
        guard step == .installer, selectedInstaller != nil else { return }
        change(to: .drive, .forward, .slide)
    }

    var canContinueToReview: Bool {
        selectedDrive.map(isPickable) ?? false
    }

    func continueToReview() {
        guard step == .drive, canContinueToReview else { return }
        change(to: .review, .forward, .slide)
    }

    /// Whether Back is offered: on the USB Drive and Review screens.
    var canGoBack: Bool {
        step == .drive || step == .review
    }

    /// Back, on the USB Drive and Review screens. Keeps what was chosen.
    func goBack() {
        switch step {
        case .drive: change(to: .installer, .back, .slide)
        case .review: change(to: .drive, .back, .slide)
        case .installer, .creating, .done: break
        }
    }

    // MARK: - Creating

    /// Whether "Erase and Create" can work at all in this build.
    var canCreate: Bool {
        creationService != nil
    }

    /// Whether the creation is only pretended: Creating, Error and Done then say so.
    var isSimulated: Bool {
        creationService?.isSimulated ?? false
    }

    func eraseAndCreate() {
        guard step == .review, hasConfirmed, !isChangingScreen, let creationService,
            let installer = selectedInstaller, let drive = selectedDrive
        else { return }
        creation = .running(CreationProgress(phase: .format, phaseFraction: 0, installerSize: installer.size))
        creationInstaller = installer
        creationDrive = drive
        result = nil
        change(to: .creating, .forward, .slide)

        let start = ContinuousClock.now
        creationTask = Task { [weak self] in
            for await event in creationService.create(installer: installer, drive: drive) {
                guard let self, !Task.isCancelled else { return }
                switch event {
                case .progress(let progress):
                    creation = .running(progress)
                case .finished:
                    result = CreationResult(installer: installer, drive: drive, duration: start.duration(to: .now))
                    creationTask = nil
                    change(to: .done, .forward, .crossfade, byUser: false)
                case .failed(let failure):
                    creation = .failed(failure)
                    creationTask = nil
                }
            }
        }
    }

    /// "Stop" in the Cancel sheet: the run ends as cancelled where it was.
    func stop() {
        guard step == .creating, case .running(let progress) = creation else { return }
        creationTask?.cancel()
        creationTask = nil
        creation = .failed(CreationFailure(reason: .cancelled, progress: progress))
    }

    /// Error's "Try Again": back to Review, where the erase is confirmed again.
    func tryAgain() {
        guard step == .creating, creation?.failure != nil else { return }
        change(to: .review, .back, .slide)
    }

    /// Error's "Start Over".
    func startOver() {
        guard step == .creating, creation?.failure != nil else { return }
        restart()
    }

    /// Done's "Eject".
    func eject() {
        guard step == .done else { return }
        restart()
    }

    /// Back to the Installer screen, keeping the installer and forgetting the drive.
    private func restart() {
        guard !isChangingScreen else { return }
        selectedDriveID = nil
        change(to: .installer, .back, .crossfade)
    }

    // MARK: - Screen changes

    /// Called when the animation of the last screen change ends.
    func screenChangeDidEnd() {
        isChangingScreen = false
    }

    /// Changes the screen. Changes the user asks for are ignored while another one runs; the end
    /// of a creation (`byUser: false`) always goes through.
    private func change(
        to newStep: AssistantStep, _ direction: ScreenChange.Direction, _ style: ScreenChange.Style,
        byUser: Bool = true
    ) {
        guard !byUser || !isChangingScreen else { return }
        if newStep == .review {
            hasConfirmed = false
        }
        lastChange = ScreenChange(direction: direction, style: style)
        step = newStep
        isChangingScreen = true
    }
}
