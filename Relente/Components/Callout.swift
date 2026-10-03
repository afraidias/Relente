//
//  Callout.swift
//  Relente
//
//  A box at the content width with a symbol, a title and a message: orange to warn about
//  something that can't be undone (Review), blue to inform (Permissions, spec 008). It can hold
//  extra content under the message, such as a confirmation checkbox.
//

import SwiftUI

struct Callout<Content: View>: View {

    enum Tone {
        /// Orange, with a warning triangle.
        case warning
        /// Blue, for information; it shows `systemImage`.
        case info(systemImage: String)

        var color: Color {
            switch self {
            case .warning: Theme.Colors.warning
            case .info: Theme.Colors.accent
            }
        }

        var systemImage: String {
            switch self {
            case .warning: "exclamationmark.triangle.fill"
            case .info(let systemImage): systemImage
            }
        }
    }

    let tone: Tone
    let title: LocalizedStringResource
    let message: LocalizedStringResource
    let content: Content

    init(
        tone: Tone = .warning,
        title: LocalizedStringResource,
        message: LocalizedStringResource,
        @ViewBuilder content: () -> Content
    ) {
        self.tone = tone
        self.title = title
        self.message = message
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: tone.systemImage)
                .font(.title2)
                .foregroundStyle(tone.color)
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
                .fill(tone.color.opacity(0.12))
                .strokeBorder(tone.color.opacity(0.35))
        }
    }
}

extension Callout where Content == EmptyView {
    /// A callout with only its title and message.
    init(tone: Tone = .warning, title: LocalizedStringResource, message: LocalizedStringResource) {
        self.init(tone: tone, title: title, message: message) { EmptyView() }
    }
}

#Preview("Warning") {
    @Previewable @State var isOn = false
    let driveName = "SanDisk Ultra"

    Callout(
        title: "Everything on “\(driveName)” will be permanently erased.",
        message: "This can't be undone. Other disks won't be touched."
    ) {
        Toggle("I understand that all data on this drive will be lost.", isOn: $isOn)
            .toggleStyle(.checkbox)
    }
    .frame(width: Theme.Sizes.contentWidth)
    .padding()
}

#Preview("Info") {
    Callout(
        tone: .info(systemImage: "touchid"), title: "Each erase asks for your permission",
        message:
            "With Touch ID or your administrator password, every time. Relente never erases a drive without asking you first."
    )
    .frame(width: Theme.Sizes.contentWidth)
    .padding()
}
