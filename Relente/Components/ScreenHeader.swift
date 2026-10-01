//
//  ScreenHeader.swift
//  Relente
//
//  Centered title and subtitle shown at the top of every assistant screen. Inside the
//  assistant, VoiceOver moves to the title when the screen appears (spec 006).
//

import SwiftUI

struct ScreenHeader: View {
    let title: LocalizedStringResource
    /// A `Text` so parts of it can be styled, e.g. an error's reason in the primary color.
    let subtitle: Text

    @Environment(\.assistantScreen) private var screen
    @AccessibilityFocusState private var isTitleFocused: Bool

    init(title: LocalizedStringResource, subtitle: LocalizedStringResource) {
        self.title = title
        self.subtitle = Text(subtitle)
    }

    init(title: LocalizedStringResource, subtitle: Text) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .titleStyle()
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($isTitleFocused)
            subtitle
                .subtitleStyle()
        }
        .multilineTextAlignment(.center)
        .onAppear {
            // Only in the assistant: previews have no screen changes to announce.
            if screen != nil {
                isTitleFocused = true
            }
        }
    }
}

#Preview {
    ScreenHeader(
        title: "Choose an Installer",
        subtitle: "Pick the version of macOS you want on the USB drive."
    )
    .padding()
}
