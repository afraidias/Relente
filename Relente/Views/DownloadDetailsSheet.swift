//
//  DownloadDetailsSheet.swift
//  Relente
//
//  Installer information, live progress and recent softwareupdate output.
//  Spec: specs/011-installer-acquisition/spec.md
//

import SwiftUI

struct DownloadDetailsSheet: View {
    private enum ArtworkState: Equatable {
        case failed
        case complete
        case downloading
        case idle
    }

    let installer: AvailableInstaller
    let match: AvailableInstaller.LocalMatch
    let isDownloading: Bool
    let isCancelling: Bool
    let wasCancelled: Bool
    let progress: Double?
    let output: [CreationOutputLine]
    let error: InstallerAcquisitionError?
    let block: InstallerAcquisitionPolicy.Reason?
    let onCancel: () -> Void
    let onRetry: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isConfirmingCancellation = false
    @State private var isActivityExpanded = true

    private var isFailed: Bool { error == .downloadFailed }
    private var hasWarning: Bool { isFailed || block != nil }
    private var isComplete: Bool {
        guard !isDownloading, !isFailed, block == nil, progress == 1 else { return false }
        if case .unique = match { return true }
        return false
    }
    private var artworkState: ArtworkState {
        if isFailed { return .failed }
        if isComplete { return .complete }
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
                    if isDownloading {
                        CancelDownloadButton(isDisabled: isCancelling) {
                            isConfirmingCancellation = true
                        }
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 18)

            errorNotice
                .animation(.easeInOut(duration: reduceMotion ? 0.2 : 0.3), value: isFailed || block != nil)

            Divider()
                .padding(.top, hasWarning ? 12 : 48)
                .padding(.bottom, 8)

            VStack(alignment: .leading, spacing: 4) {
                Button {
                    withAnimation(.easeInOut(duration: reduceMotion ? 0.12 : 0.18)) {
                        isActivityExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: isActivityExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.Colors.secondary)
                            .frame(width: 16)
                        Text("Activity")
                            .font(.headline)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .pointingCursor()
                .accessibilityLabel("Activity")
                .accessibilityAddTraits(isActivityExpanded ? .isSelected : [])
                .accessibilityHint("Show or hide command activity.")

                if isActivityExpanded {
                    activity
                        .frame(minHeight: 0, maxHeight: .infinity)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .layoutPriority(1)
        }
        .padding(16)
        .frame(width: 660, height: hasWarning ? 500 : 440, alignment: .top)
        .confirmationDialog(
            "Cancel this download?",
            isPresented: $isConfirmingCancellation,
            titleVisibility: .visible
        ) {
            Button("Keep Downloading", role: .cancel) {}
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
        } else if isComplete {
            StatusBadge(kind: .success)
                .frame(width: 120, height: 120)
        } else if isDownloading {
            ProgressRing(
                fraction: progress ?? 0,
                label: Text("Download progress"),
                value: progress.map { Text($0, format: .percent.precision(.fractionLength(0))) }
                    ?? Text("Preparing download"),
                diameter: 176,
                lineWidth: 5
            ) {
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
        } else if isComplete {
            Text("Download complete")
                .font(.callout)
                .foregroundStyle(Theme.Colors.success)
        } else if wasCancelled {
            Text("Cancellation requested. macOS may continue downloading.")
                .font(.callout)
                .foregroundStyle(Theme.Colors.secondary)
        }
    }

    @ViewBuilder
    private var errorNotice: some View {
        if isFailed, let error {
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

    private var activity: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    if output.isEmpty {
                        Text("Waiting for activity…")
                            .foregroundStyle(Theme.Colors.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    ForEach(Array(output.enumerated()), id: \.offset) { item in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(item.element.timestamp, format: .dateTime.hour().minute().second())
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(Theme.Colors.secondary)
                                .fixedSize()
                            Text(verbatim: item.element.text)
                                .font(.system(.callout, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .id(item.offset)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            }
            .onAppear { scrollToLatest(proxy) }
            .onChange(of: output.count) { scrollToLatest(proxy) }
        }
        .scrollIndicators(.visible)
    }

    private func scrollToLatest(_ proxy: ScrollViewProxy) {
        guard let lastIndex = output.indices.last else { return }
        proxy.scrollTo(lastIndex, anchor: .bottom)
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
        output: [CreationOutputLine(timestamp: .now, text: "Downloading: 42.0%...")],
        error: nil,
        block: nil,
        onCancel: {},
        onRetry: {}
    )
}
