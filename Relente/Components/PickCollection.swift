//
//  PickCollection.swift
//  Relente
//
//  The installers or drives to pick from, laid out by `PickLayout`: a row of large items, or a grid
//  of small ones that scrolls when it doesn't fit. The selection slides between the items and
//  follows the arrow keys in both.
//  Spec: specs/007-real-detection/spec.md ("Many installers or drives")
//

import SwiftUI

struct PickCollection<ID: Hashable, Content: View>: View {
    /// How many items `content` makes, the add square included.
    let itemCount: Int
    /// The selected item's id, as given to its `ForEach`.
    let selection: ID?
    /// Arrow keys: -1 or +1 for Left and Right; a grid row for Up and Down.
    let onMoveSelection: (Int) -> Void
    @ViewBuilder let content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Space between grid items.
    private static var gridSpacing: CGFloat { 14 }
    /// Room above and below the items inside the scroll view: as tall as the fade, so items
    /// scrolled to the top or bottom aren't faded.
    private static var scrollMargin: CGFloat { 16 }
    /// Width kept clear of the fade along the trailing edge, for the scroller.
    private static var scrollerWidth: CGFloat { 16 }

    private var layout: PickLayout {
        PickLayout(itemCount: itemCount)
    }

    var body: some View {
        switch layout {
        case .row:
            // Top-aligned, so every name sits on the same line whatever the details under it.
            HStack(alignment: .top, spacing: 24) {
                content
            }
            .selectsWithArrowKeys(rowLength: nil, onMoveSelection)
            .slidingSelection(selection)
            .frame(maxHeight: .infinity)
        case .grid:
            GeometryReader { proxy in
                ScrollViewReader { scroller in
                    ScrollView(.vertical) {
                        grid
                            // Centered in the space when it fits; from the top when it scrolls.
                            .frame(maxWidth: .infinity, minHeight: proxy.size.height - 2 * Self.scrollMargin)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    // Items fade out at the top and bottom edges instead of being cut.
                    .mask { edgeFade }
                    // Room between the items and the header or the button below when it scrolls.
                    .contentMargins(.vertical, Self.scrollMargin, for: .scrollContent)
                    .onAppear { scrollToSelection(scroller, animated: false) }
                    .onChange(of: selection) { scrollToSelection(scroller, animated: true) }
                }
            }
            // Clear of the header above and of whatever is below (e.g. "Download from Apple…").
            .padding(.top, 24)
            .padding(.bottom, 20)
        }
    }

    /// Keeps the selected item in view, e.g. when the arrow keys move past the visible rows.
    private func scrollToSelection(_ scroller: ScrollViewProxy, animated: Bool) {
        guard let selection else { return }
        withAnimation(animated && !reduceMotion ? .default : nil) { scroller.scrollTo(selection) }
    }

    /// Opaque in the middle, fading to clear over `scrollMargin` at the top and bottom, except a
    /// strip along the trailing edge, where the scroller is: it never fades.
    private var edgeFade: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                    .frame(height: Self.scrollMargin)
                Color.black
                LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: Self.scrollMargin)
            }
            Color.black
                .frame(width: Self.scrollerWidth)
        }
    }

    private var grid: some View {
        LazyVGrid(
            columns: Array(
                repeating: GridItem(.fixed(PickItemSize.compact.width), spacing: Self.gridSpacing, alignment: .top),
                count: PickLayout.columns),
            spacing: 18
        ) {
            content
        }
        .environment(\.pickItemSize, .compact)
        .environment(\.marksArtworkOnlyWhileChangingScreen, true)
        .selectsWithArrowKeys(rowLength: layout.rowLength, onMoveSelection)
        .slidingSelection(selection)
    }
}
