//
//  InstallerView.swift
//  Relente
//
//  Step 1: pick the macOS installer to copy to the USB drive.
//  Spec: specs/001-installer-screen/spec.md
//

import SwiftUI
import UniformTypeIdentifiers

struct InstallerView: View {
    let installers: [InstallerSource]
    @Binding var selectedID: InstallerSource.ID?
    /// Left and right arrows: -1 for the previous installer, +1 for the next.
    var onMoveSelection: (Int) -> Void = { _ in }
    /// A file picked with "Choose Installer…".
    var onChooseFile: (URL) -> Void = { _ in }
    /// Why the chosen file can't be used, shown as an alert.
    var error: InstallerError?
    var onDismissError: () -> Void = {}

    @State private var isChoosingFile = false

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(
                title: "Choose an Installer",
                subtitle: "Pick the version of macOS you want on the USB drive."
            )

            if installers.isEmpty {
                NoInstallerView(onDownload: downloadFromApple, onChoose: { isChoosingFile = true }, onDrop: drop)
                    .frame(maxHeight: .infinity)
                    .contentShape(.rect)
                    .dropDestination(for: URL.self) { urls, _ in
                        drop(urls)
                    }
            } else {
                // The add square counts as an item: it takes a place in the row or grid.
                PickCollection(
                    itemCount: installers.count + 1, selection: selectedID, onMoveSelection: onMoveSelection
                ) {
                    ForEach(installers) { installer in
                        InstallerItem(installer: installer, isSelected: installer.id == selectedID) {
                            selectedID = installer.id
                        }
                    }

                    AddInstallerButton(onChoose: { isChoosingFile = true }, onDrop: drop)
                }

                Button(action: downloadFromApple) {
                    Label("Download from Apple…", systemImage: "arrow.down.circle")
                }
                .buttonStyle(.secondary)
            }
        }
        .padding(.top, Theme.Sizes.headerTopPadding)
        .fileImporter(isPresented: $isChoosingFile, allowedContentTypes: Self.installerTypes) { result in
            if case .success(let url) = result {
                onChooseFile(url)
            }
        }
        .alert(
            error.map { Text($0.title) } ?? Text(verbatim: ""),
            isPresented: Binding(get: { error != nil }, set: { if !$0 { onDismissError() } }),
            presenting: error
        ) { _ in
            Button("OK", action: onDismissError)
        } message: { error in
            Text(error.message)
        }
    }

    /// Installer apps, disk images and InstallAssistant.pkg.
    private static let installerTypes: [UTType] = [
        .applicationBundle, .diskImage, InstallerSource.Kind.package.contentType,
    ]

    /// A file dropped from the Finder: the first one is read like a chosen one.
    private func drop(_ urls: [URL]) -> Bool {
        guard let url = urls.first(where: \.isFileURL) else { return false }
        onChooseFile(url)
        return true
    }

    private func downloadFromApple() {
        // TODO: open the download screen (1b), roadmap step 9.
    }
}

// MARK: - Installer item

/// One installer: its file's icon, name and "version · size". Installers older than Big Sur are
/// dimmed and say why they can't be used.
struct InstallerItem: View {
    let installer: InstallerSource
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        PickItem(title: installer.name, isSelected: isSelected, action: action) {
            FileIcon(url: installer.url, fallbackType: installer.kind.contentType)
                .sharedArtwork(.installer, isActive: isSelected)
        } detail: {
            VStack(spacing: 6) {
                Text(verbatim: "\(installer.version) · \(installer.formattedSize)")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.secondary)

                if !installer.isSupported {
                    StatusChip(
                        text: LocalizedStringResource(
                            "Not supported", comment: "Status chip under an installer older than macOS Big Sur."),
                        tone: .error)
                    Text(
                        "Needs macOS Big Sur or later",
                        comment: "Under an installer older than macOS Big Sur, which Relente can't use."
                    )
                    .font(Theme.Fonts.footnote)
                    .foregroundStyle(Theme.Colors.secondary)
                    .multilineTextAlignment(.center)
                }
            }
        }
        .help(installer.url.path(percentEncoded: false))
        .disabled(!installer.isSupported)
    }
}

// MARK: - Footer

/// "Continue", the default action, enabled once an installer is chosen.
struct InstallerFooter: View {
    let canContinue: Bool
    let onContinue: () -> Void

    var body: some View {
        AssistantFooter(for: .installer) {
            Button("Continue", action: onContinue)
                .buttonStyle(.primary)
                .keyboardShortcut(.defaultAction)
                .disabled(!canContinue)
        }
    }
}

// MARK: - Previews

#Preview {
    @Previewable @State var selectedID = InstallerSource.samples.first?.id

    InstallerView(installers: InstallerSource.samples, selectedID: $selectedID)
        .padding(32)
        .frame(width: 800, height: 480)
}

#Preview("Many installers (grid)") {
    @Previewable @State var selectedID = InstallerSource.samples.first?.id

    // Twelve items with the add square: the grid of small items, scrolling.
    let copies = (1...3).flatMap { copy in
        InstallerSource.samples.map { installer in
            InstallerSource(
                url: installer.url.deletingLastPathComponent().appending(
                    path: "\(copy) \(installer.url.lastPathComponent)"),
                name: installer.name, version: installer.version, kind: installer.kind, size: installer.size)
        }
    }
    InstallerView(
        installers: InstallerSource.samples + copies + [InstallerSource.unsupportedSample], selectedID: $selectedID
    )
    .padding(32)
    .frame(width: 800, height: 480)
}

#Preview("Not supported") {
    @Previewable @State var selectedID = InstallerSource.samples.first?.id

    InstallerView(
        installers: Array(InstallerSource.samples.prefix(2)) + [InstallerSource.unsupportedSample],
        selectedID: $selectedID
    )
    .padding(32)
    .frame(width: 800, height: 480)
}

#Preview("No installers") {
    @Previewable @State var selectedID: InstallerSource.ID?

    InstallerView(installers: [], selectedID: $selectedID)
        .padding(32)
        .frame(width: 800, height: 480)
}

#Preview("No installers · Classic (macOS 14–15)") {
    @Previewable @State var selectedID: InstallerSource.ID?

    InstallerView(installers: [], selectedID: $selectedID)
        .padding(32)
        .frame(width: 800, height: 480)
        .environment(\.usesClassicControls, true)
}

#Preview("No installers · Dark") {
    @Previewable @State var selectedID: InstallerSource.ID?

    InstallerView(installers: [], selectedID: $selectedID)
        .padding(32)
        .frame(width: 800, height: 480)
        .preferredColorScheme(.dark)
}

#Preview("Footer") {
    InstallerFooter(canContinue: true, onContinue: {})
        .frame(width: 800)
}
