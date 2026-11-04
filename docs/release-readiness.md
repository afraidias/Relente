# Release readiness and follow-up

This checklist records release follow-up, not evidence of checks passing. The owner must resolve
or explicitly accept each release limitation. See the linked change artifacts for actual results.

## Live creation and distribution

- [ ] Review Full Disk Access/TCC attribution and the helper-side preflight. The recorded macOS 27 run blocked before erase without access and completed with it;
  that does not prove other versions. Keep the actual helper write preflight as the safety gate.
- [ ] Validate signed/notarized helper registration, connection, uninstall and rejection of a client
  from another team. Verify fresh authorization, Touch ID and password fallback where available.
  [Issue #33](https://github.com/afraidias/Relente/issues/33) records the authorization investigation.
- [ ] Reconcile [issue #40](https://github.com/afraidias/Relente/issues/40) with the owner's
  2026-11-02 Apple-silicon-only host support decision. Intel host validation is no longer a release
  requirement; clarify any separate installer startup compatibility work before changing the issue.
  The external issue has not been modified. Do not infer physical USB startup from command
  completion or unit tests.
- [ ] Check actual icon rendering and the app switcher. The owner's 2026-11-02 minimum-version decision removes macOS 14–15 release validation
  from scope. Icon Composer previews do not replace runtime checks; prior runtime evidence used
  macOS 27 and does not establish macOS 26 behavior. These checks remain pending release preparation.
- [ ] Complete audible VoiceOver ready/error announcements, screen-title focus after navigation,
  Review warnings and the unsupported-installer announcement. Accessibility-tree inspection and
  announcement API calls do not prove speech. See [issue #25](https://github.com/afraidias/Relente/issues/25).
- [ ] Verify light/dark and Reduce Motion behavior, including actual crossfades and rolling figures
  with live progress. A previously instrumented sample build exercised the crossfade branch only.
- [ ] Reconcile Big Sur, Sonoma and Tahoe real-run coverage, `.dmg` read-only mounting/detachment
  and `InstallAssistant.pkg` preparation with current evidence. Do not rerun destructive checks
  without a separate authorized disposable disk. Record unavailable combinations explicitly.
- [ ] Review measured required capacity and FREE AFTERWARDS accuracy, actual phase order and
  timing, output parsing, speed and remaining-time behavior. Preserve honest indeterminate states.
  [Issue #41](https://github.com/afraidias/Relente/issues/41) tracks further ETA work.
- [ ] Confirm the sample-backed whole-flow test covers retry, cancellation, unplugging, eject and
  safe keyboard defaults. Reconcile older manual deferrals against current evidence before closure.

Implementation of helper validation, live progress, package/image support, cancellation, sleep
prevention and real eject is already present on the migration baseline. Earlier deferrals to those
implementation steps are superseded; they do not prove the runtime matrix above has passed.
Current behavior belongs in [product.md](product.md), and security rules remain in AGENTS.md and
SECURITY.md. Do not reinstate obsolete simulation-only Release behavior or obsolete no-FDA advice.

## Product follow-up

- Completion notifications: [issue #19](https://github.com/afraidias/Relente/issues/19), creation follow-up.
- Installer acquisition: direct download shipped in [0.11.0](https://github.com/afraidias/Relente/releases/tag/v0.11.0)
  through [PR #47](https://github.com/afraidias/Relente/pull/47). See the
  [closure evidence and remaining limits](../intent/direct-installer-download/plan.md#closure-checkpoint--2026-11-04).
  Validation on other Macs and versions is not a requirement; deleting complete retained
  installers remains separate work tracked in [issue #39](https://github.com/afraidias/Relente/issues/39).
- Creation feedback now appears directly in the main screen; the former Activity/log window was removed in 0.11.0. Earlier technical output was delivered with live creation; [issue #20](https://github.com/afraidias/Relente/issues/20)
  is historical context rather than evidence that persistent logging is implemented.

## Unscheduled ideas

Showing fixed-media USB sticks or other external SSDs/HDDs, and remembering manually chosen
installers across launches, were possibilities, not approved features. Keep them outside product
scope. If accepted, create an issue before capturing a new intent. No external
issue is created by this migration.
