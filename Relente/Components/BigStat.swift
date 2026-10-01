//
//  BigStat.swift
//  Relente
//
//  A big figure with a small uppercase label on top and an optional caption
//  under it, such as "WILL BE ERASED · 9.8 GB".
//

import SwiftUI

struct BigStat: View {
    let label: LocalizedStringResource
    /// The figure, already formatted, e.g. "9.8 GB". A `Text` so it can also be a localized word.
    let value: Text
    /// Optional line under the figure, e.g. the installer's name. A `Text` so it can be
    /// localized, e.g. "of 16.8 GB".
    var caption: Text?
    /// Color of the figure.
    var tint: Color = .primary
    /// For a figure that changes while shown: its value, so its digits roll up or down.
    var rollingValue: Double?

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .sectionLabelStyle()

            figure

            if let caption {
                caption
                    .font(Theme.Fonts.footnote)
                    .foregroundStyle(Theme.Colors.secondary)
                    .truncationMode(.middle)
            }
        }
        .lineLimit(1)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var figure: some View {
        let styled = value.font(Theme.Fonts.figure).foregroundStyle(tint)
        if let rollingValue {
            styled.rollingFigure(rollingValue)
        } else {
            styled
        }
    }
}

#Preview {
    HStack(alignment: .top, spacing: 32) {
        BigStat(label: "WILL BE ERASED", value: Text(verbatim: "9.8 GB"), tint: Theme.Colors.warning)
        BigStat(label: "WILL BE INSTALLED", value: Text(verbatim: "16.8 GB"), caption: Text(verbatim: "macOS Tahoe"))
        BigStat(label: "FREE AFTERWARDS", value: Text(verbatim: "15.2 GB"))
    }
    .padding()
}
