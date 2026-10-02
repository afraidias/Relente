//
//  PickItemSize.swift
//  Relente
//
//  The two sizes of a `PickItem`: large in a row, smaller in a grid (`PickLayout`). Items read it
//  from the environment, so the screens don't pass it around.
//  Spec: specs/007-real-detection/spec.md ("Many installers or drives")
//

import SwiftUI

nonisolated enum PickItemSize: Equatable, Sendable {
    case regular
    case compact

    /// Width of the whole item.
    var width: CGFloat {
        switch self {
        case .regular: 160
        case .compact: 128
        }
    }

    /// Side of the icon, without the plate around it.
    var iconSide: CGFloat {
        switch self {
        case .regular: 96
        case .compact: 64
        }
    }

    /// Margin between the icon and the plate behind it.
    static let platePadding: CGFloat = 8

    /// Side of the plate: what the icon takes in the item.
    var plateSide: CGFloat {
        iconSide + 2 * Self.platePadding
    }
}

extension EnvironmentValues {
    /// The size of the `PickItem`s inside.
    @Entry var pickItemSize = PickItemSize.regular
}
