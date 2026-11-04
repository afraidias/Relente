//
//  PermissionsView.swift
//  Relente
//
//  Guides helper setup and provides access to disk privacy settings. The assistant
//  refreshes the helper status when the app becomes active and periodically.

//

import AppKit
import SwiftUI

struct PermissionsView: View {
    let helperStatus: HelperStatus
    var isInstalling = false
    var helperTurnedOff = false
    var onOpenFullDiskAccessSettings: () -> Void = {}

    var body: some View {
        VStack(spacing: 12) {
            ScreenHeader(title: "Set Up Relente", subtitle: "Prepare the system helper to create your installer.")
            Spacer(minLength: 4)
            HeroArtwork(size: 104, haloColor: heroColor) {
                Image(nsImage: NSApplication.shared.applicationIconImage).resizable()
            } badge: {
                if !isInstalling {
                    switch helperStatus {
                    case .ready: StatusBadge(kind: .success)
                    case .failed: StatusBadge(kind: .failure)
                    case .notInstalled, .needsApproval: EmptyView()
                    }
                }
            }
            Spacer(minLength: 20)
            statusCallout
                .frame(width: Theme.Sizes.contentWidth)
            Callout(
                tone: .secondary(systemImage: "externaldrive"),
                title: "Drive access",
                message: "You may need to allow Relente in Full Disk Access to create the installer."
            ) {
                Button("Open Full Disk Access Settings…", action: onOpenFullDiskAccessSettings)
                    .buttonStyle(.secondary)
            }
            .frame(width: Theme.Sizes.contentWidth)
            Spacer(minLength: 4)
        }
        .padding(.top, Theme.Sizes.headerTopPadding)
        .onChange(of: isInstalling) { _, installing in
            if installing {
                AccessibilityNotification.Announcement(String(localized: "Installing helper…")).post()
            }
        }
        .onChange(of: helperStatus) { _, status in
            if let announcement = Self.announcement(for: status) {
                AccessibilityNotification.Announcement(String(localized: announcement)).post()
            }
        }
    }

    private var heroColor: Color {
        if isInstalling { return Theme.Colors.accent }
        switch helperStatus {
        case .ready: return Theme.Colors.success
        case .failed: return Theme.Colors.danger
        case .notInstalled, .needsApproval: return Theme.Colors.accent
        }
    }

    @ViewBuilder private var statusCallout: some View {
        if isInstalling {
            Callout(
                tone: .info(systemImage: "clock"), title: "Installing helper…",
                message: "Please wait while macOS registers the helper.")
        } else {
            switch helperStatus {
            case .notInstalled where helperTurnedOff:
                Callout(
                    tone: .info(systemImage: "info.circle"), title: "Helper disabled",
                    message: "Your selections are preserved. Install the helper to continue.")
            case .notInstalled:
                Callout(
                    tone: .info(systemImage: "info.circle"), title: "Helper not installed",
                    message: "Install the helper to prepare your USB drive.")
            case .needsApproval where helperTurnedOff:
                Callout(
                    tone: .info(systemImage: "clock"), title: "Helper disabled",
                    message:
                        "Your selections are preserved. Turn on Relente under App Background Activity in System Settings to continue."
                )
            case .needsApproval:
                Callout(
                    tone: .info(systemImage: "clock"), title: "Waiting for activation",
                    message:
                        "In the window that opens, find Relente under App Background Activity and turn it on. Then return here."
                )
            case .ready:
                Callout(
                    tone: .success, title: "Helper enabled",
                    message: "You can continue and choose an installer and a drive.")
            case .failed:
                Callout(
                    tone: .failure, title: "Couldn’t install the helper",
                    message: "Try again. If the problem continues, make sure Relente is in your Applications folder.")
            }
        }
    }

    /// What VoiceOver says when the helper's status changes.
    private static func announcement(for status: HelperStatus) -> LocalizedStringResource? {
        switch status {
        case .notInstalled: nil
        case .needsApproval:
            LocalizedStringResource(
                "Turn on Relente in System Settings to finish installing the system helper.",
                comment: "VoiceOver, when the helper waits for the user's approval in System Settings.")
        case .ready:
            LocalizedStringResource("System helper ready.", comment: "VoiceOver, when the helper is turned on.")
        case .failed:
            LocalizedStringResource(
                "The system helper couldn't be installed.", comment: "VoiceOver, when registering the helper failed.")
        }
    }
}

// MARK: - Footer

/// One button, the default action: always the next thing to do.
struct PermissionsFooter: View {
    let status: HelperStatus
    var isInstalling = false
    let onInstall: () -> Void
    let onOpenSettings: () -> Void
    let onContinue: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        AssistantFooter(for: .permissions) {
            Group {
                switch status {
                case .notInstalled:
                    helperButton(title: "Install Helper", progressTitle: "Installing Helper…")
                case .needsApproval:
                    Button("Open System Settings…", action: onOpenSettings)
                case .ready:
                    Button("Continue", action: onContinue)
                case .failed:
                    helperButton(title: "Try Again", progressTitle: "Trying Again…")
                }
            }
            .buttonStyle(.primary)
            .keyboardShortcut(.defaultAction)
        }
    }

    private func helperButton(title: LocalizedStringResource, progressTitle: LocalizedStringResource) -> some View {
        Button(action: onInstall) {
            if isInstalling {
                HStack(spacing: 8) {
                    if !reduceMotion {
                        ProgressView().controlSize(.small)
                    }
                    Text(progressTitle)
                }
            } else {
                Text(title)
            }
        }
        .disabled(isInstalling)
    }
}

// MARK: - Previews

/// The whole screen as it will appear in the window: content and footer.
private struct PermissionsScreenPreview: View {
    let status: HelperStatus

    var body: some View {
        VStack(spacing: 0) {
            PermissionsView(helperStatus: status)
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
                .frame(maxHeight: .infinity)
            PermissionsFooter(status: status, onInstall: {}, onOpenSettings: {}, onContinue: {})
        }
        .frame(width: Theme.Sizes.window.width, height: Theme.Sizes.window.height)
    }
}

#Preview("Not installed") {
    PermissionsScreenPreview(status: .notInstalled)
}

#Preview("Needs approval") {
    PermissionsScreenPreview(status: .needsApproval)
}

#Preview("Ready") {
    PermissionsScreenPreview(status: .ready)
}

#Preview("Failed · Without Touch ID") {
    PermissionsScreenPreview(status: .failed(.registrationFailed(reason: "Operation not permitted")))
}

#Preview("Needs approval · Dark") {
    PermissionsScreenPreview(status: .needsApproval)
        .preferredColorScheme(.dark)
}

#Preview("Classic (macOS 14–15)") {
    PermissionsScreenPreview(status: .needsApproval)
        .environment(\.usesClassicControls, true)
}
