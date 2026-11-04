//
//  DownloadDetailsSheet.swift
//  Relente
//
//  Installer information, live progress and owned acquisition activity.
//  Design: intent/direct-installer-download/spec.md
//

import AppKit
import SwiftUI

struct DownloadDetailsSheet: View {
    private enum ArtworkState: Equatable {
        case failed
        case complete
        case cancelled
        case downloading
        case idle
    }

    let installer: AvailableInstaller
    let match: AvailableInstaller.LocalMatch
    let isDownloading: Bool
    var stage: InstallerAcquisitionStage = .downloading
    let isCancelling: Bool
    let wasCancelled: Bool
    let progress: Double?
    let transfer: InstallerTransferProgress?
    let error: InstallerAcquisitionError?
    let block: InstallerAcquisitionPolicy.Reason?
    let onCancel: () -> Void
    let onRetry: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isConfirmingCancellation = false

    private var isFailed: Bool { error != nil }
    private var hasWarning: Bool { isFailed || block != nil }
    private var isComplete: Bool {
        guard !isDownloading, !isFailed, block == nil, progress == 1 else { return false }
        if case .unique = match { return true }
        return false
    }
    private var artworkState: ArtworkState {
        if isFailed { return .failed }
        if isComplete { return .complete }
        if wasCancelled { return .cancelled }
        if isDownloading { return .downloading }
        return .idle
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Spacer()
                CircularCloseButton { dismiss() }
            }

