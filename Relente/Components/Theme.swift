//
//  Theme.swift
//  Relente
//
//  Design system: colors, typography and sizes.
//  Every screen pulls its styling from here so they stay consistent.
//

import SwiftUI

enum Theme {

    // MARK: - Colors

    /// System colors, so dark mode works for free.
    enum Colors {
        static let accent: Color = .accentColor
        static let success: Color = .green
        static let warning: Color = .orange
        static let danger: Color = .red
        static let secondary: Color = .secondary
    }

    // MARK: - Typography

    /// System text styles (not fixed sizes), so line height adapts to each
    /// language's script. Sizes are the macOS defaults.
    enum Fonts {
        /// Screen title (22 pt, bold).
        static let title: Font = .title.bold()
        /// Text under the title (13 pt); shown in gray.
        static let subtitle: Font = .body
        /// Section labels such as "WILL BE ERASED" (11 pt, semibold).
        static let sectionLabel: Font = .subheadline.weight(.semibold)
        /// Small secondary text, such as the step indicator (12 pt).
        static let footnote: Font = .callout
        /// Big figures such as "9.8 GB" (22 pt, semibold, digits of equal width).
        static let figure: Font = .title.weight(.semibold).monospacedDigit()
    }

    // MARK: - Sizes

    enum Sizes {
        /// Size of the assistant window.
        static let window = CGSize(width: 800, height: 560)
        /// Width of the column that holds figures, bars, callouts and cards under the hero.
        /// The same on every screen, so they line up from one screen to the next.
        static let contentWidth: CGFloat = 640
        /// Space above each screen's header. The window has no title bar, so this keeps the
        /// title clear of the window buttons (close, minimize, zoom) in the top corner.
        static let headerTopPadding: CGFloat = 28
    }
}

// MARK: - Text style shortcuts

extension View {
    /// Title style: 24 pt bold.
    func titleStyle() -> some View {
        font(Theme.Fonts.title)
    }

    /// Subtitle style: 13 pt gray.
    func subtitleStyle() -> some View {
        font(Theme.Fonts.subtitle)
            .foregroundStyle(Theme.Colors.secondary)
    }

    /// Section label style: 11 pt semibold gray.
    func sectionLabelStyle() -> some View {
        font(Theme.Fonts.sectionLabel)
            .foregroundStyle(Theme.Colors.secondary)
    }
}
