# Draft review-stage deviation for the setup changes

- Revision: 1
- State: Accepted
- Issue: [#54](https://github.com/afraidias/Relente/issues/54)
- Approval: Owner, 2026-11-07, revision 1; conversation: “continua” in response to the explicit draft-PR deviation acceptance request.

## Decision requested

Allow opening a draft PR to review the already implemented setup window-label and contrast changes while the intermittent Touch Bar audit failure remains tracked in #54. The owner previously requested deferring the Touch Bar investigation; that request did not explicitly accept opening a PR with failing local audits.

## Conditions

- Keep all existing setup accessibility audits and their failure reporting intact. Do not remove tests, suppress findings, claim the audits pass, or imply the Touch Bar warning is harmless.
- State in the draft PR that the latest English and Spanish unfiltered audits and the Touch Bar diagnostic failed on an unnamed `TouchBar`; prior runs passed, so the finding is intermittent. Include the successful contrast, VoiceOver, unit, UI, lint and Release evidence and the unverified macOS 26 limitation accurately.
- This deviation only permits a draft review. The current integration criterion and required project checks remain in force. Do not mark the PR ready, merge, or publish without the required evidence and separate owner authorization. If a change to the integration criteria is proposed, obtain explicit acceptance of that change first.
- Do not treat CI's lack of a UI-audit job as evidence that these local audits passed. If automatic approval review rejects an action, do not bypass it; report the rejection.

## Draft PR description

The setup window's unnamed accessibility group makes its context difficult to identify, and secondary setup text triggers a contrast audit finding. This change gives the shared assistant window a meaningful accessible name and increases contrast only for setup guidance, while retaining the existing layout and actions.

The owner confirmed the simulated setup screen and installation announcements with VoiceOver in English and Spanish. Signed Debug unit tests, assistant UI tests, strict Swift lint, the generic macOS Release build, and setup contrast checks in light/dark and with Increase Contrast have passed in recorded runs. Reduce Motion functional flows were also exercised. macOS 26 has not been tested directly.

**Draft / blocked:** the latest unfiltered setup audits fail intermittently on an unnamed `TouchBar` element. Its cause and impact are tracked in #54; the audits remain enabled and no finding is suppressed. This PR is not ready for integration.
