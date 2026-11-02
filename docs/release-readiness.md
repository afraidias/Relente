# Release readiness and roadmap follow-up

This is the consolidated roadmap checklist, not evidence of checks passing. Roadmap step numbers
refer to README milestones. The owner must resolve or explicitly accept each release limitation.
Review acquisition readiness under its successor change; incomplete download work is not a prerequisite for integrating the process migration.

## Steps 7–8: live creation and first distribution

- [ ] Validate Full Disk Access/TCC attribution and the helper-side preflight on supported macOS
  versions. The recorded macOS 27 run blocked before erase without access and completed with it;
  that does not prove other versions. Keep the actual helper write preflight as the safety gate.
- [ ] Validate signed/notarized helper registration, connection, uninstall and rejection of a client
  from another team. Verify fresh authorization, Touch ID and password fallback on supported Macs.
  [Issue #33](https://github.com/afraidias/Relente/issues/33) records the authorization investigation.
- [ ] Reconcile [issue #40](https://github.com/afraidias/Relente/issues/40) with the owner's
  2026-11-02 Apple-silicon-only host support decision. Intel host validation is no longer a release
  requirement; clarify any separate installer startup compatibility work before changing the issue.
  The external issue has not been modified. Do not infer physical USB startup from command
  completion or unit tests.
- [ ] Check actual icon rendering on supported macOS versions (26.0 and later), plus the app
  switcher. The owner's 2026-11-02 minimum-version decision removes macOS 14–15 release validation
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

## Steps 7 and 9: product follow-up

- Completion notifications: [issue #19](https://github.com/afraidias/Relente/issues/19), step 7 follow-up.
- Installer acquisition: step 9. The previous softwareupdate approach was closed without verified
  cancellation. The [direct-download successor](changes/direct-installer-download/intent.md) is
  Draft; preserve and review useful work from the existing branch after integrating the validated
  lifecycle migration. Retained-download deletion is separate work tracked in
  [issue #39](https://github.com/afraidias/Relente/issues/39).
- Technical output was delivered with live creation; [issue #20](https://github.com/afraidias/Relente/issues/20)
  is historical context rather than evidence that persistent logging is implemented.

## Unscheduled ideas

Showing fixed-media USB sticks or other external SSDs/HDDs, and remembering manually chosen
installers across launches, were possibilities, not approved features. Keep them outside product
scope. If accepted, assign a roadmap step and issue before capturing a new intent. No external
issue is created by this migration.
