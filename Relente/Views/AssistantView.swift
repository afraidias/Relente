//
//  AssistantView.swift
//  Relente
//
//  The assistant: the current screen on top, its footer at the bottom. Which screen, and what
//  each button does, comes from `Assistant`. Screens slide forward and back (or crossfade for
//  endings and restarts); the footer stays still; the chosen drive and the installer's icon fly
//  from one screen to the next (`SharedArtwork`). With Reduce Motion everything crossfades.
//  Spec: specs/006-assistant-navigation/spec.md
//

import SwiftUI

struct AssistantView: View {
    @Bindable var assistant: Assistant
    /// The kind of Mac in use, for Done's start-up cards.
    let thisMac: MacArchitecture

    /// The screen on display. It follows `assistant.step` one moment later, so the screen that
    /// leaves already knows which way to go (see `.onChange`).
    @State private var shownStep: AssistantStep
    /// The footer's screen. It changes at once, outside the animation: only the screen above it
    /// slides or fades.
    @State private var footerStep: AssistantStep
    /// How the change to `shownStep` moves.
    @State private var change = ScreenChange(direction: .forward, style: .crossfade)
    /// While the screen changes, the step it changes from.
    @State private var changingFrom: AssistantStep?
    /// The last disconnection VoiceOver announced, so each is said once.
    @State private var announcedDisconnection: UUID?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(assistant: Assistant, thisMac: MacArchitecture) {
        self.assistant = assistant
        self.thisMac = thisMac
        _shownStep = State(initialValue: assistant.step)
        _footerStep = State(initialValue: assistant.step)
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                screen(for: shownStep)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .environment(\.assistantScreen, shownStep)
                    .environment(\.isChangingScreen, assistant.isChangingScreen)
                    .environment(\.artworkStayingWithScreen, artworkStayingWithScreen)
                    // Whatever changes inside a screen while it slides (e.g. the phase bar
                    // filling up) moves with the screen instead of jumping to its final place.
                    .geometryGroup()
                    .id(shownStep)
                    .transition(screenTransition)
            }
            .overlayPreferenceValue(SharedArtworkAnchors.self) { anchors in
                travellingArtwork(at: anchors[shownStep] ?? [:])
            }
            .clipped()

