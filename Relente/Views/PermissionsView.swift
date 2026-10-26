//
//  PermissionsView.swift
//  Relente
//
//  Permissions: installs the system helper, shown before Installer only while the helper isn't
//  ready. Laid out like the other screens (option E of the canvas "Relente · Permissions"): the
//  header, the app icon as the hero with a halo and badge for the helper's status, the waiting
//  indicator while macOS waits for the user, a callout about the authorization each erase asks
//  for, and one footer button that is always the next thing to do. The assistant reads the
//  helper's status again every 2 s and when the app becomes active, so the screen follows it.
//  Spec: specs/008-system-helper/spec.md
//

import AppKit
import SwiftUI

struct PermissionsView: View {
    let helperStatus: HelperStatus
    let authenticationMethod: AuthenticationMethod

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(
                title: "Set Up Relente",
                subtitle: "Relente needs a small system helper to erase drives. You only do this once."
            )

            Spacer(minLength: 8)

            PermissionsHero(status: helperStatus)

            Spacer(minLength: 8)

            AuthorizationCallout(method: authenticationMethod)
                .frame(width: Theme.Sizes.contentWidth)

            Spacer(minLength: 8)
        }
        .padding(.top, Theme.Sizes.headerTopPadding)
        .onChange(of: helperStatus) { _, status in
            if let announcement = Self.announcement(for: status) {
                AccessibilityNotification.Announcement(String(localized: announcement)).post()
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

// MARK: - Hero

/// The app icon in a halo colored by the helper's status, with a badge once it's ready or failed,
/// like the drive on Done and Error; below it, where the helper stands.
struct PermissionsHero: View {
    let status: HelperStatus

    var body: some View {
        VStack(spacing: 12) {
            HeroArtwork(size: 104, haloColor: haloColor) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
            } badge: {
                switch status {
                case .ready:
                    StatusBadge(kind: .success)
                case .failed:
                    StatusBadge(kind: .failure)
                case .notInstalled, .needsApproval:
                    EmptyView()
                }
            }

            Text(statusLine)
                .font(.body.weight(.semibold))
                .multilineTextAlignment(.center)

            // One line under it, whose space is always kept so the hero never moves when the
            // status changes: the waiting indicator, macOS's reason for a failure, or nothing.
            ZStack {
                WaitingIndicator(text: "Waiting for approval…")
                    .hidden()
                switch status {
                case .needsApproval:
                    WaitingIndicator(text: "Waiting for approval…")
                case .failed(let error):
                    Text(error.message)
                        .font(Theme.Fonts.footnote)
                        .foregroundStyle(Theme.Colors.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                case .notInstalled, .ready:
                    EmptyView()
                }
            }
        }
    }

    private var haloColor: Color {
        switch status {
        case .notInstalled, .needsApproval: Theme.Colors.accent
        case .ready: Theme.Colors.success
        case .failed: Theme.Colors.danger
        }
    }

    private var statusLine: LocalizedStringResource {
        switch status {
        case .notInstalled:
            LocalizedStringResource(
                "The system helper isn't installed.", comment: "Permissions, under the hero: before installing.")
        case .needsApproval:
            LocalizedStringResource(
                "Turn on Relente in System Settings › General › Login Items.",
                comment: "Permissions, under the hero: macOS waits for the user to turn the helper on.")
        case .ready:
            LocalizedStringResource("System helper ready.", comment: "VoiceOver, when the helper is turned on.")
        case .failed:
            LocalizedStringResource(
                "The system helper couldn't be installed.", comment: "VoiceOver, when registering the helper failed.")
        }
    }
}

// MARK: - Callout

/// What each erase will ask for through the current Authorization Services flow.
struct AuthorizationCallout: View {
    let method: AuthenticationMethod

    var body: some View {
        Callout(
            tone: .info(systemImage: method.symbolName),
            title: LocalizedStringResource(
                "Each erase asks for your permission", comment: "Permissions: title of the callout about authorizing."),
            message: message)
    }

    private var message: LocalizedStringResource {
        switch method {
        case .touchID:
            "With Touch ID or your administrator password, every time. Relente never erases a drive without asking you first."
        case .password:
            "With your administrator password, every time. Relente never erases a drive without asking you first."
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

    var body: some View {
        AssistantFooter(for: .permissions) {
            Group {
                switch status {
                case .notInstalled:
                    helperButton(title: "Install Helper", progressTitle: "Installing Helper…")
                case .needsApproval:
                    Button("Open Settings…", action: onOpenSettings)
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
                    ProgressView().controlSize(.small)
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
    var method = AuthenticationMethod.password

    var body: some View {
        VStack(spacing: 0) {
            PermissionsView(helperStatus: status, authenticationMethod: method)
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
    PermissionsScreenPreview(
        status: .failed(.registrationFailed(reason: "Operation not permitted")), method: .password)
}

#Preview("Needs approval · Dark") {
    PermissionsScreenPreview(status: .needsApproval)
        .preferredColorScheme(.dark)
}

#Preview("Classic (macOS 14–15)") {
    PermissionsScreenPreview(status: .needsApproval)
        .environment(\.usesClassicControls, true)
}
