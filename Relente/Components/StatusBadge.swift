//
//  StatusBadge.swift
//  Relente
//
//  The badge that says how something ended: a green check or a red cross. An opaque circle with
//  a white symbol, inside a ring that sets it apart from the artwork under it: white in light
//  mode, the window's background in dark mode. Done's installer icon (spec 005), Error (spec 004)
//  and Permissions (spec 008) use it, so it looks the same everywhere.
//

import AppKit
import SwiftUI

struct StatusBadge: View {
    enum Kind {
        case success
        case failure

        var color: Color {
            switch self {
            case .success: Theme.Colors.success
            case .failure: Theme.Colors.danger
            }
        }

        var systemImage: String {
            switch self {
            case .success: "checkmark"
            case .failure: "xmark"
            }
        }
    }

    let kind: Kind

    @Environment(\.colorScheme) private var colorScheme

    /// White in light mode; in dark mode white would look like a sticker, so the window's own
    /// background color makes the cut instead.
    private var ringColor: Color {
        colorScheme == .dark ? Color(nsColor: .windowBackgroundColor) : .white
    }

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            // The ring is about a twelfth of the badge, never thinner than 1.5 pt.
            let ring = max(side / 12, 1.5)
            ZStack {
                Circle()
                    .fill(ringColor)
                Circle()
                    .fill(kind.color)
                    .padding(ring)
                Image(systemName: kind.systemImage)
                    .font(.system(size: side * 0.42, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: 20) {
        StatusBadge(kind: .success)
            .frame(width: 44, height: 44)
        StatusBadge(kind: .failure)
            .frame(width: 44, height: 44)
        StatusBadge(kind: .success)
            .frame(width: 20, height: 20)
    }
    .padding()
    .background(.gray)
}