            footer(for: footerStep)
                .environment(\.assistantScreen, footerStep)
        }
        .overlayPreferenceValue(SharedArtworkAnchors.self) { anchors in
            stepIndicator(at: anchors[footerStep]?[.stepIndicator])
        }
        .frame(width: Theme.Sizes.window.width, height: Theme.Sizes.window.height)
        .onChange(of: assistant.step) { oldStep, newStep in
            // First let the current screen learn how it will leave, then change it on the next
            // frame: a leaving screen keeps the transition it was last drawn with.
            change = assistant.lastChange
            changingFrom = oldStep
            footerStep = newStep
            Task {
                try? await Task.sleep(for: .milliseconds(16))
                withAnimation(animation) {
                    shownStep = newStep
                } completion: {
                    changingFrom = nil
                    assistant.screenChangeDidEnd()
                    // VoiceOver reads the new screen from its title (see `ScreenHeader`).
                    AccessibilityNotification.ScreenChanged().post()
                    announceDisconnection()
                }
            }
        }
    }

    // MARK: - Announcements

    /// After the chosen drive was unplugged on Review and the assistant went back to USB Drive,
    /// VoiceOver says why, once the new screen is in place.
    private func announceDisconnection() {
        guard let disconnection = assistant.disconnection, disconnection.id != announcedDisconnection else { return }
        announcedDisconnection = disconnection.id
        AccessibilityNotification.Announcement(
            String(
                localized: "“\(disconnection.driveName)” was disconnected.",
                comment: "VoiceOver, when the chosen drive is unplugged on Review. The value is the drive's name.")
        ).post()
    }

    // MARK: - Motion

    private var isCrossfade: Bool {
        reduceMotion || change.style == .crossfade
    }

    private var animation: Animation {
        isCrossfade ? .easeInOut(duration: 0.3) : .timingCurve(0.2, 0.8, 0.2, 1, duration: 0.45)
    }

    /// Forward: in from the trailing edge, out by the leading one; back: the opposite. Leading and
    /// trailing follow the layout direction, so right-to-left languages are mirrored.
    private var screenTransition: AnyTransition {
        if isCrossfade { return .opacity }
        return switch change.direction {
        case .forward: .asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))
        case .back: .asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .trailing))
        }
    }

    // MARK: - Travelling artwork

    /// The drive and the installer's icon, drawn where the shown screen marked them. When the
    /// shown screen changes, they fly from the old marks to the new ones; when a screen has no
    /// mark for one (e.g. Installer has no drive), it comes and goes with its screen.
    private func travellingArtwork(at marks: [SharedArtwork: Anchor<CGRect>]) -> some View {
        GeometryReader { proxy in
            ZStack {
                if let drive = shownDrive, let mark = marks[.drive] {
                    place(DriveArtwork(kind: drive.kind), in: proxy[mark])
                        .id(artworkIdentity)
                        .transition(screenTransition)
                }
                if let installer = shownInstaller, let mark = marks[.installer] {
                    place(InstallerBadge(installer: installer, isChecked: shownStep == .done), in: proxy[mark])
                        .id(artworkIdentity)
                        .transition(screenTransition)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// One step indicator for every footer, where the current footer marked it, so the pill and
    /// the number move when the step changes instead of being redrawn.
    private func stepIndicator(at mark: Anchor<CGRect>?) -> some View {
        GeometryReader { proxy in
            if let mark {
                let rect = proxy[mark]
                StepIndicator(current: footerStep.stepNumber, total: AssistantStep.stepCount, name: footerStep.stepName)
                    .fixedSize()
                    .frame(width: rect.width, height: rect.height, alignment: .leading)
                    .position(x: rect.midX, y: rect.midY)
            }
        }
        .allowsHitTesting(false)
    }

    /// While the screen changes, the artwork one of the two screens has no place for: it comes or
    /// goes with its screen instead of being drawn here.
    private var artworkStayingWithScreen: Set<SharedArtwork> {
        guard let changingFrom else { return [] }
        return SharedArtwork.stayingWithScreens(from: changingFrom, to: assistant.step)
    }

    /// With Reduce Motion, each screen gets its own drive and icon, which fade with it instead of
    /// flying from the previous screen.
    private var artworkIdentity: AnyHashable {
        reduceMotion ? AnyHashable(shownStep) : AnyHashable(0)
    }

    private func place(_ view: some View, in rect: CGRect) -> some View {
        view
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
    }

    private var shownDrive: Drive? {
        switch shownStep {
        case .installer: nil
        case .drive, .review: assistant.selectedDrive
        case .creating: assistant.creationDrive
        case .done: assistant.result?.drive
        }
    }

    private var shownInstaller: InstallerSource? {
        switch shownStep {
        case .installer, .drive, .review: assistant.selectedInstaller
        case .creating: assistant.creationInstaller
        case .done: assistant.result?.installer
        }
    }

    // MARK: - Screens

    @ViewBuilder
    private func screen(for step: AssistantStep) -> some View {
        switch step {
        case .installer:
            InstallerView(
                installers: assistant.installers, selectedID: installerSelection,
                onMoveSelection: assistant.moveSelection,
                onChooseFile: { url in Task { await assistant.chooseInstaller(at: url) } },
                error: assistant.installerError, onDismissError: assistant.dismissInstallerError)
        case .drive:
            if let installer = assistant.selectedInstaller {
                DriveView(
                    drives: assistant.drives, installer: installer, selectedID: driveSelection,
                    onMoveSelection: assistant.moveSelection)
            }
        case .review:
            if let installer = assistant.selectedInstaller, let drive = assistant.selectedDrive {
                ReviewView(installer: installer, drive: drive, hasConfirmed: $assistant.hasConfirmed)
            }
        case .creating:
            if let installer = assistant.creationInstaller, let drive = assistant.creationDrive,
                let creation = assistant.creation
            {
                CreatingView(installer: installer, drive: drive, state: creation, isSimulated: assistant.isSimulated)
            }
        case .done:
            if let result = assistant.result {
                DoneView(result: result, thisMac: thisMac, isSimulated: assistant.isSimulated)
            }
        }
    }

    // MARK: - Footers

    /// The footer swaps without moving: only the screen above it slides or fades.
    @ViewBuilder
    private func footer(for step: AssistantStep) -> some View {
        switch step {
        case .installer:
            InstallerFooter(canContinue: assistant.selectedInstaller != nil, onContinue: assistant.continueToDrive)
        case .drive:
            DriveFooter(
                canContinue: assistant.canContinueToReview,
                onBack: assistant.goBack,
                onContinue: assistant.continueToReview
            )
        case .review:
            ReviewFooter(
                hasConfirmed: assistant.hasConfirmed,
                canCreate: assistant.canCreate,
                onBack: assistant.goBack,
                onErase: assistant.eraseAndCreate
            )
        case .creating:
            if assistant.creation?.failure == nil {
                CreatingFooter(driveName: assistant.creationDrive?.name ?? "", onStop: assistant.stop)
            } else {
                CreationErrorFooter(onStartOver: assistant.startOver, onTryAgain: assistant.tryAgain)
            }
        case .done:
            DoneFooter(
                installerName: assistant.result?.installer.name ?? "", driveName: assistant.result?.drive.name ?? "",
                isEjecting: assistant.isEjecting, ejectFailure: assistant.ejectFailure,
                onEject: { Task { await assistant.eject() } },
                onForceEject: { Task { await assistant.forceEject() } },
                onDismissFailure: assistant.dismissEjectFailure)
        }
    }

    // MARK: - Selections

    private var installerSelection: Binding<InstallerSource.ID?> {
        Binding(
            get: { assistant.selectedInstallerID },
            set: { id in if let id { assistant.selectInstaller(id) } }
        )
    }

    private var driveSelection: Binding<Drive.ID?> {
        Binding(
            get: { assistant.selectedDriveID },
            set: { id in if let id { assistant.selectDrive(id) } }
        )
    }
}

// MARK: - Previews

#Preview("Liquid Glass (macOS 26+)") {
    AssistantView(
        assistant: Assistant(installers: InstallerSource.samples, drives: Drive.samples), thisMac: .appleSilicon)
}

#Preview("Classic (macOS 14–15)") {
    AssistantView(
        assistant: Assistant(installers: InstallerSource.samples, drives: Drive.samples), thisMac: .appleSilicon
    )
    .environment(\.usesClassicControls, true)
}
