//
//  Assistant.swift
//  Relente
//
//  The assistant's shared state: the current screen, what was chosen, and how the last screen
//  change should animate. Every user action checks it's allowed on the current screen and does
//  nothing otherwise.
//  Spec: specs/006-assistant-navigation/spec.md, specs/008-system-helper/spec.md
//

import AppKit
import Foundation
import Observation
import os

@MainActor
@Observable
final class Assistant {
    /// Newest first, as the installer service finds them.
    private(set) var installers: [InstallerSource] = []
    /// As the drive service finds them.
    private(set) var drives: [Drive] = []

    private(set) var step: AssistantStep
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
    /// Timestamped command output for the current Creating or Error screen, never persisted.
    private(set) var creationOutput: [CreationOutputLine] = []
    /// What that run is making. Kept apart from the selection, which Start Over clears while
    /// Creating is still fading out.
    private(set) var creationInstaller: InstallerSource?
    private(set) var creationDrive: Drive?
    /// What Done shows, once a run finishes.
    private(set) var result: CreationResult?

    /// A drive unplugged on Review, which sent the assistant back to USB Drive. VoiceOver
    /// announces it.
    struct Disconnection: Equatable {
        let driveName: String
        /// Tells two disconnections of the same drive apart.
        let id = UUID()
    }

    private(set) var disconnection: Disconnection?

    /// The helper stopped being ready on Installer, USB Drive or Review, which sent the assistant
    /// back to Permissions. VoiceOver announces it; the id tells two of them apart.
    private(set) var helperTurnedOff: UUID?

    /// True while Done's drive is being ejected.
    private(set) var isEjecting = false
    /// Why the last eject failed, shown as an alert on Done.
    private(set) var ejectFailure: EjectError?
    /// Why the file the user chose can't be used, shown as an alert on Installer.
    private(set) var installerError: InstallerError?

    /// Where the system helper stands, shown on Permissions.
    private(set) var helperStatus: HelperStatus
    /// True while the helper is being installed or retried.
    private(set) var isInstallingHelper = false
    /// Why uninstalling the helper failed, shown as an alert.
    private(set) var helperUninstallError: HelperError?
    /// "Uninstall System Helper…" was chosen: its confirmation is shown.
    var isConfirmingHelperUninstall = false
    /// "Erase and Create" found the helper off: the alert that says so is shown.
    var isShowingHelperOffAlert = false
    /// The helper's selected-volume write probe failed; Review stays visible and creation does not start.
    var isShowingDiskAccessAlert = false
    /// True while macOS's authorization dialog is open, so "Erase and Create" can't start twice.
    private(set) var isAuthorizing = false
    /// True while the helper checks the selected volume before creation.
    private(set) var isCheckingHelperDiskAccess = false

    private let installerService: any InstallerService
    private let driveService: any DriveService
    private let helperService: any HelperService
    private let helperClient: any HelperClient
    private let authorizer: any EraseAuthorizer
    private let logger = Logger(subsystem: "com.afraidias.Relente", category: "helper")
    /// `nil` in Release builds until roadmap step 7: "Erase and Create" is then disabled.
    private let creationService: (any CreationService)?
    private var creationTask: Task<Void, Never>?
    private var hasStarted = false

    /// Starts on Permissions until the system helper is ready.
    init(
        installerService: any InstallerService, driveService: any DriveService,
        helperService: any HelperService = SampleHelperService(), helperClient: any HelperClient = SampleHelperClient(),
        authorizer: any EraseAuthorizer = SampleEraseAuthorizer(), creationService: (any CreationService)? = nil
    ) {
        self.installerService = installerService
        self.driveService = driveService
        self.helperService = helperService
        self.helperClient = helperClient
        self.authorizer = authorizer
        self.creationService = creationService
        let status = helperService.status
        helperStatus = status
        step = status == .ready ? .installer : .permissions
    }

    /// An assistant that starts with these installers and drives, for previews and tests.
    convenience init(
        installers: [InstallerSource], drives: [Drive], helperService: any HelperService = SampleHelperService(),
        helperClient: any HelperClient = SampleHelperClient(),
        authorizer: any EraseAuthorizer = SampleEraseAuthorizer(),
        creationService: (any CreationService)? = nil
    ) {
        self.init(
            installerService: SampleInstallerService(installers: installers),
            driveService: SampleDriveService(drives: drives), helperService: helperService,
            helperClient: helperClient, authorizer: authorizer, creationService: creationService)
        updateInstallers(installers)
        updateDrives(drives)
    }

    // MARK: - Following the Mac

