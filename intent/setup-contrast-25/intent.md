# Improve contrast on the setup screen

- Revision: 1
- State: Accepted
- Issue: [#25](https://github.com/afraidias/Relente/issues/25)
- Related investigation: [#53](https://github.com/afraidias/Relente/issues/53)
- Approval: Owner, 2026-11-05, revision 1; conversation: “acepto” in response to the explicit intent acceptance request.

## Problem and evidence

On macOS 27.2 the unfiltered accessibility audit reports `Contrast nearly passed` for the setup subtitle after the window's unnamed group is identified. The subtitle uses the shared `ScreenHeader` and its secondary text style. Other findings may become visible after this one is addressed; the audit result alone does not establish that the subtitle is the only contrast issue.

## Audience and outcome

People using the setup screen should be able to read its guidance comfortably in light and dark appearances, including with Increase Contrast enabled. Preserve its visual hierarchy and familiar native appearance.

## Scope and constraints

Investigate and address verified text-contrast problems in the setup screen, beginning with the reported subtitle. Select a targeted solution that does not unintentionally alter other assistant screens, even though the existing header and styles are shared. Do not suppress the accessibility audit or weaken tests. Preserve English and Spanish, VoiceOver, keyboard navigation, Reduce Motion, existing actions and helper security. Use simulated data and do not change real permissions or operate on disks.

## Non-goals and dependencies

This is not an app-wide redesign or a claim that every problem in #25 has been resolved. Other screens remain separate work. The window-label change is tracked in [#53](https://github.com/afraidias/Relente/issues/53). The owner accepted proceeding with macOS 27 testing when macOS 26 is unavailable; direct macOS 26 results remain unverified. Merge and release are separately authorized.

## Success measures and open questions

- Verify the reported subtitle contrast and any additional setup-screen findings using the full unfiltered audit, in both appearances and languages where feasible, with actual outcomes recorded.
- Manually assess visual hierarchy and legibility, including Increase Contrast; if the audit reports a finding that cannot responsibly be resolved within setup-screen scope, record it and revisit scope rather than suppress it.
- Determine whether a targeted native text style meets contrast and visual needs without changing shared screens. A design and implementation plan require separate owner acceptance before code changes.
