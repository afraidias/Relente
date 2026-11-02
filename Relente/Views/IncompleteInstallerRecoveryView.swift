//
//  IncompleteInstallerRecoveryView.swift
//  Relente
//
//  Compact entry point and review sheet for incomplete installer apps.
//  Spec: specs/011-installer-acquisition/spec.md
//

import SwiftUI
import UniformTypeIdentifiers

struct IncompleteInstallerRecoveryView: View {
    let installers: [IncompleteInstaller]
    let isDownloading: Bool
    let error: IncompleteInstallerError?
    let onMoveToTrash: (IncompleteInstaller) -> Void
    let onDismissError: () -> Void

    @State private var isShowingReview = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Theme.Colors.warning)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Incomplete installers")
                    .font(.subheadline.weight(.semibold))
                Text("Some installer apps can’t be used.")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.secondary)
            }

            Spacer(minLength: 8)

            Button("Inspect") {
                isShowingReview = true
            }
            .buttonStyle(.secondary)
            .disabled(isDownloading)
            .accessibilityHint(Text("Review incomplete installer apps and choose whether to move one to the Trash."))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.warning.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        .padding(.top, 12)
        .sheet(isPresented: $isShowingReview) {
            IncompleteInstallerReviewSheet(
                installers: installers,
                isDownloading: isDownloading,
                error: error,
                onMoveToTrash: onMoveToTrash,
                onDismissError: onDismissError
            )
            .interactiveDismissDisabled(isDownloading)
        }
    }
}

private struct IncompleteInstallerReviewSheet: View {
    let installers: [IncompleteInstaller]
    let isDownloading: Bool
    let error: IncompleteInstallerError?
    let onMoveToTrash: (IncompleteInstaller) -> Void
    let onDismissError: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var installerToTrash: IncompleteInstaller?
    @State private var isConfirmingTrash = false

    private var listHeight: CGFloat {
        min(CGFloat(max(installers.count, 1)) * 60 + CGFloat(max(installers.count - 1, 0)), 243)
    }

    private var sheetHeight: CGFloat {
        132 + listHeight
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Incomplete installers")
                        .font(.title2.weight(.semibold))
                    Text("Review items found in Applications.")
                        .font(.callout)
                        .foregroundStyle(Theme.Colors.secondary)
                }
                Spacer()
                CircularCloseButton { dismiss() }
            }

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(installers) { installer in
                        installerRow(installer)
                        if installer.id != installers.last?.id {
                            Divider().padding(.leading, 56)
                        }
                    }
                }
            }
            .scrollIndicators(.visible)
            .frame(height: listHeight)

            Spacer(minLength: 0)

            Label {
                Text("Required files are missing or empty. Relente can’t tell which process created these apps.")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.secondary)
            } icon: {
                Image(systemName: "info.circle")
                    .foregroundStyle(Theme.Colors.accent)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(width: 560, height: sheetHeight, alignment: .topLeading)
        .confirmationDialog(
            Text("Move “\(installerToTrash?.fileName ?? "")” to the Trash?"),
            isPresented: $isConfirmingTrash,
            titleVisibility: .visible
        ) {
            Button("Cancel", role: .cancel) { installerToTrash = nil }
            Button("Move to Trash", role: .destructive) {
                if let installerToTrash { onMoveToTrash(installerToTrash) }
                installerToTrash = nil
            }
        } message: {
            Text(
                "Relente will move only this incomplete installer app. Don’t continue if macOS is currently preparing it."
            )
        }
        .alert(
            "Couldn’t Move Installer",
            isPresented: Binding(
                get: { error != nil },
                set: { if !$0 { onDismissError() } }
            )
        ) {
            Button("OK", role: .cancel, action: onDismissError)
        } message: {
            if let error { Text(error.message) }
        }
    }

    private func installerRow(_ installer: IncompleteInstaller) -> some View {
        HStack(spacing: 12) {
            FileIcon(url: installer.url, fallbackType: .applicationBundle)
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: installer.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(
                    verbatim:
                        "\(installer.version.description) · \(ByteCountFormatter.string(fromByteCount: installer.sizeInBytes, countStyle: .file))"
                )
                .font(.caption)
                .foregroundStyle(Theme.Colors.secondary)
            }

            Spacer(minLength: 8)

            Button(role: .destructive) {
                installerToTrash = installer
                isConfirmingTrash = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 32, height: 32)
            }
            .environment(\.usesCircularSecondaryButton, true)
            .buttonStyle(.secondary)
            .controlSize(.small)
            .pointingCursor()
            .accessibilityLabel(Text("Move to Trash"))
            .accessibilityHint(
                Text("Moves this incomplete installer app to the Trash after confirmation.")
            )
            .disabled(isDownloading)
            .padding(.trailing, 0.5)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

#Preview {
    IncompleteInstallerRecoveryView(
        installers: [
            IncompleteInstaller(
                url: URL(filePath: "/Applications/Install macOS Big Sur.app"),
                name: "macOS Big Sur",
                version: "11.7.11",
                sizeInBytes: 40_200_000,
                snapshot: "preview"
            )
        ],
        isDownloading: false,
        error: nil,
        onMoveToTrash: { _ in },
        onDismissError: {}
    )
    .padding()
    .frame(width: 700)
}
