//
//  EmptyStateView.swift
//  Relente
//
//  What a screen shows while it waits for something that isn't there yet: an installer on the
//  Installer screen, a drive on the USB Drive screen. Both look and behave the same: a gray
//  symbol, a title, a description, optional actions and a "Waiting for…" indicator.
//  Spec: specs/007-real-detection/spec.md
//

import SwiftUI

struct EmptyStateView<Actions: View>: View {
    let title: LocalizedStringResource
    let systemImage: String
    let description: Text
    /// e.g. "Waiting for a drive…".
    let waitingText: LocalizedStringResource
    @ViewBuilder let actions: Actions

    var body: some View {
        ContentUnavailableView {
            Label {
                Text(title)
            } icon: {
                Image(systemName: systemImage)
            }
        } description: {
            description
        } actions: {
            VStack(spacing: 16) {
                actions
                WaitingIndicator(text: waitingText)
            }
        }
    }
}

extension EmptyStateView where Actions == EmptyView {
    init(title: LocalizedStringResource, systemImage: String, description: Text, waitingText: LocalizedStringResource) {
        self.init(
            title: title, systemImage: systemImage, description: description, waitingText: waitingText,
            actions: { EmptyView() })
    }
}

// MARK: - Waiting indicator

/// A small spinner and what the screen is waiting for.
struct WaitingIndicator: View {
    let text: LocalizedStringResource

    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text(text)
        }
        .foregroundStyle(Theme.Colors.secondary)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    EmptyStateView(
        title: "No USB Drive Connected", systemImage: "externaldrive.badge.plus",
        description: Text(verbatim: "Use a USB drive or SD card with at least 17.8 GB."),
        waitingText: "Waiting for a drive…"
    )
    .frame(width: 800, height: 400)
}
