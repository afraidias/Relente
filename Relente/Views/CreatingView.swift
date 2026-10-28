//
//  CreatingView.swift
//  Relente
//
//  Step 4: the bootable installer being made, with its progress around the drive,
//  the copy figures and the phase bar. Step 4b, when it stops, keeps the same layout
//  in red, with why it stopped in the subtitle and where in the figures.
//  Spec: specs/004-creating-screen/spec.md
//

import AppKit
import SwiftUI

struct CreatingView: View {
    let installer: InstallerSource
    let drive: Drive
    /// Running, or stopped with a reason. Both share this layout, so the screen doesn't jump.
    let state: CreationState
    let output: [CreationOutputLine]
    /// What the creation only pretended (Debug builds), or `nil`: a label then says so.
    var simulation: CreationSimulation?
    var onOpenFullDiskAccessSettings: () -> Void = {}
    @State private var creationStarted = ContinuousClock.now

    var body: some View {
        let progress = state.progress

        VStack(spacing: 0) {
            if let failure = state.failure {
                ScreenHeader(title: "Couldn't Create the Installer", subtitle: Self.subtitle(for: failure.reason))
                if failure.reason == .volumeAccessDenied {
                    Button("Open Full Disk Access Settings…", action: onOpenFullDiskAccessSettings)
                        .buttonStyle(.link)
                        .padding(.top, 6)
                }
            } else {
                ScreenHeader(
                    title: "Creating Installer",
                    subtitle: progress.isPreparingInstaller
                        ? LocalizedStringResource(
                            "Preparing the selected installer…",
                            comment: "Creating screen subtitle while the helper validates and prepares the installer.")
                        : Self.subtitle(for: progress.phase)
                )
            }

            if let simulation {
                SimulationLabel(simulation: simulation)
                    .padding(.top, 8)
            }

            Spacer(minLength: 8)

            CreatingHero(installer: installer, drive: drive, progress: progress, isFailed: state.failure != nil)

            Spacer(minLength: 8)

            VStack(spacing: 32) {
                if let failure = state.failure {
                    // Keeps the height of the three figures (which have a caption), so nothing moves.
                    CreatingStats(progress: progress)
                        .hidden()
                        .overlay(alignment: .top) {
                            FailureStats(failure: failure)
                        }
                } else {
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        CreatingStats(progress: progress, elapsed: creationStarted.duration(to: .now))
                    }
                }

                if progress.isPreparingInstaller {
                    Group {
                        if state.failure == nil {
                            ProgressView()
                        } else {
                            ProgressView(value: 0)
                                .tint(Theme.Colors.danger)
                        }
                    }
                    .accessibilityLabel(
                        Text(state.failure == nil ? "Preparing the installer" : "Installer preparation stopped")
                    )
                    .accessibilityValue(Text(state.failure == nil ? "In progress" : "Stopped"))
                    .frame(height: 28)
                    .accessibilityIdentifier("creation.preparingInstaller")
                } else if state.failure == nil, progress.phase == .format {
                    // During erasure, one real progress bar is clearer than showing the
                    // later creation phases as if they were already underway.
                    Group {
                        if let fraction = progress.phaseFraction {
                            ProgressView(value: fraction)
                        } else {
                            ProgressView()
                        }
                    }
                    .accessibilityLabel(Text("Formatting the USB drive"))
                    .accessibilityValue(
                        Text(
                            verbatim: progress.phaseFraction.map { $0.formatted(.percent) }
                                ?? String(localized: "In progress")
                        )
                    )
                    .frame(height: 28)
                } else if state.failure == nil, progress.isLive, progress.phaseFraction == nil {
                    VStack(spacing: 8) {
                        ProgressView()
                        Text(progress.phase == .copy ? "Measuring installer image…" : "In progress")
                            .font(Theme.Fonts.footnote)
                            .foregroundStyle(Theme.Colors.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(Text(progress.phase.name))
                    .accessibilityValue(Text("In progress"))
                    .frame(height: 44)
                    .accessibilityIdentifier("creation.indeterminateProgress")
                } else {
                    PhaseBar(
                        current: progress.phase,
                        currentFraction: progress.phaseFraction ?? 0,
                        isIndeterminate: state.failure == nil && progress.isLive && progress.phaseFraction == nil,
                        isFailed: state.failure != nil
                    )
                }
            }
            .frame(width: Theme.Sizes.contentWidth)

            // Free space is shared evenly above and below the hero and at the bottom. Both
            // states are the same height, so it's shared the same way and nothing jumps.
            Spacer(minLength: 8)
        }
        .padding(.top, Theme.Sizes.headerTopPadding)
        .overlay(alignment: .topTrailing) {
            CreationOutputDetails(lines: output, failure: state.failure?.reason)
                .padding(.top, 8)
                .padding(.trailing, 24)
        }
    }

    /// The Error screen's subtitle: why it stopped, in the primary color, then what to do.
    private static func subtitle(for reason: CreationFailure.Reason) -> Text {
        Text(
            "\(Text(reason.title).foregroundStyle(.primary)) \(Text(reason.recovery))",
            comment: "Error screen subtitle. First value: why it stopped; second: what to do. Both are full sentences."
        )
    }

    /// Names the operation macOS is currently performing, even when it reports no percentage.
    private static func subtitle(for phase: CreationPhase) -> LocalizedStringResource {
        switch phase {
        case .format:
            LocalizedStringResource(
                "Erasing and formatting the USB drive…",
                comment: "Creating screen subtitle while createinstallmedia erases and formats the selected USB.")
        case .copy:
            LocalizedStringResource(
                "Copying installer files to the USB drive…",
                comment: "Creating screen subtitle while createinstallmedia copies installer files.")
        case .makeBootable:
            LocalizedStringResource(
                "Making the USB drive bootable…",
                comment: "Creating screen subtitle while createinstallmedia makes the USB bootable.")
        case .verify:
            LocalizedStringResource(
                "Checking the bootable installer…",
                comment: "Creating screen subtitle while Relente checks the completed USB installer.")
        }
    }
}

// MARK: - Hero

/// The drive inside the progress ring, the overall percentage, and the drive's name and capacity.
/// When it stopped, the halo and badge turn red, the ring goes away (keeping its space) and the
/// percentage moves to STOPPED AT.
struct CreatingHero: View {
    let installer: InstallerSource
    let drive: Drive
    let progress: CreationProgress
    let isFailed: Bool

