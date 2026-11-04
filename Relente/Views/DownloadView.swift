//
//  DownloadView.swift
//  Relente
//
//  Apple's full installer catalog, shown as a substate of Installer.
//  Design: intent/direct-installer-download/spec.md
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct DownloadView: View {
    let installers: [AvailableInstaller]
    let localInstallers: [InstallerSource]
    let selectedID: AvailableInstaller.ID?
    let isLoading: Bool
    let hasLoadedInstallers: Bool
    let isDownloading: Bool
    var stage: InstallerAcquisitionStage = .downloading
    let isCancelling: Bool
    let wasCancelled: Bool
    let downloadingID: AvailableInstaller.ID?
    let progress: Double?
    let transfer: InstallerTransferProgress?
    let error: InstallerAcquisitionError?
    let block: InstallerAcquisitionPolicy.Reason?
    let onRetry: () -> Void
    let onDownload: (AvailableInstaller) -> Void
    let onUse: (AvailableInstaller) -> Void
    let onCancel: () -> Void
    let onMoveSelection: (Int) -> Void

    @State private var mainDownloadDetails: AvailableInstaller?
    @State private var localAppIcons: [URL: NSImage] = [:]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.drawsSelectionInRow) private var drawsSelectionInRow

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(
                title: "Download macOS",
                subtitle: headerSubtitle
            )
            .padding(.top, Theme.Sizes.headerTopPadding)
            .padding(.bottom, 8)

            if isLoading, !supportedInstallers.isEmpty {
                Label("Refreshing Apple’s list…", systemImage: "arrow.clockwise")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.secondary)
                    .padding(.bottom, 4)
            }

            if isLoading, supportedInstallers.isEmpty {
                ProgressView("Loading Apple’s installer list…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if supportedInstallers.isEmpty {
                emptyCatalog
            } else {
                installerGrid
            }

            if error == .recoveryRequired, !supportedInstallers.isEmpty {
                Button("Show Installer Storage in Finder") {
                    NSWorkspace.shared.open(InstallerArtifactStore().root)
                }
                .buttonStyle(.secondary)
                .padding(.top, 8)
            }
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .easeInOut(duration: 0.4), value: isDownloading)
        .task(id: localInstallers) {
            var icons: [URL: NSImage] = [:]
            for installer in localInstallers where installer.kind == .app {
                icons[installer.url] = FileIcon.loadIcon(url: installer.url, fallbackType: .applicationBundle)
            }
            localAppIcons = icons
        }
        .onReceive(NotificationCenter.default.publisher(for: RelenteAppDelegate.dismissDownloadSheets)) { _ in
            mainDownloadDetails = nil
        }
        .environment(\.marksArtworkOnlyWhileChangingScreen, true)

    }

    private var installerGrid: some View {
        Group {
            switch layout {
            case .row:
                HStack(alignment: .top, spacing: 24) {
                    ForEach(latestInstallers) { installer in
                        installerOption(
                            installer,
                            itemSize: .regular,
                            openDetails: { mainDownloadDetails = $0 }
                        )
                        .id(installer.id)
                    }
                }
                .padding(.horizontal, 16)
                .selectsWithArrowKeys(onMoveSelection)
                .slidingSelection(selectedID)
                .frame(maxHeight: .infinity)
            case .grid:
                PickCollection(
                    itemCount: latestInstallers.count,
                    selection: selectedID,
                    onMoveSelection: onMoveSelection,
                    isScrollDisabled: isDownloading
                ) {
                    ForEach(latestInstallers) { installer in
                        installerOption(
                            installer,
                            itemSize: .compact,
                            openDetails: { mainDownloadDetails = $0 }
                        )
                        .id(installer.id)
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .sheet(item: $mainDownloadDetails) { installer in
            downloadDetailsSheet(for: installer)
        }
    }

    private var emptyCatalog: some View {
        Group {
            if error == .recoveryRequired {
                ContentUnavailableView {
                    Label {
                        Text("Previous Download Needs Review")
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Theme.Colors.warning)
                    }
                } description: {
                    Text("Relente couldn’t confirm that the previous work finished safely.")
                } actions: {
                    Button("Open Folder in Finder", systemImage: "folder") {
                        NSWorkspace.shared.open(InstallerArtifactStore().root)
                    }
                    .buttonStyle(.secondary)
                }
            } else if error == .catalogUnavailable {
                ContentUnavailableView {
                    Label("Installer List Unavailable", systemImage: "exclamationmark.triangle.fill")
                } description: {
                    Text("Relente couldn’t load Apple’s installer list. Try again.")
                } actions: {
                    Button("Try Again", action: onRetry)
                        .buttonStyle(.secondary)
                }
            } else {
                ContentUnavailableView(
                    "No Full Installers Available",
                    systemImage: "arrow.down.circle",
                    description: Text(
                        "Choose a local installer or try again later."
                    )
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var supportedInstallers: [AvailableInstaller] {
        AvailableInstaller.sorted(installers.filter(\.isSupported))
    }

    private var headerSubtitle: LocalizedStringResource {
        switch error {
        case .recoveryRequired: "Review the pending work before downloading."
        case .catalogUnavailable: "Try loading the list again."
        default: "Choose a full installer available for this Mac."
        }
    }

    private var layout: PickLayout {
        PickLayout(itemCount: latestInstallers.count)
    }

    private var latestInstallers: [AvailableInstaller] {
        AvailableInstaller.latestPerFamily(supportedInstallers)
    }

    @ViewBuilder
    private func installerOption(
        _ installer: AvailableInstaller,
        itemSize: PickItemSize,
        openDetails: @escaping (AvailableInstaller) -> Void
    ) -> some View {
        let match = installer.localMatch(in: localInstallers)
        let isActive = downloadingID == installer.id && isDownloading
        let canRetry = error == .downloadFailed && selectedID == installer.id
        let artworkSide = itemSize.iconSide
        let artworkContainerSide = itemSize.plateSide
        let sizeText = installer.sizeInBytes.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) }

        VStack(spacing: 0) {
            Button {
                activate(installer, match: match, isActive: isActive, canRetry: canRetry, openDetails: openDetails)
            } label: {
                VStack(spacing: 0) {
                    ZStack {
                        AvailableInstallerArtwork(
                            installer: installer, match: match, side: artworkSide,
                            preloadedIcon: {
                                if case .unique(let source) = match { return localAppIcons[source.url] }
                                return nil
                            }()
                        )
                        .sharedArtwork(
                            .installer,
                            isActive: selectedID == installer.id && hasUniqueLocalMatch(match)
                        )
                        .overlay(alignment: .bottomTrailing) {
                            if case .unique = match {
                                StatusBadge(kind: .success)
                                    .frame(width: 20, height: 20)
                                    .offset(x: 5, y: 5)
                            }
                        }
                        .overlay(alignment: .bottomTrailing) {
                            if isActive {
                                ProgressView()
                                    .controlSize(.small)
                                    .padding(8)
                                    .background(.regularMaterial, in: Circle())
                                    .accessibilityHidden(true)
                            }
                        }
                        .overlay {
                            if canRetry {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(Theme.Colors.accent)
                                    .frame(width: 44, height: 44)
                                    .background(.regularMaterial, in: Circle())
                                    .overlay { Circle().strokeBorder(.quaternary, lineWidth: 1) }
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                    .frame(width: artworkContainerSide, height: artworkContainerSide)
                    .background {
                        if drawsSelectionInRow {
                            Color.clear.anchorPreference(key: SelectionMarks.self, value: .bounds) { anchor in
                                selectedID == installer.id && !isActive
                                    ? SelectionMarks.Value(shapes: [.plate: anchor]) : .init()
                            }
                        } else if selectedID == installer.id && !isActive {
                            PickItem<EmptyView, EmptyView>.plate
                        }
                    }
                    .animation(reduceMotion ? .easeInOut(duration: 0.2) : .easeInOut(duration: 0.4), value: isActive)

                    Text(installer.title)
                        .font(PickItem<EmptyView, EmptyView>.nameFont)
                        .lineLimit(1)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(selectedID == installer.id && !drawsSelectionInRow ? .white : .primary)
                        .anchorPreference(key: SelectionMarks.self, value: .bounds) { anchor in
                            drawsSelectionInRow
                                ? SelectionMarks.Value(names: [.init(title: installer.title, anchor: anchor)]) : .init()
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background {
                            if drawsSelectionInRow {
                                Color.clear.anchorPreference(key: SelectionMarks.self, value: .bounds) { anchor in
                                    selectedID == installer.id
                                        ? SelectionMarks.Value(shapes: [.capsule: anchor]) : .init()
                                }
                            } else if selectedID == installer.id {
                                PickItem<EmptyView, EmptyView>.capsule
                            }
                        }
                        .padding(.top, 6)

                }
            }
            .buttonStyle(.plain)
            .pointingCursor()
            .accessibilityLabel(
                isActive
                    ? Text(
                        "Show download details for \(installer.title) \(installer.version.description)",
                        comment:
                            "VoiceOver action to open details for the active installer; values are its family name and version."
                    )
                    : canRetry ? Text("Retry Download") : actionLabel(for: installer, match: match)
            )
            .accessibilityHint(
                isActive
                    ? Text("Open the download details to see progress or cancel.")
                    : canRetry
                        ? Text("Try downloading this macOS version again.") : actionHint(for: match)
            )
            .accessibilityIdentifier("installer-artwork-\(installer.id)")
            .accessibilityHidden(!isActive)
            .accessibilityValue(Text(stage.title))
            .focusable(isActive)
            .accessibilityAddTraits(selectedID == installer.id ? .isSelected : [])
            .disabled(
                !isActive
                    && (isCancelling || isDownloading || isLoading || match == .ambiguous
                        || (error == .recoveryRequired && !hasUniqueLocalMatch(match)))
            )

            HStack(spacing: 2) {
                Button {
                    activate(installer, match: match, isActive: isActive, canRetry: canRetry, openDetails: openDetails)
                } label: {
                    HStack(spacing: 3) {
                        Text(verbatim: installer.version.description)
                            .font(metadataFont(for: itemSize).monospacedDigit())
                            .foregroundStyle(Theme.Colors.secondary)
                        if let sizeText {
                            Text(verbatim: "·")
                                .font(metadataFont(for: itemSize))
                                .foregroundStyle(Theme.Colors.secondary)
                            Text(verbatim: sizeText)
                                .font(metadataFont(for: itemSize).monospacedDigit())
                                .foregroundStyle(Theme.Colors.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.9)
                        }
                    }
                    .padding(.horizontal, itemSize == .regular ? 7 : 2)
                    .padding(.vertical, 1)
                }
                .buttonStyle(.plain)
                .pointingCursor()
                .accessibilityIdentifier("installer-action-\(installer.id)")
                .accessibilityLabel(actionLabel(for: installer, match: match))
                .accessibilityValue(Text(verbatim: sizeText ?? ""))
                .disabled(
                    isDownloading || isLoading || match == .ambiguous
                        || (error == .recoveryRequired && !hasUniqueLocalMatch(match)))

            }
            .frame(height: 24)
            .padding(.top, 6)
        }
        .frame(maxWidth: itemSize.width, minHeight: 160, alignment: .top)
    }

    private func metadataFont(for itemSize: PickItemSize) -> Font {
        itemSize == .regular ? .body : .caption
    }

    private func hasUniqueLocalMatch(_ match: AvailableInstaller.LocalMatch) -> Bool {
        if case .unique = match { return true }
        return false
    }

    private func downloadDetailsSheet(for installer: AvailableInstaller) -> some View {
        DownloadDetailsSheet(
            installer: installer,
            match: installer.localMatch(in: localInstallers),
            isDownloading: downloadingID == installer.id && isDownloading,
            stage: stage,
            isCancelling: isCancelling,
            wasCancelled: selectedID == installer.id && wasCancelled,
            progress: selectedID == installer.id ? progress : nil,
            transfer: selectedID == installer.id ? transfer : nil,
            error: selectedID == installer.id ? error : nil,
            block: selectedID == installer.id ? block : nil,
            onCancel: onCancel,
            onRetry: { onDownload(installer) }
        )
    }

    private func activate(
        _ installer: AvailableInstaller,
        match: AvailableInstaller.LocalMatch,
        isActive: Bool,
        canRetry: Bool,
        openDetails: (AvailableInstaller) -> Void
    ) {
        if isActive {
            openDetails(installer)
        } else if canRetry || match == .none {
            onDownload(installer)
            openDetails(installer)
        } else if case .unique = match {
            onUse(installer)
        }
    }

    private func actionLabel(for installer: AvailableInstaller, match: AvailableInstaller.LocalMatch) -> Text {
        switch match {
        case .unique:
            Text(
                "Use \(installer.title) \(installer.version.description)",
                comment: "Accessible label for activating an installer option to use a local installer."
            )
        case .none:
            Text(
                "Download \(installer.title) \(installer.version.description)",
                comment: "Accessible label for activating a macOS installer option to download."
            )
        case .ambiguous:
            Text(
                "macOS \(installer.version.description)", comment: "Accessible label for an ambiguous installer option."
            )
        }
    }

    private func actionHint(for match: AvailableInstaller.LocalMatch) -> Text {
        switch match {
        case .unique:
            Text("This installer is already on this Mac.")
        case .none:
            Text("Downloads this installer from Apple.")
        case .ambiguous:
            Text("Choose an installer on the Installer screen.")
        }
    }

}

#Preview {
    DownloadView(
        installers: [
            AvailableInstaller(title: "macOS Tahoe", version: "26.1", build: "25B354"),
            AvailableInstaller(title: "macOS Tahoe", version: "26.0", build: "25A354"),
            AvailableInstaller(title: "macOS Sequoia", version: "15.8", build: "24H232"),
            AvailableInstaller(title: "macOS Sonoma", version: "14.8", build: "23J124"),
        ],
        localInstallers: InstallerSource.samples,
        selectedID: "26.1|25B354|macOS Tahoe",
        isLoading: false,
        hasLoadedInstallers: true,
        isDownloading: false,
        isCancelling: false,
        wasCancelled: false,
        downloadingID: nil,
        progress: nil,
        transfer: nil,
        error: nil,
        block: nil,

        onRetry: {},
        onDownload: { _ in },
        onUse: { _ in },
        onCancel: {},

        onMoveSelection: { _ in }
    )
    .padding(32)
    .frame(width: 800, height: 480)
}

#Preview("Classic (macOS 14–15)") {
    DownloadView(
        installers: [AvailableInstaller(title: "macOS Tahoe", version: "26.0", build: "25A354")],
        localInstallers: [], selectedID: nil, isLoading: false, hasLoadedInstallers: true,
        isDownloading: false, isCancelling: false,
        wasCancelled: false,
        downloadingID: nil, progress: nil, transfer: nil, error: nil, block: nil,

        onRetry: {}, onDownload: { _ in }, onUse: { _ in }, onCancel: {},
        onMoveSelection: { _ in }
    )
    .padding(32)
    .frame(width: 800, height: 480)
    .environment(\.usesClassicControls, true)
}

#Preview("Dark") {
    DownloadView(
        installers: [AvailableInstaller(title: "macOS Tahoe", version: "26.0", build: "25A354")],
        localInstallers: [], selectedID: nil, isLoading: false, hasLoadedInstallers: true,
        isDownloading: true, isCancelling: false,
        wasCancelled: false,
        downloadingID: "26.0|25A354|macOS Tahoe", progress: nil, transfer: nil, error: nil, block: nil,

        onRetry: {}, onDownload: { _ in }, onUse: { _ in }, onCancel: {},
        onMoveSelection: { _ in }
    )
    .padding(32)
    .frame(width: 800, height: 480)
    .preferredColorScheme(.dark)
}
