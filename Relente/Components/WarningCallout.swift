//
//  WarningCallout.swift
//  Relente
//
//  Orange box that warns about something that can't be undone.
//  It can hold extra content under the message, such as a confirmation checkbox.
//

import SwiftUI

struct WarningCallout<Content: View>: View {
    let title: LocalizedStringResource
    let message: LocalizedStringResource
    let content: Content

    init(
        title: LocalizedStringResource,
        message: LocalizedStringResource,
        @ViewBuilder content: () -> Content = { EmptyView() }
    ) {
        self.title = title
        self.message = message
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(Theme.Colors.warning)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.semibold))
                Text(message)
                    .font(Theme.Fonts.footnote)
                    .foregroundStyle(Theme.Colors.secondary)

                content
                    .padding(.top, 6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.Colors.warning.opacity(0.12))
                .strokeBorder(Theme.Colors.warning.opacity(0.35))
        }
    }
}

#Preview {
    @Previewable @State var isOn = false
    let driveName = "SanDisk Ultra"

    WarningCallout(
        title: "Everything on “\(driveName)” will be permanently erased.",
        message: "This can't be undone. Other disks won't be touched."
    ) {
        Toggle("I understand that all data on this drive will be lost.", isOn: $isOn)
            .toggleStyle(.checkbox)
    }
    .frame(width: Theme.Sizes.contentWidth)
    .padding()
}