    /// Size of the ring, and of the space it leaves when it's gone.
    private static let ringDiameter: CGFloat = 140

    var body: some View {
        let tint = isFailed ? Theme.Colors.danger : Theme.Colors.accent

        let artwork = HeroArtwork(size: 90, haloColor: tint) {
            // Once it stopped, the screen draws the drive itself: the assistant draws shared
            // artwork above the whole screen, which would cover the cross's ring (spec 008).
            DriveArtwork(kind: drive.kind)
                .sharedArtwork(.drive, isActive: !isFailed)
        } badge: {
            if isFailed {
                StatusBadge(kind: .failure)
            } else {
                FileIcon(url: installer.url, fallbackType: installer.kind.contentType)
                    .sharedArtwork(.installer)
            }
        }

        VStack(spacing: 10) {
            if isFailed {
                // No ring once it stopped: the red halo and badge say it, and STOPPED AT says
                // where. The ring's space is kept, so nothing moves (spec 005).
                artwork
                    .frame(width: Self.ringDiameter, height: Self.ringDiameter)
            } else if progress.isLive
                && (progress.phaseFraction == nil || (progress.phaseFraction == 1 && !progress.hasMeasuredCopyProgress))
            {
                ZStack(alignment: .bottomTrailing) {
                    artwork
                    ProgressView()
                        .controlSize(.small)
                }
                .frame(width: Self.ringDiameter, height: Self.ringDiameter)
                .accessibilityElement(children: .combine)
            } else {
                ProgressRing(
                    fraction: progress.isLive ? (progress.phaseFraction ?? 0) : progress.overallFraction,
                    label: progress.isLive
                        ? Text(progress.phase.name)
                        : Text("Creating installer", comment: "VoiceOver label of the progress ring."),
                    value: Text(
                        progress.isLive ? Int((progress.phaseFraction ?? 0) * 100) : progress.percent, format: .percent),
                    diameter: Self.ringDiameter,
                    tint: tint
                ) {
                    artwork
                }
            }

            // When it stopped, the percentage moves to STOPPED AT. Its space is kept (so nothing
            // below moves) but goes under the name, so the name stays right under the ring.
            VStack(spacing: 2) {
                if isFailed {
                    driveName
                    percentage
                        .hidden()
                } else {
                    percentage
                    driveName
                }
            }
        }
    }

    private var percentage: some View {
        Group {
            if progress.isLive
                && (progress.phaseFraction == nil || (progress.phaseFraction == 1 && !progress.hasMeasuredCopyProgress))
            {
                Text("In progress")
            } else {
                let percent = progress.isLive ? Int((progress.phaseFraction ?? 0) * 100) : progress.percent
                HStack(spacing: 6) {
                    if progress.isLive { Text(progress.phase.name) }
                    Text(percent, format: .percent)
                        .rollingFigure(Double(percent))
                }
            }
        }
        .font(Theme.Fonts.figure)
        .accessibilityHidden(true)
    }

