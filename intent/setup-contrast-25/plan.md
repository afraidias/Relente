# Setup contrast implementation plan

- Revision: 1
- State: Accepted
- Implementation state: In progress
- Issue: [#25](https://github.com/afraidias/Relente/issues/25)
- Intent: [Accepted revision 1](intent.md)
- Design: [Revision 2, incorporating owner visual feedback](spec.md)
- PR: [#55](https://github.com/afraidias/Relente/pull/55) (draft; not ready for integration)
- Approval: Owner, 2026-11-05, revision 1; conversation: “Acepto” in response to the explicit plan acceptance request.

## Ordered work

1. **Record the baseline.** Preserve the existing unsuppressed setup accessibility audit and its failing subtitle-contrast result. Confirm the simulated setup data and available appearance/language test configuration. Verification: retain the existing Xcode result and report its actual finding; do not suppress the test or its findings.
2. **Improve setup text contrast.** Apply a native primary text style to the setup subtitle without changing the default style of shared headers or other screens. Run the full setup audit and relevant focused UI test. If a further setup text contrast finding appears, investigate and address it within the accepted design; stop for owner review if the remedy affects other screens or materially changes the visual design.
3. **Review appearance and accessibility.** Inspect the resulting screen in light and dark, with increased contrast where supported by the test environment, and in English and Spanish. Check title hierarchy, icon, spacing, callouts and controls. Verify keyboard and VoiceOver behavior, asking the owner for listening when needed. Use simulated data; do not alter real permissions or perform disk operations. Record any unverified combination. macOS 26 remains unverified but does not block the work, as accepted by the owner.
4. **Validate and prepare review.** Run the unfiltered setup audit, relevant simulated flow tests, required signed Debug unit tests, Release compile check and full strict Swift lint. Review the combined window-label and setup-contrast diff and document results and warnings, including any audit findings still open. Update both change plans and preserve separate follow-up for any app-wide contrast work. Prepare a PR only when acceptance criteria and applicable checks are met; merge requires separate owner approval.

## Dependencies and risks

The accepted window-label work is currently uncommitted in the same investigation branch and is needed to expose the subtitle finding in the audit. Preserve its test and all audit findings. A more prominent subtitle may affect visual hierarchy or expose other contrast issues; inspect the actual rendered result and stop for review if an appropriate fix requires broader changes. Do not claim the full audit passes until an actual unfiltered run passes.

## Execution evidence

Implementation and verification are in progress; prior baseline and the window-label investigation are documented in [the issue #53 plan](../setup-accessibility-53/plan.md) and [investigation](../setup-permissions/issue-53-investigation.md).

### 2026-11-05 execution in progress

- The initial primary text treatment removed the setup contrast finding and passed an isolated unfiltered audit on macOS 27.2, but the owner reported that the text stood out too much. A softer primary text treatment is under visual review and is not yet accepted as final.
- A subsequent full run passed the unit tests and other selected assistant UI tests, but the unsuppressed English and Spanish audits failed on an intermittently reported unnamed element whose screenshot shows the macOS menu bar. A later isolated English audit passed. The specific element and trigger remain under investigation; do not claim the audits are consistently passing or suppress this finding.
- The Release compile check and strict lint passed before the later softer-text and diagnostic changes; rerun applicable checks for the final version. Direct macOS 26 behavior remains unverified.
- Owner visual review, 2026-11-05: after reporting the initial primary text was too prominent, the owner reviewed the softer variant and said “Me gusta más”.

- Contrast-only audits passed for the softer variant in English and Spanish on macOS 27.2. Full audits remain enabled: a pair failed with the element identified as `TouchBar`, and a later pair passed. This intermittent failure remains unexplained; it must not be represented as resolved.
- The final softer treatment passed both contrast-only audits and, in a subsequent run, both unfiltered audits, the assistant UI suite and signed Debug unit tests on macOS 27.2. The earlier TouchBar failure remains unexplained and intermittent, so a successful rerun does not establish its cause or eliminate it. Relente does not define Touch Bar items in its source; Apple's [Touch Bar documentation](https://developer.apple.com/documentation/appkit/nstouchbar) notes that frameworks may provide bars automatically. The host model has a Touch Bar; actual ownership and accessibility impact of the reported element have not been established.
- The generic Release build and full strict lint passed for the softer product code; the Release build warned about a missing cached SwiftShims PCM. The current English VoiceOver and light/dark/increased-contrast manual reviews are still pending; no macOS 26 runtime check is claimed.
- Owner VoiceOver check, 2026-11-05, English simulated setup: the owner reported the screen reads well and both installation start and completion are announced.
- Inspected the English setup in light appearance on macOS 27.2: subtitle and callout messages appeared legible, with the larger bold title visibly dominant. A launch intended to inspect dark appearance resolved to an existing light window, so it is not evidence of a dark-mode review. Increased-contrast appearance remains unverified.

- 2026-11-07: forced the app's color scheme to dark only in the simulated Debug UI test; the setup-window screenshot showed legible subtitle and callout text and a prominent heading. The contrast-only accessibility audit passed on macOS 27.2 in English. This did not verify increased contrast or every setup state. Screenshot: `/private/tmp/relente-issue53-dark-20261107/4E7BF42B-5A96-405D-8670-79C0E02B6B25.png`.

### 2026-11-07 additional verification

- Full signed Debug `RelenteTests` and `AssistantFlowUITests` completed successfully (463 reported passing test cases, including 20 assistant UI tests). Both unfiltered setup audits, English/Spanish light contrast checks, dark contrast checks in English/Spanish, the dark failure state and the window name after app relaunch passed. Strict full-scope Swift lint and the generic Release build passed without reported warnings.
- The first dark Spanish run launched without a window because the test's standalone flag interfered with argument parsing. Providing the flag a value fixed the test; the focused retry and subsequent full run passed.
- Manual visual review of the dark English screenshot showed the hierarchy and contrast clearly. Reduced Motion and increased contrast have not been verified: the computer control provider and its skill file are unavailable, and the project does not permit claiming an untested configuration. Official AppKit documentation explicitly advises against directly assigning a high-contrast appearance to a view as a substitute for enabling the system setting.
- The TouchBar audit finding was not observed in the successful full run, but prior intermittent failures remain unexplained and are not suppressed. Direct macOS 26 testing remains unverified as previously accepted by the owner.

- 2026-11-07, actual system accessibility settings: with Increase Contrast enabled, the English and Spanish setup contrast audits passed for the system appearance and forced dark appearance. The captured dark screenshot was visually inspected. With Reduce Motion enabled, simulated helper installation, failure/retry, complete flow and keyboard Back/Escape tests passed. These functional tests do not by themselves prove the absence of all animation. System Increase Contrast and Reduce Motion were restored to off, and Appearance was observed as Automatic. Earlier notes about these checks being unavailable are superseded by this evidence.

- 2026-11-07: the owner requested deferring the Touch Bar finding as a future improvement, tracked in [#54](https://github.com/afraidias/Relente/issues/54). Three setup audits and three minimal-view audits each reproduced an unnamed disabled `TouchBar` with no children. This does not prove system ownership or lack of impact. Full setup audits and the Touch Bar diagnostic remain unsuppressed in the working tree and can still fail; issue #54 does not itself resolve or waive them.

- 2026-11-07 integration review: `origin/main` was checked against GitHub and still points to `caa6eeabd6fa9f8b6ffb45c7b66f4fb35cc22f14`. Both unfiltered setup audits and the separate Touch Bar diagnostic were run without suppression and all failed on the unnamed `TouchBar` element (reports in `/private/tmp/relente-review-audits/`). The owner requested deferring that issue as [#54](https://github.com/afraidias/Relente/issues/54). This leaves the accepted plan's unsuppressed audit/integration criteria unmet; no PR or merge is claimed. Do not delete or suppress the failing audit to force progress.

- 2026-11-07: the owner accepted the [draft review deviation](../setup-contrast-25/review-addendum.md), and draft PR [#55](https://github.com/afraidias/Relente/pull/55) was opened. The Touch Bar finding remains unsuppressed and the PR is not ready for integration.

- 2026-11-07 scope correction: the owner requested keeping Touch Bar as a future enhancement outside this PR. The duplicate Touch Bar-only diagnostic test was removed; both original unfiltered setup audits remain unchanged. The latest execution of both passed, while earlier failures remain recorded in #54.
