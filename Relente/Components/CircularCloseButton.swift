//
//  CircularCloseButton.swift
//  Relente
//
//  Shared circular close control for modal sheets.
//

import SwiftUI

struct CircularCloseButton: View {
    let isDisabled: Bool
    let action: () -> Void

    init(isDisabled: Bool = false, action: @escaping () -> Void) {
        self.isDisabled = isDisabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 32, height: 32)
        }
        .environment(\.usesCircularSecondaryButton, true)
        .buttonStyle(.secondary)
        .controlSize(.small)
        .pointingCursor()
        .accessibilityLabel("Close")
        .disabled(isDisabled)
    }
}

#Preview {
    CircularCloseButton(action: {})
        .padding()
}