            HStack(alignment: .center, spacing: 20) {
                VStack(spacing: 14) {
                    ZStack {
                        progressArtwork
                            .id(artworkState)
                            .transition(artworkTransition)
                            .zIndex(artworkState == .downloading ? 1 : 0)
                    }
                    .frame(width: 176, height: 176)
                    .animation(
                        reduceMotion ? .easeInOut(duration: 0.25) : .easeInOut(duration: 0.55),
                        value: artworkState
                    )
                    if isDownloading {
                        CancelDownloadButton(isDisabled: isCancelling, showsLabel: true) {
                            isConfirmingCancellation = true
                        }
                    } else if wasCancelled {
                        Button("Retry Download", action: onRetry)
                            .buttonStyle(.secondary)
                    }
                }
                .alignmentGuide(VerticalAlignment.center) { dimensions in
                    dimensions[.top] + 88
                }
                .animation(reduceMotion ? .easeInOut(duration: 0.2) : .easeInOut(duration: 0.35), value: isDownloading)

                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(installer.title)
                            .font(.title2.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 8) {
                            Text(verbatim: installer.version.description)
                            if let size = installer.sizeInBytes {
                                Text(verbatim: "·")
                                    .foregroundStyle(Theme.Colors.secondary)
                                Text(verbatim: ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                            }
                        }
                        .font(.title3.monospacedDigit())
                        .foregroundStyle(Theme.Colors.secondary)
                    }

                    status
                    stages
                }
                .fixedSize(horizontal: true, vertical: false)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 18)

            errorNotice
                .animation(.easeInOut(duration: reduceMotion ? 0.2 : 0.3), value: isFailed || block != nil)

        }
        .padding(16)
        .frame(width: 500, height: hasWarning ? 410 : 350, alignment: .top)
        .confirmationDialog(
            "Cancel this download?",
            isPresented: $isConfirmingCancellation,
            titleVisibility: .visible
        ) {
            Button("Keep Downloading", role: .cancel) {}
                .keyboardShortcut(.defaultAction)
            Button("Cancel Download", role: .destructive, action: onCancel)
        } message: {
            Text("You may need to download this installer again.")
        }
    }

    @ViewBuilder
    private var progressArtwork: some View {
        if isFailed {
            Button(action: onRetry) {
                AvailableInstallerArtwork(installer: installer, match: match, side: 144)
                    .overlay {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(Theme.Colors.accent)
                            .frame(width: 56, height: 56)
                            .background(.regularMaterial, in: Circle())
                    }
            }
            .buttonStyle(.plain)
            .pointingCursor()
            .accessibilityLabel("Retry Download")
            .disabled(error == .recoveryRequired)
        } else if isComplete {
            StatusBadge(kind: .success)
                .frame(width: 120, height: 120)
                .accessibilityHidden(false)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Installer ready")
        } else if wasCancelled {
            Image(systemName: "stop.fill")
                .font(.system(size: 42, weight: .medium))
                .foregroundStyle(Theme.Colors.secondary)
                .frame(width: 120, height: 120)
                .background(Theme.Colors.secondary.opacity(0.12), in: Circle())
                .accessibilityLabel("Download cancelled")
        } else if isDownloading {
            ProgressRing(
                fraction: progress ?? 0,
                label: Text("Download progress") + Text(verbatim: ", ") + progressValue,
                value: Text(verbatim: ""),
                diameter: 176,
                lineWidth: 5
            ) {
                VStack(spacing: 9) {
                    if isCancelling || progress == nil {
                        ProgressView()
                            .controlSize(.large)
                            .tint(Theme.Colors.accent)
                    } else if let progress {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(progress * 100, format: .number.precision(.fractionLength(0)))
                                .font(.system(size: 48, weight: .semibold).monospacedDigit())
                                .rollingFigure(progress * 100)
                            Text(verbatim: "%")
                                .font(.title3.weight(.medium))
                                .foregroundStyle(Theme.Colors.secondary)
                        }
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    }
                    if let bytes = downloadedBytes {
                        bytes
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Theme.Colors.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.9)
                            .frame(width: 158, alignment: .center)
                    }
                }
            }
        } else {
            AvailableInstallerArtwork(installer: installer, match: match, side: 144)
        }
    }

    private var artworkTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.94)),
            removal: .opacity.combined(with: .scale(scale: 0.98))
        )
    }

    @ViewBuilder
    private var status: some View {
        if isCancelling {
            Text("Cancelling download")
                .font(.callout)
                .foregroundStyle(Theme.Colors.secondary)
        }
    }

    @ViewBuilder
    private var errorNotice: some View {
        if error == .recoveryRequired {
            Button("Show Installer Storage in Finder") {
                NSWorkspace.shared.open(InstallerArtifactStore().root)
            }
            .buttonStyle(.secondary)
        } else if let error {
            notice(title: Text("Download Failed"), message: Text(error.message))
        } else if let block {
            notice(title: Text("Download Unavailable"), message: Text(block.message))
        }
    }

    private func notice(title: Text, message: Text) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Theme.Colors.warning)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                title
                    .font(.headline)
                    .foregroundStyle(Theme.Colors.warning)
                message
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.warning.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .transition(.opacity)
    }

    private var downloadedBytes: Text? {
        guard stage == .downloading, let transfer else { return nil }
        let downloaded = ByteCountFormatter.string(fromByteCount: transfer.bytes, countStyle: .file)
        if let total = transfer.total {
            let size = ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
            return Text("\(downloaded) of \(size)", comment: "Downloaded bytes and total download size.")
        }
        return Text("\(downloaded) downloaded", comment: "Bytes downloaded when total size is unknown.")
    }

    private var progressValue: Text {
        let value = progress.map { Text($0, format: .percent.precision(.fractionLength(0))) } ?? Text(stage.title)
        guard let bytes = downloadedBytes else { return value }
        return value + Text(verbatim: ", ") + bytes
    }

    private var stages: some View {
        let ordered: [InstallerAcquisitionStage] = [.connecting, .downloading, .verifying, .preparing]
        let symbols = ["network", "arrow.down", "shield", "shippingbox"]
        let current = ordered.firstIndex(of: stage) ?? 0
        return HStack(spacing: 0) {
            ForEach(Array(ordered.enumerated()), id: \.offset) { index, item in
                let completed = index < current || isComplete
                let active = index == current && isDownloading
                if index > 0 {
                    Rectangle()
                        .fill(Theme.Colors.secondary.opacity(0.3))
                        .frame(width: 10, height: 1)
                        .accessibilityHidden(true)
                }
                Image(systemName: symbols[index])
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(
                        completed ? Theme.Colors.success : active ? Theme.Colors.accent : Theme.Colors.secondary
                    )
                    .frame(width: 30, height: 30)
                    .background(
                        completed
                            ? Theme.Colors.success.opacity(0.16)
                            : active ? Theme.Colors.accent.opacity(0.16) : Theme.Colors.secondary.opacity(0.12),
                        in: Circle()
                    )
                    .accessibilityLabel(Text(item.title))
                    .accessibilityValue(completed ? Text("Completed") : active ? Text("In progress") : Text("Pending"))
            }
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.15) : .easeInOut(duration: 0.35), value: stage)
        .animation(reduceMotion ? .easeInOut(duration: 0.15) : .easeInOut(duration: 0.35), value: isComplete)
        .padding(.top, 8)
    }

}

#Preview {
    DownloadDetailsSheet(
        installer: AvailableInstaller(
            title: "macOS Tahoe", version: "26.1", build: "25B354", sizeInBytes: 18_000_000_000),
        match: .none,
        isDownloading: true,
        isCancelling: false,
        wasCancelled: false,
        progress: 0.42,
        transfer: InstallerTransferProgress(bytes: 7_560_000_000, total: 18_000_000_000, bytesPerSecond: 30_000_000),
        error: nil,
        block: nil,
        onCancel: {},
        onRetry: {}
    )
}