    /// Follows the installers and drives on the Mac until the task is cancelled. The app calls it
    /// once; later calls return at once.
    func start() async {
        guard !hasStarted else { return }
        hasStarted = true
        async let installers: Void = followInstallers()
        async let drives: Void = followDrives()
        async let helper: Void = followHelper()
        _ = await (installers, drives, helper)
    }

    /// macOS doesn't say when the user turns the helper on or off in System Settings, so its
    /// status is read every 2 s (and when the app becomes active, through the view).
    private func followHelper() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(2))
            refreshHelperStatus()
        }
    }

    private func followInstallers() async {
        for await list in installerService.updates() {
            updateInstallers(list)
        }
    }

    private func followDrives() async {
        for await list in driveService.updates() {
            updateDrives(list)
        }
    }

    /// A new list of installers. The selection stays if it's still there. If the chosen installer
    /// disappeared on USB Drive or Review, the assistant goes back to the Installer screen; the
    /// newest supported installer is then selected.
    func updateInstallers(_ list: [InstallerSource]) {
        let hadSelection = selectedInstallerID != nil
        installers = InstallerSource.sorted(list)
        guard selectedInstaller == nil else { return }
        selectedInstallerID = InstallerSource.defaultSelection(in: installers)?.id
        if hadSelection, step == .drive || step == .review {
            selectedDriveID = nil
            change(to: .installer, .back, .slide, byUser: false)
        }
    }

    /// A new list of drives. If the chosen drive was unplugged, the selection is cleared; on
    /// Review the assistant goes back to USB Drive, and a running creation fails.
    func updateDrives(_ list: [Drive]) {
        followCreationDrive(in: list)
        let unplugged = selectedDrive.flatMap { drive in list.contains { $0.id == drive.id } ? nil : drive }
        drives = list

        if step == .creating, case .running(let progress) = creation, let drive = creationDrive,
            !list.contains(where: { $0.id == drive.id }),
            // While the helper formats, the drive may vanish for a moment; a real disconnection
            // then comes from the helper.
            !(progress.phase == .format && creationService?.erasesDrive == true)
        {
            creationTask?.cancel()
            creationTask = nil
            creation = .failed(CreationFailure(reason: .driveDisconnected, progress: progress))
        }

        guard let unplugged else { return }
        selectedDriveID = nil
        if step == .review {
            disconnection = Disconnection(driveName: unplugged.name)
            change(to: .drive, .back, .slide, byUser: false)
        }
    }

    /// Erasing gives the drive a new media UUID, its id. While creating and on Done, the drive is
    /// followed by its BSD name instead, which stays the same while it's connected.
    private func followCreationDrive(in list: [Drive]) {
        guard step == .creating || step == .done, let drive = creationDrive,
            !list.contains(where: { $0.id == drive.id }),
            let renamed = list.first(where: { $0.bsdName == drive.bsdName })
        else { return }
        if selectedDriveID == drive.id {
            selectedDriveID = renamed.id
        }
        creationDrive = renamed
        if let result, result.drive.id == drive.id {
            self.result = CreationResult(installer: result.installer, drive: renamed, duration: result.duration)
        }
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
        guard installers.contains(where: { $0.id == id && $0.isSupported }) else { return }
        selectedInstallerID = id
        if let drive = selectedDrive, !isPickable(drive) {
            selectedDriveID = nil
        }
    }

    func selectDrive(_ id: Drive.ID) {
        guard let drive = drives.first(where: { $0.id == id }), isPickable(drive) else { return }
        selectedDriveID = id
    }

    /// "Choose Installer…": reads the file, adds it to the list and selects it (unless it's
    /// unsupported, which is only shown). A file that isn't an installer sets `installerError`.
    func chooseInstaller(at url: URL) async {
        guard step == .installer else { return }
        do {
            let installer = try await installerService.add(url)
            if !installers.contains(where: { $0.id == installer.id }) {
                installers = InstallerSource.sorted(installers + [installer])
            }
            if installer.isSupported {
                selectedInstallerID = installer.id
            }
        } catch {
            installerError = error
        }
    }

    /// The "Isn't a macOS Installer" alert's "OK".
    func dismissInstallerError() {
        installerError = nil
    }

    /// Left and right arrows: the previous or next supported installer, or pickable drive, without
    /// wrapping.
    func moveSelection(by offset: Int) {
        switch step {
        case .installer:
            let supported = installers.filter(\.isSupported)
            guard let index = supported.firstIndex(where: { $0.id == selectedInstallerID }) else { return }
            selectInstaller(supported[min(max(index + offset, 0), supported.count - 1)].id)
        case .drive:
            let pickable = drives.filter(isPickable)
            guard !pickable.isEmpty else { return }
            guard let index = pickable.firstIndex(where: { $0.id == selectedDriveID }) else {
                selectedDriveID = pickable[0].id
                return
            }
            selectedDriveID = pickable[min(max(index + offset, 0), pickable.count - 1)].id
        case .permissions, .review, .creating, .done:
            break
        }
    }

    // MARK: - System helper

    /// Reads the helper's status again. If it stopped being ready on Installer, USB Drive or
    /// Review, the assistant crossfades back to Permissions, keeping the chosen installer and
    /// drive; a creation or Done is never interrupted.
    func refreshHelperStatus() {
        // A failure stays on screen until the user tries again.
        if case .failed = helperStatus, helperService.status == .notInstalled { return }
        let wasReady = helperStatus == .ready
        updateHelperStatus(helperService.status)
        guard wasReady, helperStatus != .ready, step == .installer || step == .drive || step == .review else {
            return
        }
        helperTurnedOff = UUID()
        change(to: .permissions, .back, .crossfade, byUser: false)
    }

    /// When the helper becomes ready, connects to it once: that starts it, which adds the erase
    /// right, and shows in the log that the connection works.
    private func updateHelperStatus(_ status: HelperStatus) {
        let becameReady = status == .ready && helperStatus != .ready
        helperStatus = status
        guard becameReady else { return }
        Task {
            let connects = await helperClient.connectsToCurrentHelper()
            logger.info("Helper ready; connection \(connects ? "works" : "failed", privacy: .public)")
        }
    }

    /// Permissions' "Install" and "Try Again".
    func installHelper() async {
        guard step == .permissions, !isInstallingHelper else { return }
        isInstallingHelper = true
        defer { isInstallingHelper = false }
        await Task.yield()
        do {
            try await helperService.register()
            updateHelperStatus(helperService.status)
        } catch {
            helperStatus = .failed(error)
        }
    }

    /// Permissions' "Open Settings…".
    func openHelperSettings() {
        helperService.openSettings()
    }

    func openFullDiskAccessSettings() {
        guard
            let url = URL(
                string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles")
        else { return }
        NSWorkspace.shared.open(url)
    }

    /// Permissions' "Continue", once the helper is ready.
    func continueFromPermissions() {
        guard step == .permissions, helperStatus == .ready else { return }
        change(to: .installer, .forward, .crossfade)
    }

    /// Whether "Uninstall System Helper…" is available: the helper is installed and no drive is
    /// being formatted or created.
    var canUninstallHelper: Bool {
        guard helperStatus == .ready || helperStatus == .needsApproval else { return false }
        if step == .creating, case .running = creation { return false }
        return true
    }

    /// "Uninstall System Helper…": asks for confirmation first.
    func requestHelperUninstall() {
        guard canUninstallHelper else { return }
        isConfirmingHelperUninstall = true
    }

    /// "Uninstall System Helper…", once confirmed: unregisters it and goes to Permissions,
    /// keeping the chosen installer. If macOS refuses, `helperUninstallError` holds why.
    func uninstallHelper() async {
        isConfirmingHelperUninstall = false
        guard canUninstallHelper else { return }
        do {
            try await helperService.unregister()
        } catch {
            helperUninstallError = error
            return
        }
        helperStatus = helperService.status
        selectedDriveID = nil
        if step != .permissions {
            change(to: .permissions, .back, .crossfade, byUser: false)
        }
    }

    /// The uninstall failure alert's "OK".
    func dismissHelperUninstallError() {
        helperUninstallError = nil
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
        case .permissions, .installer, .creating, .done: break
        }
    }

    // MARK: - Creating

    /// Whether "Erase and Create" can work at all in this build.
    var canCreate: Bool {
        creationService != nil
    }

    /// What the creation only pretends: Creating, Error and Done then say so.
    var simulation: CreationSimulation? {
        creationService?.simulation
    }

    /// "Erase and Create". The helper must prove it can write the selected USB before creation;
    /// any refusal leaves Review visible and the drive untouched.
    func eraseAndCreate() async {
        guard step == .review, hasConfirmed, !isChangingScreen, !isAuthorizing, let creationService,
            let installer = selectedInstaller, let drive = selectedDrive
        else { return }

        var authorization: EraseAuthorization?
        if creationService.erasesDrive {
            guard helperService.status == .ready else {
                isShowingHelperOffAlert = true
                return
            }
        }

        if creationService.erasesDrive {
            guard helperService.status == .ready else {
                isShowingHelperOffAlert = true
                return
            }
            // Starts the helper, which adds the erase right before the app asks for it.
            isAuthorizing = true
            guard await helperClient.connectsToCurrentHelper() else {
                isAuthorizing = false
                isShowingHelperOffAlert = true
                return
            }
            do {
                authorization = try await authorizer.authorize()
                isAuthorizing = false
            } catch {
                isAuthorizing = false
                return
            }
            // The drive may have been unplugged, or the screen changed, while the dialog was open.
            guard step == .review, selectedDrive?.id == drive.id else { return }
        }

        if creationService.simulation == nil, let authorization {
            isCheckingHelperDiskAccess = true
            defer { isCheckingHelperDiskAccess = false }
            let outcome = await helperClient.checkVolumeWriteAccess(drive, authorization: authorization.externalForm)
            guard step == .review, selectedDrive?.id == drive.id else { return }
            guard outcome == .created else {
                isShowingDiskAccessAlert = true
                return
            }
        }

        creation = .running(
            CreationProgress(
                phase: .format, phaseFraction: nil, installerSize: installer.size,
                isLive: creationService.simulation == nil,
                isPreparingInstaller: creationService.simulation == nil))
        creationOutput = []
        creationInstaller = installer
        creationDrive = drive
        result = nil
        change(to: .creating, .forward, .slide)
        let start = ContinuousClock.now
        creationTask = Task { [weak self] in
            for await event in creationService.create(installer: installer, drive: drive, authorization: authorization)
            {
                guard let self, !Task.isCancelled else { return }
                switch event {
                case .progress(let progress):
                    creation = .running(progress)
                case .output(let line):
                    creationOutput.append(line)
                case .finished:
                    // The drive as it is now: the format gave it a new id.
                    result = CreationResult(
                        installer: installer, drive: creationDrive ?? drive, duration: start.duration(to: .now))
                    creationOutput = []
                    creationTask = nil
                    change(to: .done, .forward, .crossfade, byUser: false)
                case .failed(let failure):
                    creation = .failed(failure)
                    creationTask = nil
                }
            }
            guard !Task.isCancelled, let self, self.creationTask != nil,
                case .running(let progress) = self.creation
            else { return }
            self.creation = .failed(CreationFailure(reason: .helperUnavailable, progress: progress))
            self.creationTask = nil
        }
    }

    /// "Stop" in the Cancel sheet: the run ends as cancelled where it was.
    func stop() {
        guard step == .creating, case .running(let progress) = creation else { return }
        creationTask?.cancel()
        creationTask = nil
        creation = .failed(CreationFailure(reason: .cancelled, progress: progress))
    }

    /// Error's "Try Again": back to Review, where the erase is confirmed again. After a
    /// disconnection, or when the drive wasn't the one confirmed, back to USB Drive to pick it
    /// again, even if it's connected again.
    func tryAgain() {
        guard step == .creating, let failure = creation?.failure else { return }
        creationOutput = []
        if failure.reason.sendsBackToDriveScreen {
            selectedDriveID = nil
        }
        change(to: selectedDrive == nil ? .drive : .review, .back, .slide)
    }

    /// The "System Helper Is Off" alert's "Open Settings…".
    func openHelperSettingsFromAlert() {
        isShowingHelperOffAlert = false
        helperService.openSettings()
    }

    /// Error's "Start Over".
    func startOver() {
        guard step == .creating, creation?.failure != nil else { return }
        restart()
    }

    /// Done's "Eject" (and the alert's "Try Again"): ejects the drive, then goes back to the
    /// Installer screen. If macOS refuses, `ejectFailure` holds why and the assistant stays on
    /// Done. A drive that's already gone just goes back.
    func eject() async {
        await eject(force: false)
    }

    /// The eject alert's "Force Eject".
    func forceEject() async {
        await eject(force: true)
    }

    /// The eject alert's "Cancel": stay on Done.
    func dismissEjectFailure() {
        ejectFailure = nil
    }

    private func eject(force: Bool) async {
        guard step == .done, !isEjecting, let drive = result?.drive else { return }
        ejectFailure = nil
        guard drives.contains(where: { $0.id == drive.id }) else {
            restart()
            return
        }
        isEjecting = true
        defer { isEjecting = false }
        do {
            try await driveService.eject(drive, force: force)
            restart()
        } catch .notConnected {
            restart()
        } catch {
            ejectFailure = error
        }
    }

    /// Back to the Installer screen, keeping the installer and forgetting the drive.
    private func restart() {
        guard !isChangingScreen else { return }
        creationOutput = []
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
