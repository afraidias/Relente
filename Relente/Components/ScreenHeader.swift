//
//  ScreenHeader.swift
//  Relente
//
//  Centered title and subtitle shown at the top of every assistant screen.
//

import SwiftUI

struct ScreenHeader: View {
    let title: LocalizedStringResource
    let subtitle: LocalizedStringResource

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .titleStyle()
            Text(subtitle)
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
