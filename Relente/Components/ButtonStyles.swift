//
//  ButtonStyles.swift
//  Relente
//
//  The app's button styles. They use Liquid Glass on macOS 26 and later,
//  and the classic bordered styles on earlier versions, so screens never
//  need their own availability checks. Liquid Glass buttons are always
//  capsules; at the regular control size macOS would draw rounded rectangles.
//

import SwiftUI

extension EnvironmentValues {
    /// Forces the classic (pre–Liquid Glass) look on any macOS version.
    /// Used by previews and, in Debug builds, by the `-classicControls` launch argument,
    /// to check how the app looks on macOS 14 and 15.
    @Entry var usesClassicControls = false
}

/// Style for the main action of a screen, such as "Continue".
struct PrimaryButtonStyle: PrimitiveButtonStyle {
    @Environment(\.usesClassicControls) private var usesClassicControls

    func makeBody(configuration: Configuration) -> some View {
        if #available(macOS 26, *), !usesClassicControls {
            Button(configuration).buttonStyle(.glassProminent).buttonBorderShape(.capsule)
        } else {
            Button(configuration).buttonStyle(.borderedProminent)
        }
    }
}

/// Style for secondary actions, such as "Download from Apple…".
struct SecondaryButtonStyle: PrimitiveButtonStyle {
    @Environment(\.usesClassicControls) private var usesClassicControls

    func makeBody(configuration: Configuration) -> some View {
        if #available(macOS 26, *), !usesClassicControls {
            Button(configuration).buttonStyle(.glass).buttonBorderShape(.capsule)
        } else {
            Button(configuration).buttonStyle(.bordered)
        }
    }
}

extension PrimitiveButtonStyle where Self == PrimaryButtonStyle {
    /// Main action: Liquid Glass prominent capsule on macOS 26+, bordered prominent before.
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension PrimitiveButtonStyle where Self == SecondaryButtonStyle {
    /// Secondary action: Liquid Glass capsule on macOS 26+, bordered before.
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}
