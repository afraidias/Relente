//
//  SlidingSelection.swift
//  Relente
//
//  In a row of `PickItem`s, the selection's gray plate and blue name capsule are one shape each
//  that slides to the newly selected item. The items only mark where they'd go; the row draws
//  them behind. Over the names, the row draws a white copy of every name, masked by the capsule,
//  so each letter turns white exactly while the capsule is under it, as in a segmented control. `matchedGeometryEffect` isn't used: each item is a button, drawn on its own, so
//  shapes in different items can't be matched. With Reduce Motion the shapes crossfade.
//  Spec: specs/006-assistant-navigation/spec.md
//

import SwiftUI

extension View {
    /// Draws the selection of the `PickItem`s inside, sliding it when `selection` changes.
    func slidingSelection(_ selection: some Hashable) -> some View {
        modifier(SlidingSelection(selection: selection))
    }
}

/// How long the selection takes to slide.
nonisolated enum SelectionMotion {
    static let duration = 0.35
}

/// Which part of the selection a mark is for.
nonisolated enum SelectionShape: Hashable, Sendable {
    case plate
    case capsule
}

nonisolated struct SelectionMarks: PreferenceKey {
    /// One item's name and where it is.
    struct Name {
        let title: String
        let anchor: Anchor<CGRect>
    }

    struct Value {
        /// Where the selected item wants its plate and capsule.
        var shapes: [SelectionShape: Anchor<CGRect>] = [:]
        /// Every item's name.
        var names: [Name] = []
    }

    static let defaultValue = Value()

    static func reduce(value: inout Value, nextValue: () -> Value) {
        let next = nextValue()
        value.shapes.merge(next.shapes) { $1 }
        value.names += next.names
    }
}

extension EnvironmentValues {
    /// Whether a row draws the selection of the items inside it.
    @Entry var drawsSelectionInRow = false
}

private struct SlidingSelection<Selection: Hashable>: ViewModifier {
    let selection: Selection

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .environment(\.drawsSelectionInRow, true)
            .backgroundPreferenceValue(SelectionMarks.self) { marks in
                GeometryReader { proxy in
                    if let mark = marks.shapes[.plate] {
                        place(PickItem<EmptyView, EmptyView>.plate, in: proxy[mark])
                    }
                    if let mark = marks.shapes[.capsule] {
                        place(PickItem<EmptyView, EmptyView>.capsule, in: proxy[mark])
                    }
                }
                .animation(animation, value: selection)
            }
            .overlayPreferenceValue(SelectionMarks.self) { marks in
                GeometryReader { proxy in
                    whiteNames(marks.names, in: proxy)
                        .mask {
                            ZStack {
                                if let mark = marks.shapes[.capsule] {
                                    place(Capsule(), in: proxy[mark])
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .animation(animation, value: selection)
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
    }

    private var animation: Animation {
        reduceMotion ? .easeInOut(duration: SelectionMotion.duration) : .snappy(duration: SelectionMotion.duration)
    }

    /// Every name in white, exactly over the item's own name.
    private func whiteNames(_ names: [SelectionMarks.Name], in proxy: GeometryProxy) -> some View {
        ZStack {
            ForEach(names.indices, id: \.self) { index in
                let rect = proxy[names[index].anchor]
                Text(verbatim: names[index].title)
                    .font(PickItem<EmptyView, EmptyView>.nameFont)
                    .lineLimit(1)
                    .foregroundStyle(.white)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func place(_ shape: some View, in rect: CGRect) -> some View {
        let placed =
            shape
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
        if reduceMotion {
            // A new shape for each selection, so it fades instead of moving.
            placed
                .id(selection)
                .transition(.opacity)
        } else {
            placed
        }
    }
}

#Preview {
    @Previewable @State var selectedID = InstallerSource.samples.first?.id

    // Click an item: the plate and the capsule slide to it.
    HStack(spacing: 24) {
        ForEach(InstallerSource.samples) { installer in
            PickItem(title: installer.name, isSelected: installer.id == selectedID) {
                selectedID = installer.id
            } icon: {
                FileIcon(url: installer.url, fallbackType: installer.kind.contentType)
            }
        }
    }
    .slidingSelection(selectedID)
    .padding()
}
