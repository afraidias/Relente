//
//  PickItem.swift
//  Relente
//
//  Finder-style selectable item: a big icon with its name underneath.
//  When selected, the icon gets a gray plate behind it and the name
//  sits in a blue capsule, just like a selected file in Finder.
//  The icon is any view, so the same item works for installers and drives.
//

import SwiftUI

struct PickItem<Icon: View>: View {
    let title: String
    let subtitle: String?
    let isSelected: Bool
    let action: () -> Void
    let icon: Icon

    init(
        title: String,
        subtitle: String? = nil,
        isSelected: Bool,
        action: @escaping () -> Void,
        @ViewBuilder icon: () -> Icon
    ) {
        self.title = title
        self.subtitle = subtitle
        self.isSelected = isSelected
        self.action = action
        self.icon = icon()
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                icon
                    .frame(width: 96, height: 96)
                    .padding(8)
                    .background {
                        // Gray plate behind the selected icon.
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(.quaternary)
                            .opacity(isSelected ? 1 : 0)
                    }

                Text(title)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .foregroundStyle(isSelected ? .white : .primary)
                    .background {
                        Capsule()
                            .fill(Theme.Colors.accent)
                            .opacity(isSelected ? 1 : 0)
                    }

                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Theme.Colors.secondary)
                }
            }
            .frame(width: 160)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    HStack {
        ForEach(InstallerSource.samples) { installer in
            PickItem(
                title: installer.name,
                subtitle: installer.version,
                isSelected: installer.id == InstallerSource.samples.first?.id,
                action: {}
            ) {
                FileIcon(url: installer.url, fallbackType: installer.kind.contentType)
            }
        }
    }
    .padding()
}
