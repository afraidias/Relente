//
//  CancelDownloadButton.swift
//  Relente
//
//  Shared compact cancel control for a download card and its details sheet.
//

import SwiftUI

struct CancelDownloadButton: View {
    let isDisabled: Bool
    let action: () -> Void
    let showsLabel: Bool

    init(isDisabled: Bool = false, showsLabel: Bool = false, action: @escaping () -> Void) {
        self.isDisabled = isDisabled
        self.showsLabel = showsLabel
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 11, weight: .semibold))
                if showsLabel { Text("Cancel Download") }
            }
            .frame(minWidth: showsLabel ? nil : 24, minHeight: 24)
        }
        .environment(\.usesCircularSecondaryButton, !showsLabel)
        .buttonStyle(.secondary)
        .controlSize(.small)
        .pointingCursor()
        .accessibilityLabel("Cancel Download")
        .accessibilityHint("Stops this download.")
        .disabled(isDisabled)
    }
}

#Preview {
    CancelDownloadButton(action: {})
        .padding()
}
