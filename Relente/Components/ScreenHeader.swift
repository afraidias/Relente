//
//  ScreenHeader.swift
//  Relente
//
//  Centered title and subtitle shown at the top of every assistant screen.
//

import SwiftUI

struct ScreenHeader: View {
    let title: LocalizedStringResource
    /// A `Text` so parts of it can be styled, e.g. an error's reason in the primary color.
    let subtitle: Text

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
            subtitle
                .subtitleStyle()
        }
        .multilineTextAlignment(.center)
    }
}

#Preview {
    ScreenHeader(
        title: "Choose an Installer",
        subtitle: "Pick the version of macOS you want on the USB drive."
    )
    .padding()
}
