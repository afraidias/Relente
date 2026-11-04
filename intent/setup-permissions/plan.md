# Setup screen implementation plan

- Revision: 1
- State: Accepted
- Implementation: In progress
- Issue: N/A — owner-led screen review
- PR: [#52](https://github.com/afraidias/Relente/pull/52) (draft)
- Approval: Owner, 2026-11-04, revision 1; conversation: “acepto” in response to the explicit plan acceptance request.
- Intent: [Accepted revision 1](intent.md)
- Design: [Accepted revision 2](spec.md)

## Ordered work

1. **Establish baseline and state coverage.** Inspect current setup, helper tests and previews; identify state transitions and settings actions. Acceptance: each accepted state has a reproducible safe sample or test route, including revoked approval and failures. Verify using focused tests and previews; no real disk operations.
2. **Implement setup presentation.** Update `PermissionsView`, its footer and existing components as appropriate: state-specific callouts, primary helper action, separate Full Disk Access action, reviewed recovery copy. Preserve helper security and later write-access checks. Acceptance: each state offers the correct action and does not claim a disk-access status. Verify with focused tests and previews.
3. **Wire state and accessibility.** Connect the existing settings action and distinguish a return after helper deactivation where needed; retain selections and preserve in-progress creation behavior. Add or update meaningful tests in `AssistantHelperTests` and relevant UI tests. Verify keyboard, announcements, Reduce Motion and no duplicate registration.
4. **Localize and inspect.** Update English and Spanish strings and product documentation. Inspect every state in both appearances and languages at the actual window size, including long text; use Accessibility Inspector and manual VoiceOver and keyboard checks. Verify the System Settings destination and labels on available supported macOS versions. Record unavailable environments rather than claiming success.
5. **Integrate evidence and review.** Run the project Debug unit tests with configured signing, arm64 Release compile check and full strict swift-format lint. Review the diff against the accepted artifacts and security invariants; record checks, limitations and findings here. Commit, push and open a PR within the accepted scope. Merge and release publication require separate owner authorization.

## Risks and dependencies

Task 2 follows the baseline; task 3 depends on the presentation and state mapping; task 4 follows the complete flow; task 5 follows verification. System Settings labels may vary by OS or locale and direct access to every supported version may be unavailable. Do not infer Full Disk Access status from helper status. Do not weaken helper checks, authorization or tests to pass verification. Material changes to behavior or risk return to owner review.

## Execution evidence

Not started. Baseline Debug build on main `c548e5e` succeeded with configured signing for visual inspection; no tests or accessibility checks are claimed. Branch `design/setup-permissions` is published; worktree `/private/tmp/relente-setup-permissions`. Draft artifacts are uncommitted. The language selector is deferred to issue #51.

### Progress — 2026-11-04

- Owner accepted plan revision 1. Implementation is in progress and uncommitted.
- Added state callouts and a separate Full Disk Access settings action, Spanish strings, and a return-after-deactivation message. No helper security logic was changed.
- Debug unit test run reported passed (375 tests, 5 skipped); this preceded the final layout adjustment. Release compile and full strict swift-format lint passed; repeat applicable checks after final edits.
- Inspected the initial Spanish dark appearance using simulated data. Found inconsistent callout widths and insufficient distinction; width was adjusted, but requires a fresh visual check. Other states, English, light appearance, actual settings navigation, VoiceOver, keyboard and Reduce Motion remain unverified.
- Next: verify and correct the hierarchy and all states, complete accessibility and language checks, add meaningful coverage where needed, rerun final checks, review and prepare PR. Do not mark verified or request integration yet.

### Owner visual feedback

The owner requested restoring the original icon and halo, equal callout widths, Liquid Glass controls, and removing the standalone erase-authorization sentence from its previous position. The updated initial state was built and visually inspected in Spanish dark mode with sample data. The owner subsequently chose to omit that explanation on this screen; no security behavior has changed. Other state, accessibility and final checks remain pending.

### Verification update

- Owner reviewed initial, approval, ready and simulated failure states in Spanish dark appearance; English dark failure was also visually inspected. Light and dark concept variants were reviewed, but the running implementation has not yet been manually checked in light mode. Installing and revoked-approval layouts have not been manually inspected in the running app.
- Debug unit suite passed after the final change; focused UI tests for the setup flow and simulated failure/retry passed (the latter preceded the final retry-icon adjustment). Release compile and strict full-scope swift-format lint passed after the final change. `git diff --check` passed.
- Accessibility tree exposes both settings and primary buttons; a manual Tab attempt did not establish full keyboard navigation. VoiceOver, Accessibility Inspector, Reduce Motion and actual settings destinations remain unverified. Do not claim these checks passed or request integration until resolved or the owner accepts a deferral.
- The owner chose to omit the erase-authorization explanation from this screen. Design revision 2 records that decision; erase authorization remains unchanged.

- Draft PR #52 was opened for review with the manual checks above still pending; it is not a request to merge.

### Follow-up checks — 2026-11-04

- In English light appearance, initial and failure screens fit in the window. The test also ran with Reduce Motion enabled. In a separate slow-registration simulation, the spinner was found to animate with Reduce Motion; it was corrected and manually verified as static. Appearance and Reduce Motion settings were restored.
- With keyboard navigation enabled, Tab focused both actions. The original keyboard setting was restored. The Full Disk Access button opened the expected System Settings page; no permission was changed.
- `performAccessibilityAudit()` failed on an unnamed group encompassing the window. The same audit against an isolated `origin/main` archive failed with the same message and a full-window element capture. The warning remains unresolved; no audit exception was added. Details and reproduction are in [accessibility-audit.md](accessibility-audit.md).
- VoiceOver automated activation timed out. A second attempt while it was manually active was rejected by automatic approval review over the risk of leaving VoiceOver active; VoiceOver was restored to off. Spoken output and status announcements remain unverified.
- Still pending: manual VoiceOver validation, resolving or separately accepting the pre-existing audit warning, visual inspection of the revoked-helper state, and verifying Login Items navigation on supported systems. The PR remains draft.