    private var driveName: some View {
        Text(verbatim: "\(drive.name) · \(drive.detail)")
            .font(Theme.Fonts.footnote)
            .foregroundStyle(Theme.Colors.secondary)
            .lineLimit(1)
            .truncationMode(.middle)
            .accessibilityLabel(
                Text(verbatim: "\(drive.name), \(drive.detail.replacingOccurrences(of: " · ", with: ", "))"))
    }
}

// MARK: - Figures

/// ELAPSED / COPIED / REMAINING.
struct CreatingStats: View {
    let progress: CreationProgress
    var elapsed: Duration = .zero

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            BigStat(
                label: LocalizedStringResource(
                    "ELAPSED", comment: "Creating screen: elapsed time since creation started."),
                value: Text(verbatim: Self.elapsedText(elapsed)),
                rollingValue: Double(max(elapsed.components.seconds, 0))
            )
            .frame(maxWidth: .infinity)
            .accessibilityLabel(Text("ELAPSED"))
            .accessibilityValue(Text(verbatim: Self.elapsedText(elapsed)))
            .accessibilityIdentifier("creation.elapsed")

            if progress.phase != .format {
                BigStat(
                    label: LocalizedStringResource(
                        "COPIED", comment: "Creating screen figure: bytes of the installer copied to the drive so far."),
                    value: Text(
                        verbatim: progress.isLive && !progress.hasMeasuredCopyProgress
                            ? String(localized: "Measuring…") : Self.bytes(progress.displayedCopiedBytes)),
                    caption: progress.isLive && !progress.hasMeasuredCopyProgress
                        ? Text("Waiting for installer image data…")
                        : Text(
                            "of \(Self.bytes(progress.installerSize))",
                            comment:
                                "Creating screen, under COPIED. The value is the primary installer image's size, e.g. 18.4 GB."
                        ),
                    rollingValue: progress.isLive && !progress.hasMeasuredCopyProgress
                        ? nil : Double(progress.displayedCopiedBytes)
                )
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("creation.copied")
            }

            if progress.phase != .format {
                BigStat(
                    label: LocalizedStringResource(
                        "REMAINING", comment: "Creating screen figure: estimated time left."),
                    value: Text(progress.remaining.text),
                    rollingValue: remainingSeconds
                )
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("creation.remaining")
            }
        }
    }

    /// REMAINING in seconds, so it rolls downwards as it shrinks; 0 when there's no estimate.
    private var remainingSeconds: Double? {
        guard case .estimate(let duration) = progress.remaining else { return nil }
        return Double(duration.components.seconds)
    }

    /// Bytes formatted for people, writing zero as "0 bytes" rather than "Zero KB".
    private static func bytes(_ count: Int64) -> String {
        count.formatted(.byteCount(style: .file, spellsOutZero: false))
    }

    private static func elapsedText(_ duration: Duration) -> String {
        let seconds = max(duration.components.seconds, 0)
        return String(format: "%lld:%02lld", seconds / 60, seconds % 60)
    }
}

/// STOPPED AT, shown instead of the copy figures when it stopped. No caption: the phase bar
/// already shows the phase it stopped in.
struct FailureStats: View {
    let failure: CreationFailure

