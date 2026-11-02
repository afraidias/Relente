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

    init(isDisabled: Bool = false, action: @escaping () -> Void) {
        self.isDisabled = isDisabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: "stop.fill")
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 24, height: 24)
        }
        .environment(\.usesCircularSecondaryButton, true)
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
