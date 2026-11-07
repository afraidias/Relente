# Make the setup window accessible to audit and assistive technology

- Revision: 1
- State: Accepted
- Issue: [#53](https://github.com/afraidias/Relente/issues/53)
- Approval: Owner, 2026-11-05, revision 1; conversation: “acepto” in response to the explicit intent acceptance request.

## Problem and evidence

The automated accessibility audit reports an unnamed group around the setup window. A minimal view in the existing window reproduces the finding. A temporary label on the AppKit content view removed that finding in the investigated environment, but is not a validated fix. See [the investigation](../setup-permissions/issue-53-investigation.md) for methods, limitations and results.

## Audience and desired outcome

People using VoiceOver and other assistive technology should encounter a clearly identified window hierarchy and retain access to the setup screen's content and actions. The relevant automated audit should no longer report the unnamed window group, without suppressing findings or reducing accessibility.

## Scope and constraints

Investigate and implement a suitable accessibility treatment for the window hierarchy, if validated. The window hosts the rest of the assistant as well as setup, so verify that the treatment does not misidentify other screens, duplicate announcements or interfere with controls or window reopening. Preserve English and Spanish support, keyboard navigation, existing visual presentation, supported platforms and helper security. Use simulated data for tests; do not operate on real disks or change actual permissions.

## Non-goals and dependencies

Changing the visual design, helper authorization or system-settings behavior is outside this change. Subtitle contrast is tracked separately in [#25](https://github.com/afraidias/Relente/issues/25); the full audit cannot be claimed clean while it reports that issue. The owner accepted proceeding with macOS 27 testing without blocking on access to macOS 26 (2026-11-05). The separate macOS 26 runtime verification in #53 remains unverified until a suitable environment is available. This intent does not authorize merge or release.

## Success measures

- The unnamed-window-group finding is absent in reproducible automated checks on available supported environments, with no audit suppression.
- VoiceOver and keyboard checks show that the window, setup content, buttons and status announcements remain understandable and usable in English and Spanish; any shared-window effect is evaluated beyond the setup screen.
- Results, operating-system coverage and remaining issues are accurately recorded. A newer macOS result is not presented as proof for macOS 26.

## Open questions

- Which supported per-window approach provides a meaningful localized label without duplicate or misleading VoiceOver output?
- Can the audit check isolate the group finding while continuing to report the separately tracked contrast issue?
- When and where can macOS 26 runtime and accessibility verification be performed?
