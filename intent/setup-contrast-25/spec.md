# Setup screen text contrast design

- Revision: 2
- State: Accepted
- Issue: [#25](https://github.com/afraidias/Relente/issues/25)
- Intent: [Accepted revision 1](intent.md)
- Approval: Owner, 2026-11-05; revision 1: “Acepto” in response to the design acceptance request. Revision 2 incorporates the owner’s visual feedback: the initial text was too prominent and the softer variant “Me gusta más”.

## Proposed behavior and appearance

Give the setup subtitle and setup callout messages a softened primary text appearance (80% opacity) instead of the current secondary appearance, increasing distinction from the background without the visual intensity the owner rejected. Preserve the current title, subtitle wording, typography, spacing, icon, callout styling and Liquid Glass controls. The title remains the visual heading through its larger bold type. Apply the change to this setup subtitle only; other screens retain their current header styling.

Use semantic system styling rather than fixed color values so the text can adapt to light, dark and increased-contrast appearances, consistent with Apple's [color guidance](https://developer.apple.com/design/human-interface-guidelines/color). Verify the rendered result rather than assuming a system style guarantees sufficient contrast. Do not alter real system accessibility settings without the owner's consent; use supported app previews or test launch configuration to inspect appearance variants where available.

If the unfiltered audit reveals another setup-screen text contrast issue, investigate its context and use an appropriate system style while preserving the same visual hierarchy and accepted screen design. If the correction would alter shared components on other screens, affect other kinds of elements, or materially change the design, stop and review scope with the owner. Do not suppress or disable any audit finding.

## Acceptance criteria

1. The setup subtitle is legible and the title remains visually dominant in light and dark appearances, including increased contrast. Check both English and Spanish; record actual host and test conditions.
2. Run the unfiltered setup accessibility audit and document each finding. The reported subtitle finding must be absent. If a different finding cannot be addressed within the accepted scope, record it and revisit before integration; do not claim a passing audit unless it passes.
3. Existing window accessibility, VoiceOver announcements, keyboard operation, setup actions and simulated helper flow remain usable; preserve Reduce Motion and helper security. Do not change real permissions or operate on disks.
4. Other screens' styles remain unchanged. This change does not close all of #25 unless its broader scope has actually been verified and resolved.
5. Record macOS 27 results and the unverified macOS 26 limitation accepted in the intent.