    var body: some View {
        BigStat(
            label: LocalizedStringResource(
                "STOPPED AT", comment: "Error screen figure: overall progress when creating stopped."),
            value: failure.progress.isLive
                ? Text(failure.progress.phase.name) : Text(failure.stoppedPercent, format: .percent),
            tint: Theme.Colors.danger
        )
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Footer

/// "Cancel", which asks before stopping. Esc presses it, as Apple's guidelines ask; it only opens
/// the confirmation.
struct CreatingFooter: View {
    let driveName: String
    let onStop: () -> Void

    @State private var isConfirmingCancel: Bool

    /// `isConfirmingCancel` opens the confirmation from the start, for previews.
    init(driveName: String, isConfirmingCancel: Bool = false, onStop: @escaping () -> Void) {
        self.driveName = driveName
        self.onStop = onStop
        _isConfirmingCancel = State(initialValue: isConfirmingCancel)
    }

    var body: some View {
        AssistantFooter(for: .creating) {
            Button("Cancel") {
                isConfirmingCancel = true
            }
            .buttonStyle(.secondary)
            .keyboardShortcut(.cancelAction)
        }
        .sheet(isPresented: $isConfirmingCancel) {
            StopCreationSheet(
                driveName: driveName,
                onKeepGoing: { isConfirmingCancel = false },
                onStop: {
                    isConfirmingCancel = false
                    onStop()
                }
            )
        }
    }
}

/// Asks before stopping, looking like a macOS alert. A sheet rather than a native alert so that
/// Return *and* Esc keep going (a native alert gives each button one key); "Stop" is destructive
/// and only answers a click. Spec 005, "Apple's Human Interface Guidelines".
struct StopCreationSheet: View {
    let driveName: String
    let onKeepGoing: () -> Void
    let onStop: () -> Void

    var body: some View {
        AlertSheet(
            title: Text(
                "Stop creating the installer?", comment: "Title of the alert shown when cancelling the creation."),
            message: Text(
                "“\(driveName)” will be left unusable until it's erased again.",
                comment: "Message of the cancel alert. The value is the drive's name, e.g. SanDisk Ultra."),
            action: Text("Stop", comment: "Alert button: stop creating the installer."),
            actionRole: .destructive,
            safeChoice: Text("Keep Going", comment: "Alert button: don't stop, keep creating the installer."),
            onAction: onStop,
            onSafeChoice: onKeepGoing)
    }
}

/// "Start Over" and "Try Again". "Try Again" is the default: it only goes back to Review,
/// where erasing has to be confirmed again.
struct CreationErrorFooter: View {
    let onStartOver: () -> Void
    let onTryAgain: () -> Void

    var body: some View {
        AssistantFooter(for: .creating) {
            Button(action: onStartOver) {
                Label {
                    Text("Start Over", comment: "Error screen button: go back to the first step.")
                } icon: {
                    Image(systemName: "arrow.uturn.backward")
                }
            }
            .buttonStyle(.secondary)

            Button(action: onTryAgain) {
                Label {
                    Text(
                        "Try Again",
                        comment: "Error screen button: go back to Review with the same drive and installer.")
                } icon: {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .buttonStyle(.primary)
            .keyboardShortcut(.defaultAction)
        }
    }
}

// MARK: - Whole screen

/// The whole screen as it appears in the window: content and footer, for the previews.
struct CreatingScreen: View {
    var state = CreationState.running(.sampleMidCopy)
    var isConfirmingCancel = false
    var simulation: CreationSimulation?

    var body: some View {
        VStack(spacing: 0) {
            CreatingView(
                installer: InstallerSource.samples[0], drive: Drive.samples[0], state: state, output: [],
                simulation: simulation
            )
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if state.failure == nil {
                CreatingFooter(driveName: Drive.samples[0].name, isConfirmingCancel: isConfirmingCancel, onStop: {})
            } else {
                CreationErrorFooter(onStartOver: {}, onTryAgain: {})
            }
        }
        .frame(width: Theme.Sizes.window.width, height: Theme.Sizes.window.height)
    }
}

// MARK: - Previews

#Preview("Format") {
    CreatingScreen(state: .running(.sampleFormat))
}

#Preview("Preparing installer") {
    CreatingScreen(
        state: .running(
            CreationProgress(
                phase: .format, phaseFraction: nil, installerSize: InstallerSource.samples[0].size,
                isLive: true, isPreparingInstaller: true)))
}

#Preview("Copy, no reported bytes") {
    CreatingScreen(state: .running(.sampleEarlyCopy))
}

#Preview("Copy") {
    CreatingScreen(state: .running(.sampleMidCopy))
}

#Preview("Copy, measured bytes") {
    CreatingScreen(state: .running(.sampleMeasuredCopy))
}

#Preview("Make bootable") {
    CreatingScreen(state: .running(.sampleMakeBootable))
}

#Preview("Verify") {
    CreatingScreen(state: .running(.sampleVerify))
}

#Preview("Error: drive disconnected") {
    CreatingScreen(state: .failed(.sampleDriveDisconnected))
}

#Preview("Error: cancelled") {
    CreatingScreen(state: .failed(.sampleCancelled))
}

#Preview("Simulated") {
    CreatingScreen(simulation: .everything)
}

#Preview("Error, simulated") {
    CreatingScreen(state: .failed(.sampleDriveDisconnected), simulation: .afterFormat)
}

#Preview("Cancel confirmation") {
    CreatingScreen(isConfirmingCancel: true)
}

#Preview("Classic (macOS 14–15)") {
    CreatingScreen(state: .running(.sampleMeasuredCopy))
        .environment(\.usesClassicControls, true)
}

#Preview("Error, classic (macOS 14–15)") {
    CreatingScreen(state: .failed(.sampleDriveDisconnected))
        .environment(\.usesClassicControls, true)
}

#Preview("Dark") {
    CreatingScreen(state: .running(.sampleMeasuredCopy))
        .preferredColorScheme(.dark)
}

#Preview("Error, dark") {
    CreatingScreen(state: .failed(.sampleDriveDisconnected))
        .preferredColorScheme(.dark)
}
