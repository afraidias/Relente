//
//  PickLayout.swift
//  Relente
//
//  How the installers or drives to pick from are laid out: up to 4 large items in a row, which is
//  all that fits in the window; from 5, a grid of smaller items that scrolls when it doesn't fit.
//  Spec: specs/007-real-detection/spec.md ("Many installers or drives")
//

import Foundation

nonisolated enum PickLayout: Equatable, Sendable {
    /// One row of large items.
    case row
    /// A grid of small items, `columns` wide.
    case grid

    /// Most items that fit in a row of large ones.
    static let maxRowItems = 4
    /// Columns of the grid.
    static let columns = 5

    /// The layout for this many items. On the Installer screen the add square counts as one.
    init(itemCount: Int) {
        self = itemCount <= Self.maxRowItems ? .row : .grid
    }

    var itemSize: PickItemSize {
        switch self {
        case .row: .regular
        case .grid: .compact
        }
    }

    /// How far Up and Down move the selection: a grid row; `nil` in a row, where they do nothing.
    var rowLength: Int? {
        switch self {
        case .row: nil
        case .grid: Self.columns
        }
    }
}
