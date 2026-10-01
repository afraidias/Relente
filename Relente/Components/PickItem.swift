//
//  PickItem.swift
//  Relente
//
//  Finder-style selectable item: a big icon with its name underneath.
//  When selected, the icon gets a gray plate behind it and the name
//  sits in a blue capsule, just like a selected file in Finder.
//  The icon and the details under the name are any views, so the same
//  item works for installers and drives. Disabled items look dimmed.
//

import SwiftUI

struct PickItem<Icon: View, Detail: View>: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    let icon: Icon
    let detail: Detail

    @Environment(\.isEnabled) private var isEnabled
    /// Inside `.slidingSelection`, the row draws the plate and capsule; the item only marks them.
    @Environment(\.drawsSelectionInRow) private var drawsSelectionInRow

    /// Font of the name, also used by the row's white copy of it (`SlidingSelection`).
    static var nameFont: Font { .body.weight(.medium) }

    /// Gray plate behind the selected icon.
    static var plate: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(.quaternary)
    }

    /// Blue capsule behind the selected name.
    static var capsule: some View {
        Capsule()
            .fill(Theme.Colors.accent)
    }

    init(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void,
        @ViewBuilder icon: () -> Icon,
        @ViewBuilder detail: () -> Detail = { EmptyView() }
    ) {
        self.title = title
        self.isSelected = isSelected
        self.action = action
        self.icon = icon()
        self.detail = detail()
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                icon
                    .frame(width: 96, height: 96)
                    .padding(8)
                    .background { selectionShape(.plate) }

                Text(title)
                    .font(Self.nameFont)
                    .lineLimit(1)
                    // In a row, the name stays primary: the row draws it white where the capsule is.
                    .foregroundStyle(isSelected && !drawsSelectionInRow ? .white : .primary)
                    .anchorPreference(key: SelectionMarks.self, value: .bounds) { anchor in
                        drawsSelectionInRow
                            ? SelectionMarks.Value(names: [.init(title: title, anchor: anchor)]) : .init()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background { selectionShape(.capsule) }

                detail
            }
            .frame(width: 160)
            .opacity(isEnabled ? 1 : 0.45)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// The plate or capsule, drawn here or only marked for the row to draw.
    @ViewBuilder
    private func selectionShape(_ shape: SelectionShape) -> some View {
        if drawsSelectionInRow {
            Color.clear
                .anchorPreference(key: SelectionMarks.self, value: .bounds) {
                    isSelected ? SelectionMarks.Value(shapes: [shape: $0]) : .init()
                }
        } else {
            Group {
                switch shape {
                case .plate: Self.plate
                case .capsule: Self.capsule
                }
            }
            .opacity(isSelected ? 1 : 0)
        }
    }
}

#Preview {
    HStack {
        ForEach(InstallerSource.samples) { installer in
            PickItem(
                title: installer.name,
                isSelected: installer.id == InstallerSource.samples.first?.id,
                action: {}
            ) {
                FileIcon(url: installer.url, fallbackType: installer.kind.contentType)
            } detail: {
                Text(verbatim: installer.version.description)
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.secondary)
            }
        }
    }
    .padding()
}
