//
//  DownloadView.swift
//  Relente
//
//  Apple's full installer catalog, shown as a substate of Installer.
//  Spec: specs/011-installer-acquisition/spec.md
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct DownloadView: View {
    private struct FamilySelection: Identifiable {
        let title: String
        var id: String { title }
    }

    let installers: [AvailableInstaller]
    let localInstallers: [InstallerSource]
    let selectedID: AvailableInstaller.ID?
    let isLoading: Bool
    let hasLoadedInstallers: Bool
    let isDownloading: Bool
    let isCancelling: Bool
    let wasCancelled: Bool
    let downloadingID: AvailableInstaller.ID?
    let progress: Double?
    let output: [CreationOutputLine]
    let error: InstallerAcquisitionError?
    let block: InstallerAcquisitionPolicy.Reason?
    let incompleteInstallers: [IncompleteInstaller]
    let incompleteInstallerError: IncompleteInstallerError?
    let onRetry: () -> Void
    let onDownload: (AvailableInstaller) -> Void
    let onUse: (AvailableInstaller) -> Void
    let onCancel: () -> Void
    let onMoveToTrash: (IncompleteInstaller) -> Void
    let onDismissIncompleteInstallerError: () -> Void
    let onMoveSelection: (Int) -> Void

    @State private var olderVersionsFamily: FamilySelection?
    @State private var mainDownloadDetails: AvailableInstaller?
    @State private var olderDownloadDetails: AvailableInstaller?
    @State private var isConfirmingDownloadCancellation = false
    @State private var isConfirmingOlderDownloadCancellation = false
    @State private var localAppIcons: [URL: NSImage] = [:]

    private let scrollMargin: CGFloat = 16
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.drawsSelectionInRow) private var drawsSelectionInRow

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(
                title: "Download macOS",
                subtitle: "Choose a full installer available for this Mac."
            )
            .padding(.top, Theme.Sizes.headerTopPadding)
            .padding(.bottom, 8)

            if hasLoadedInstallers, !incompleteInstallers.isEmpty {
                IncompleteInstallerRecoveryView(
                    installers: incompleteInstallers,
                    isDownloading: isDownloading,
                    error: incompleteInstallerError,
                    onMoveToTrash: onMoveToTrash,
                    onDismissError: onDismissIncompleteInstallerError
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
            }

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

            if let error, error != .downloadFailed, !isShowingDetailsSheet {
                Text(error.message)
                    .foregroundStyle(Theme.Colors.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)
                if error != .downloadFailed {
                    Button("Try Again", action: onRetry)
                        .buttonStyle(.secondary)
                        .padding(.top, 8)
                }
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
        .environment(\.marksArtworkOnlyWhileChangingScreen, true)
        .sheet(item: $olderVersionsFamily) { family in
            olderVersionsSheet(for: family.title)
                .interactiveDismissDisabled(isDownloading)
        }
        .confirmationDialog(
            "Cancel this download?",
            isPresented: $isConfirmingDownloadCancellation,
            titleVisibility: .visible
        ) {
            Button("Keep Downloading", role: .cancel) {}
            Button("Cancel Download", role: .destructive, action: onCancel)
        } message: {
            Text("You may need to download this installer again.")
        }
    }

    private var installerGrid: some View {
        Group {
            switch layout {
            case .row:
                HStack(alignment: .top, spacing: 24) {
                    ForEach(latestInstallers) { installer in
                        installerOption(
                            installer,
                            showsHistoryControl: true,
                            itemSize: .regular,
                            requestCancel: { isConfirmingDownloadCancellation = true },
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
                            showsHistoryControl: true,
                            itemSize: .compact,
                            requestCancel: { isConfirmingDownloadCancellation = true },
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
        ContentUnavailableView(
            "No Full Installers Available",
            systemImage: "arrow.down.circle",
            description: Text("Apple isn’t offering a full installer for this Mac right now.")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var supportedInstallers: [AvailableInstaller] {
        AvailableInstaller.sorted(installers.filter(\.isSupported))
    }

    private var layout: PickLayout {
        PickLayout(itemCount: latestInstallers.count)
    }

    private var familyTitles: [String] {
        var seen = Set<String>()
        return supportedInstallers.compactMap { seen.insert($0.title).inserted ? $0.title : nil }
    }

    private var isShowingDetailsSheet: Bool {
        mainDownloadDetails != nil || olderDownloadDetails != nil
    }

    private var latestInstallers: [AvailableInstaller] {
        familyTitles.flatMap { title -> [AvailableInstaller] in
            let family = installers(in: title)
            guard let latest = family.first?.version else { return [] }
            return family.filter { $0.version == latest }
        }
    }

    private func installers(in title: String) -> [AvailableInstaller] {
        supportedInstallers.filter { $0.title == title }
    }

    private func olderInstallers(in title: String) -> [AvailableInstaller] {
        let family = installers(in: title)
        guard let latest = family.first?.version else { return [] }
        return family.filter { $0.version != latest }
    }

    @ViewBuilder
    private func installerOption(
        _ installer: AvailableInstaller,
        showsHistoryControl: Bool,
        itemSize: PickItemSize,
        fillsColumn: Bool = false,
        sharesArtwork: Bool = true,
        requestCancel: @escaping () -> Void,
        openDetails: @escaping (AvailableInstaller) -> Void
    ) -> some View {
        let match = installer.localMatch(in: localInstallers)
        let isActive = downloadingID == installer.id && isDownloading
        let canRetry = error == .downloadFailed && selectedID == installer.id
        let artworkSide = itemSize.iconSide
        let artworkContainerSide = itemSize.plateSide
        let sizeText = installer.sizeInBytes.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) }
        let hasDownloadedOlderVersion =
            showsHistoryControl
            && olderInstallers(in: installer.title).contains {
                hasUniqueLocalMatch($0.localMatch(in: localInstallers))
            }

        VStack(spacing: 0) {
            Button {
                activate(installer, match: match, isActive: isActive, canRetry: canRetry, openDetails: openDetails)
            } label: {
                VStack(spacing: 0) {
                    ZStack {
                        if isActive {
                            activeProgressArtwork(iconSide: artworkSide, containerSide: artworkContainerSide)
                                .transition(reduceMotion ? .opacity : .scale(scale: 0.8).combined(with: .opacity))
                        } else {
                            AvailableInstallerArtwork(
                                installer: installer, match: match, side: artworkSide,
                                preloadedIcon: {
                                    if case .unique(let source) = match { return localAppIcons[source.url] }
                                    return nil
                                }()
                            )
                            .sharedArtwork(
                                .installer,
                                isActive: sharesArtwork && selectedID == installer.id && hasUniqueLocalMatch(match)
                            )
                            .overlay(alignment: .bottomTrailing) {
                                if case .unique = match {
                                    StatusBadge(kind: .success)
                                        .frame(width: 20, height: 20)
                                        .offset(x: 5, y: 5)
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
                            .transition(reduceMotion ? .opacity : .scale(scale: 0.8).combined(with: .opacity))
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
                    ? Text("Downloading")
                    : canRetry ? Text("Retry Download") : actionLabel(for: installer, match: match)
            )
            .accessibilityHint(
                isActive
                    ? Text("Use Cancel beside the version to stop this download.")
                    : canRetry
                        ? Text("Try downloading this macOS version again.") : actionHint(for: match)
            )
            .accessibilityAddTraits(selectedID == installer.id ? .isSelected : [])
            .disabled(!isActive && (isCancelling || isDownloading || isLoading || match == .ambiguous))

            HStack(spacing: 2) {
                if itemSize == .regular && (isActive || showsHistoryControl) {
                    Color.clear.frame(width: 24, height: 24).accessibilityHidden(true)
                }
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
                .accessibilityLabel(actionLabel(for: installer, match: match))
                .accessibilityValue(Text(verbatim: sizeText ?? ""))
                .disabled(isDownloading || isLoading || match == .ambiguous)

                if isActive {
                    CancelDownloadButton(isDisabled: isCancelling) {
                        requestCancel()
                    }
                } else if showsHistoryControl, !olderInstallers(in: installer.title).isEmpty {
                    Button {
                        olderVersionsFamily = FamilySelection(title: installer.title)
                    } label: {
                        ZStack(alignment: .bottomTrailing) {
                            Image(systemName: "chevron.down")
                                .font(.caption.weight(.semibold))
                                .frame(width: 24, height: 24)
                                .contentShape(Rectangle())
                            if hasDownloadedOlderVersion {
                                StatusBadge(kind: .success)
                                    .frame(width: 12, height: 12)
                                    .accessibilityHidden(true)
                            }
                        }
                        .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.Colors.secondary)
                    .pointingCursor()
                    .accessibilityLabel(
                        Text(
                            "Older \(installer.title.replacingOccurrences(of: "macOS ", with: "")) versions",
                            comment:
                                "Accessible label for the control that opens older versions of a macOS release family."
                        )
                    )
                    .accessibilityValue(
                        hasDownloadedOlderVersion ? Text("A downloaded older version is available") : Text("")
                    )
                    .disabled(isLoading || isDownloading)
                } else if showsHistoryControl {
                    Color.clear.frame(width: 24, height: 24).accessibilityHidden(true)
                }
            }
            .frame(height: 24)
            .padding(.top, 6)
        }
        .frame(maxWidth: fillsColumn ? .infinity : itemSize.width, minHeight: 160, alignment: .top)
    }

    private func metadataFont(for itemSize: PickItemSize) -> Font {
        itemSize == .regular ? .body : .caption
    }

    private func hasUniqueLocalMatch(_ match: AvailableInstaller.LocalMatch) -> Bool {
        if case .unique = match { return true }
        return false
    }

    private func olderVersionsSheet(for familyTitle: String) -> some View {
        let columnCount = min(2, max(1, olderInstallers(in: familyTitle).count))
        return VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: familyTitle)
                        .font(.title2.weight(.semibold))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Older versions")
                        .font(.subheadline)
                        .foregroundStyle(Theme.Colors.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                CircularCloseButton(isDisabled: isDownloading || olderDownloadDetails != nil) {
                    olderVersionsFamily = nil
                }
            }
            .padding(20)

            ScrollViewReader { scroller in
                ScrollView(.vertical) {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: columnCount), spacing: 12
                    ) {
                        ForEach(olderInstallers(in: familyTitle)) { installer in
                            installerOption(
                                installer,
                                showsHistoryControl: false,
                                itemSize: .regular,
                                fillsColumn: true,
                                sharesArtwork: false,
                                requestCancel: { isConfirmingOlderDownloadCancellation = true },
                                openDetails: { olderDownloadDetails = $0 }
                            )
                            .id(installer.id)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .selectsWithArrowKeys(rowLength: columnCount, onMoveSelection)
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollDisabled(isDownloading)
                .scrollIndicators(.visible)
                .contentMargins(.vertical, scrollMargin, for: .scrollContent)
                .mask { scrollEdgeFade }
                .onAppear { if let downloadingID { scroller.scrollTo(downloadingID, anchor: .center) } }
            }
        }
        .frame(width: columnCount == 1 ? 400 : 480, height: columnCount == 1 ? 330 : 400)
        .sheet(item: $olderDownloadDetails) { installer in
            downloadDetailsSheet(for: installer)
        }
        .confirmationDialog(
            "Cancel this download?",
            isPresented: $isConfirmingOlderDownloadCancellation,
            titleVisibility: .visible
        ) {
            Button("Keep Downloading", role: .cancel) {}
            Button("Cancel Download", role: .destructive, action: onCancel)
        } message: {
            Text("You may need to download this installer again.")
        }
        .onExitCommand { if !isDownloading { olderVersionsFamily = nil } }
    }

    private func downloadDetailsSheet(for installer: AvailableInstaller) -> some View {
        DownloadDetailsSheet(
            installer: installer,
            match: installer.localMatch(in: localInstallers),
            isDownloading: downloadingID == installer.id && isDownloading,
            isCancelling: isCancelling,
            wasCancelled: selectedID == installer.id && wasCancelled,
            progress: selectedID == installer.id ? progress : nil,
            output: selectedID == installer.id ? output : [],
            error: selectedID == installer.id ? error : nil,
            block: selectedID == installer.id ? block : nil,
            onCancel: onCancel,
            onRetry: { onDownload(installer) }
        )
    }

    private func activeProgressArtwork(iconSide: CGFloat, containerSide: CGFloat) -> some View {
        let value: Text =
            if let progress {
                Text(progress, format: .percent.precision(.fractionLength(0)))
            } else if isCancelling {
                Text("Cancelling download")
            } else {
                Text("Preparing download")
            }

        return ProgressRing(
            fraction: progress ?? 0,
            label: Text(isCancelling ? "Cancelling download" : "Download progress"),
            value: value,
            diameter: containerSide,
            lineWidth: 4
        ) {
            ZStack {
                if isCancelling || progress == nil {
                    ProgressView()
                        .controlSize(.regular)
                        .tint(Theme.Colors.accent)
                } else if let progress {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(progress * 100, format: .number.precision(.fractionLength(0)))
                            .font(numberFont(for: containerSide).monospacedDigit().weight(.semibold))

                        Text(verbatim: "%")
                            .font(unitFont(for: containerSide).weight(.medium))
                            .foregroundStyle(Theme.Colors.secondary)
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                }
            }
            .frame(width: iconSide, height: iconSide)
            .accessibilityHidden(true)
        }
    }

    private func numberFont(for containerSide: CGFloat) -> Font {
        containerSide > PickItemSize.compact.plateSide ? .largeTitle : .title2
    }

    private func unitFont(for containerSide: CGFloat) -> Font {
        containerSide > PickItemSize.compact.plateSide ? .title3 : .caption
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

    private var scrollEdgeFade: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                    .frame(height: scrollMargin)
                Color.black
                LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: scrollMargin)
            }
            Color.black
                .frame(width: 16)
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
        output: [],
        error: nil,
        block: nil,
        incompleteInstallers: [], incompleteInstallerError: nil,
        onRetry: {},
        onDownload: { _ in },
        onUse: { _ in },
        onCancel: {},
        onMoveToTrash: { _ in }, onDismissIncompleteInstallerError: {},
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
        downloadingID: nil, progress: nil, output: [], error: nil, block: nil,
        incompleteInstallers: [], incompleteInstallerError: nil,
        onRetry: {}, onDownload: { _ in }, onUse: { _ in }, onCancel: {}, onMoveToTrash: { _ in },
        onDismissIncompleteInstallerError: {}, onMoveSelection: { _ in }
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
        downloadingID: "26.0|25A354|macOS Tahoe", progress: nil, output: [], error: nil, block: nil,
        incompleteInstallers: [], incompleteInstallerError: nil,
        onRetry: {}, onDownload: { _ in }, onUse: { _ in }, onCancel: {}, onMoveToTrash: { _ in },
        onDismissIncompleteInstallerError: {}, onMoveSelection: { _ in }
    )
    .padding(32)
    .frame(width: 800, height: 480)
    .preferredColorScheme(.dark)
}
