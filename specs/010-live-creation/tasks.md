# Tasks: 010 · Live installer creation

Spec: [spec.md](spec.md) · Plan: [plan.md](plan.md)

> The owner approved the revised plan: Activity uses a popover, Permissions retains its existing
> layout with added helper and access guidance, drive presentation stays unchanged, and live
> creation requires Full Disk Access and Background App Activity. Completed work is retained.

Verification commands required by the project:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -scheme Relente -destination 'platform=macOS' -only-testing:RelenteTests
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -scheme Relente -destination 'platform=macOS' -only-testing:RelenteUITests
xcrun swift-format lint -r --strict Relente RelenteHelper Shared RelenteTests RelenteUITests
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build -scheme Relente -configuration Release -destination 'generic/platform=macOS' CODE_SIGNING_ALLOWED=NO
```

## Follow-up from the real-drive experiment

The signed build completed a creation on the approved SanDisk on macOS 27 while Full Disk Access
was enabled for Relente. One successful run does not establish that this permission is necessary
on every supported Mac or which identity received it. Full Disk Access was restored to disabled.
The run also exposed an accessibility crash and untruthful progress and remaining-time feedback.
The following tasks precede completion of the existing feature tasks; keep their existing results.

- [x] Task 18: Gate creation on helper write access
  - Acceptance: remove the unprivileged app's scoped Removable Volumes probe. Add a typed helper
    preflight that validates the selected disk fingerprint and mounted volume, then writes and
    removes a unique temporary marker without erasing. The app must run it after administrator
    authorization and remain on Review if it fails. Do not start creation or erase on denial.
  - Verify: injected denied and allowed results cover Review gating. On 27 October 2026, with Full
    Disk Access disabled, the installed v3 helper's preflight failed on the approved SanDisk;
    Relente stayed on Review, displayed the settings alert, and did not start creation. The
    confirmation toggle was cleared afterwards. No permission setting was changed.
  - Files: helper XPC contract, creation pipeline/client, Assistant, focused tests and this plan

- [x] Task 19: Explain creation permissions
  - Acceptance: retain the Permissions layout and explain the helper, Full Disk Access and
    Background App Activity. Permit browsing, installer selection and drive selection without
    Full Disk Access. If the helper preflight fails on Review, block creation and provide a route
    to the relevant System Settings panes; do not add a recurring acknowledgement checkbox.
  - Verify: inspected the Spanish Permissions and Review states on the live app; the failed
    preflight alert offers both Full Disk Access and Login Items settings routes. The existing
    layout remains intact.
  - Verify: owner reviews the OS prompt and HIG treatment; sample-backed UI and service tests cover
    grant, denial, revocation, localization and VoiceOver.
  - Files: Permissions screen and associated service/model types, string catalog, focused tests

- [x] Task 20: Correct live progress and remaining time
  - Acceptance: parse observed Apple output and preserve unknown phases, copied bytes, speed and
    remaining time as unknown when not measurable. Recognize Apple's `Copying essential files...`
    message as the start of Copy, and label the remaining time unavailable once copying starts if
    Apple provides no measurable basis for an estimate. Do not present a phase completion or
    computed estimate as an actual copy measurement; retain Activity output and the existing main geometry.
  - Verify: parser and service regressions cover `Copying essential files...` when typed helper
    progress is missing, plus unknown bytes and remaining time. Focused and full unit tests,
    strict lint and universal Release build pass. On the SanDisk test drive, the rebuilt app
    advanced to Copy, showed `No disponible` for remaining time, and kept copied bytes unknown
    while displaying approximate USB write activity. The run was then cancelled in Copy; the USB
    is partially created and must be erased before reuse.
  - Files: output parser, creation service/model, Creating screen, focused tests

- [x] Task 21: Fix the accessibility traversal crash
  - Acceptance: reproduce and eliminate the Creating/Error accessibility recursion while retaining
    meaningful VoiceOver labels and the Activity popover; do not remove accessibility support.
  - Verify: sample-data accessibility traversal remains stable while progress and error states
    update; check VoiceOver and Reduce Motion without touching a real disk.
  - Verify: Activity/full-log UI tests pass with sample data, including after Error. The live
    Creating and stopped states also survived accessibility-tree queries. The Creating/Activity
    UI test passed with VoiceOver enabled and again with Reduce Motion enabled; both settings were
    restored to off afterwards. No real disk was used by these UI tests.
  - Files: affected Creating/Activity views and focused UI or accessibility tests

- [x] Task 22: Verify the selected device's write activity
  - Acceptance: associate IOKit counters with the selected physical drive during a real-drive
    validation and compare with system device statistics; do not present whole-device throughput
    as installer-copy speed or keep continuous polling in the app.
  - Verify: injected samples cover missing data, counter reset, zero intervals and identity
    changes. During Task 20's owner-approved SanDisk run, Relente showed about 9.7 MB/s while
    `iostat` showed 9.48 MB/s on external `/dev/disk6` (SanDisk Ultra); `/dev/disk7` (Toshiba)
    showed no writes. `diskutil info disk6` confirmed USB, external and removable. After
    cancellation, read-only samples showed no continuing SanDisk writes; no additional write run
    was started for this check. This diagnostic was removed from the app after review because it
    was approximate and did not tell the user how many installer bytes were copied.
  - Files: this plan (the temporary sampler and tracker were removed in Task 24)

- [x] Task 23: Bound helper XPC requests
  - Acceptance: every reply-bearing request has an operation-appropriate deadline; a helper that accepts a
    connection but never replies cannot leave the UI stuck. Timeout completes the request exactly
    once, invalidates the connection, logs the operation and follows the existing recovery path.
  - Verify: immediate/no/late reply tests and the Review recovery test for a failed helper version
    check pass; the full unit suite, strict swift-format lint and universal Release build pass. No
    test or preview contacts the real helper or a real disk.
  - Files: `Relente/Services/LiveHelperClient.swift`, focused service tests, this spec and plan

- [x] Task 24: Clarify live phase feedback
  - Acceptance: while formatting, show the real format progress in one focused progress bar and
    name the current action; show only elapsed time until Copy begins. Show the current
    macOS-reported action during later phases. Animate elapsed time with the existing
    rolling-number treatment. Keep copied bytes and remaining time
    unknown when `createinstallmedia` provides no measurement. Remove the approximate device
    write-rate display and its continuous IOKit polling.
  - Verify: localized phase descriptions, focused format feedback, changing elapsed time, unknown
    copied bytes/remaining time and the absence of speed feedback are covered by UI tests. Dark,
    classic-control and failure previews exist; VoiceOver values and Reduce Motion fallbacks are
    covered by the existing accessible stat and phase components.
  - Files: Creating screen, string catalog, focused UI tests, this plan and task list

- [x] Task 25: Show measured progress during Apple's silent copy phase
  - Acceptance: while `createinstallmedia` copies, the helper observes only a regular
    `SharedSupport.dmg` at the validated source and the matching path inside the selected USB's
    installer app. It sends the destination byte count and source byte count through the typed XPC
    progress callback; it does not infer installer bytes from whole-device throughput. Relente
    shows measured bytes and a progress bar on the main Creating screen, without an empty copied
    value or detached spinner. Show remaining time only after enough stable byte-rate samples;
    otherwise use a clear calculating/unknown state. If either file cannot be safely matched,
    preserve truthful indeterminate feedback. Activity remains for phase changes and technical
    output/errors, not as the only place where users can understand copy progress.
  - Verify: eight focused file/rate tests cover absent data, a matching image, symlink rejection,
    size bounds, stable-rate resets, a 30-second sample window and a brief write burst. An earlier
    full unit run passed 399 tests, including the latest ETA changes; the latest run passed 338
    tests. The latest full UI run passed all
  26 tests with Xcode's signed runner. Strict lint passed and the universal Release build passed
  with warnings as errors. The approved SanDisk run completed;
    read-only inspection measured both source and destination `SharedSupport.dmg` at
    18,386,308,006 bytes. That creation completed before the Task 25 monitor was added; it confirms
    the source/destination file pair and final size, not the new in-run display on real hardware.
    The sample UI test showed measured bytes/progress and an ETA after stable samples, and the
    unknown state without an empty placeholder. UI tests and fixtures used sample data and never
    touched a real disk. Two later owner-approved runs showed live copy measurement, then were
    cancelled by the owner. The first reached 27% (5.11 GB of 18.39 GB) and exposed an ETA that
    stayed calculating: a four-sample cap could never satisfy the five-second window. A six-sample
    fix made ETA available, but the second run showed it fluctuating from about 29 to 32 to 27 min
    over 3:48 before cancellation at 11% (2.14 GB). The estimator now uses 31 one-second samples
    over 30 seconds. The full unit suite passes, including the 30-second-window and brief-burst
    checks. On 28 October, the current signed build showed
    real SanDisk progress: 391 MB and 32 min at 0:49, 575 MB and 32 min at 1:09, then 783 MB and
    31 min at 1:31 (4%). The owner stopped the run at Copy; it did not verify completion or
    bootability. On 28 October, the next owner-approved run completed creation on the SanDisk in
    31 minutes. The estimate descended from 31 min at 0:52 (407.6 MB) to 29 min at 1:57 (1.04 GB),
    25 min at 4:52 (2.82 GB), 23 min at 8:17 (4.89 GB), 18 min at 12:26 (7.41 GB), 15 min at
    15:26 (9.23 GB), 10 min at 20:23 (12.23 GB), 5 min at 25:18 (15.2 GB), and under one minute
    at 29:53 (17.99 GB), with no later upward jumps in these observations. Relente reported
    completion in 31 minutes. Read-only checks found the resulting 30.75 GB removable USB volume
    mounted, `OS Can Be Installed: Yes`, and source/destination `SharedSupport.dmg` sizes equal at
    18,386,308,006 bytes. This verifies a complete creation and volume contents, but not startup
    from the USB. The initial estimate settled downward during the first minutes; issue #41 tracks
    further ETA smoothing and review of displayed time precision.
  - Files: helper runner/progress callback, shared XPC progress contract, live creation service,
    creation progress model, Creating screen, English/Spanish strings and focused unit/UI tests

### Checkpoint: Verified permission and feedback

- [x] The write preflight blocks creation before erase when access is denied and allows the tested
  creation after the owner enables access; the recovery path explains the setting.
- [x] On macOS 27, unified TCC logs identify the denied removable-volume request as
  `com.afraidias.Relente.Helper` with `auid=0`, `euid=0`; denial and successful creation are both
  observed with Full Disk Access disabled and enabled, respectively.
- [ ] TCC behavior on other supported macOS versions remains open as recorded in the spec.
- [x] Live feedback remains honest when Apple does not report a measurable value, and the
  accessibility traversal no longer crashes the app.
- [x] The existing Permissions layout and selected Activity popover are preserved.

## Phase 1: Inspect boundaries and prove package preparation

- [x] Task 1: Map current creation and helper boundaries
  - Acceptance: identify the existing helper/XPC API, creation service/events/models, installer
    preparation, screen ownership, project file membership and tests that 010 will change; record
    the minimal extension points without changing code.
  - Verify: findings are reflected in the implementation task file and no existing behavior is
    assumed to be a separate pre-erase format stage.
  - Files: none (read-only inspection)

- [x] Task 2: Prove no-install `InstallAssistant.pkg` preparation
  - Acceptance: validate package signature and `pkgutil --expand-full` behavior using a
    representative Apple package; confirm the signed Apple Software Update chain, extracted app
    and SharedSupport layout, `createinstallmedia` signature, and the app bundle's legacy resource
    envelope. Package signature must authenticate resources when the bundle-resource check is
    skipped. Do not install the package or execute its scripts on the host Mac.
  - Verify: on 27 October 2026, `pkgutil --check-signature` reported `signed Apple Software` with
    the Software Update → Apple Software Update Certification Authority → Apple Root CA chain.
    `pkgutil --expand-full` produced `Payload/Applications/Install macOS Sequoia.app` and
    `SharedSupport.dmg`; Apple's postinstall script hard-links that image to
    `Contents/SharedSupport/SharedSupport.dmg`. We recreated the hard link in private test storage
    without running the script. The extracted app had a legacy resource envelope; its code
    satisfied `anchor apple` when resource verification was skipped, and its `createinstallmedia`
    satisfied `anchor apple` with normal verification. No package was installed and no USB was
    touched. The owner approved this narrow package-signature exception. The helper now rechecks the
    copied package signature and only permits resource-check skipping for the prepared package/app
    layout; a regression test rejects direct app and mounted DMG paths from that provenance.
  - Files: `specs/010-live-creation/plan.md`, `spec.md`, focused package-preparation tests

- [x] Task 3: Define typed helper creation and output contracts
  - Acceptance: represent a create request, phase/progress, timestamped plain-text output,
    cancellation and terminal outcome as typed `Sendable` values; output is helper-to-app only;
    preserve protocol versioning and signing requirements; add no shell, generic command API or
    networking.
  - Verify: contract tests cover values and protocol compatibility; Swift 6 compilation passes.
  - Files: `Shared/HelperProtocol.swift`, new shared contract types, `RelenteTests/HelperContractTests.swift`

### Checkpoint A: Boundaries and contract

- [x] Package preparation is demonstrated or that source's scope is revised with the owner.
- [x] XPC contract is narrow, typed, one-way for output and covered by tests.
- [x] No implementation path runs `diskutil eraseDisk` before `createinstallmedia`.

## Phase 2: Installer preflight and command output

- [x] Task 4: Validate direct installer apps and locate the fixed executable
  - Acceptance: reject unsupported, malformed, symlinked or non-Apple-signed sources before
    erase; resolve `createinstallmedia` from the installer without accepting a caller-provided
    executable path; check signatures again immediately before execution.
  - Verify: tests cover valid/invalid signatures, missing executable, symlinks and replacement
    between preflight and launch.
  - Files: helper installer-preflight type(s), focused `RelenteTests`

- [x] Task 5: Prepare disk-image sources with owned mount cleanup
  - Acceptance: mount `.dmg` read-only and hidden; identify its contained installer; detach only a
    mount created by this operation on success, failure and cancellation; leave pre-existing
    mounts alone.
  - Verify: `InstallerImageMounterTests` inject `hdiutil` and prove pre-existing mounts are reused,
    new mounts are read-only and hidden, and only an owned mount with a device is detached. The
    runner uses the tested async cleanup scope; simulated success, failure and cancellation results
    each detach the owned mount.
  - Files: helper/service disk-image mount type(s), focused `RelenteTests`

- [x] Task 6: Prepare `InstallAssistant.pkg` without host installation
  - Acceptance: the helper copies the user-selected package into a root-owned mode-0700 temporary
    directory, verifies that copy accepts only the Apple Software Update signer and chain, then
    expands it with the fixed `pkgutil --expand-full` command. Never run package scripts. Create the
    expected SharedSupport hard link, reject unsafe paths, and ensure the helper validates the
    Apple-signed installer code; skip only legacy app resource validation for this root-owned
    extraction. The helper validates `createinstallmedia` normally. Clean the temporary directory
    on every terminal path.
  - Verify: preparation tests cover copy/check/expand order, trusted Apple package output,
    invalid and third-party signatures, malformed layout, SharedSupport linking, unsafe paths and
    cleanup on success/failure/cancellation. The cancellation test requests cancellation after
    expansion and verifies the private extraction is removed. Helper tests prove the package-specific
    resource exception cannot be used for direct app or disk-image sources.
  - Files: `Relente/Services/InstallerPackagePreparer.swift`,
    `RelenteHelper/LiveCreateInstallMediaRunner.swift`, focused `RelenteTests`

- [x] Task 7: Parse `createinstallmedia` output
  - Acceptance: map known command output to typed phases and optional percentages; timestamp and
    preserve plain-text lines; unknown, reordered or incomplete output never fabricates progress
    or success.
  - Verify: captured fixtures cover supported output variants, missing percentages, unexpected
    phase order, terminal errors and high-volume output.
  - Files: shared parser type(s), focused parser tests

### Checkpoint B: Preflight and output parsing

- [x] Invalid installers fail before destructive work and signatures are rechecked before launch.
- [x] Operation-owned disk-image mounts and package temporary files are cleaned on every exit.
- [x] Unknown or incomplete output remains truthful and cannot signal success.

## Phase 3: Helper operation

- [x] Task 8: Add cancellable pseudo-terminal runner
  - Acceptance: launch only the validated fixed `createinstallmedia` executable with fixed
    `--volume` and `--nointeraction` arguments; stream output; terminate on cancellation or XPC
    disconnect; map non-zero exit to failure.
  - Verify: the production runner is compiled into the unit-test target with only its process
    executor and signature verifier injected. Tests cover the validated executable, exact fixed
    arguments, streamed output, success/nonzero exit mapping and cancellation while running. The
    pseudo-terminal implementation remains the helper's only production executor; tests never
    launch Apple's destructive command. Pipeline cancellation is covered separately.
  - Files: helper process-runner type(s), focused `RelenteTests`

- [x] Task 9: Orchestrate authorization, validation and creation
  - Acceptance: serialize one operation; check fresh authorization and disk eligibility/fingerprint;
    preflight source; recheck disk and Apple signatures immediately before execution; let
    `createinstallmedia` perform preparation/erasure; clean owned resources and report typed
    terminal results. Do not run `diskutil eraseDisk` separately.
  - Verify: injected pipeline tests prove check order and cover auth failure, changed/disconnected
    disk, preflight/signature failure, command failure, cancellation and success.
  - Files: helper request handler/pipeline, shared outcome types, focused `RelenteTests`

- [x] Task 10: Wire typed XPC progress and cancellation
  - Acceptance: stream progress and output to the calling app, serialize active requests, cancel
    the active operation, preserve mutual code-signing requirements, and clean up on connection
    loss.
  - Verify: production helper handler tests send typed progress and one-way output through the
    production receiver and assert the terminal reply; a held creation is cancelled by connection
    loss and the shared operation gate accepts the next request. Request-reply deadline tests cover
    immediate, missing and late replies; contract tests cover supported, outdated and missing
    protocol versions. The progress receiver, process runner, cancellation path, and mutual signing
    requirements have focused tests. No test launches Apple's destructive command or touches a
    real disk.
  - Files: `RelenteHelper/HelperListener.swift`, `RelenteHelper/HelperRequestHandler.swift`,
    `Relente/Services/LiveHelperClient.swift`, `Shared/HelperProtocol.swift`, focused tests

### Checkpoint C: Helper behavior

- [x] Tests prove security check ordering, typed progress/output and all terminal cleanup paths.
- [x] Helper contains no shell, generic command runner or networking.
- [x] No test or preview can erase a real disk.

## Phase 4: App flow, feedback and verification

- [x] Task 11: Connect the live creation service
  - Acceptance: map helper progress, optional percentages, timestamped output, cancellation and
    terminal outcomes to the creation service; preserve deterministic sample implementations;
    keep output only for the active run and clear it on terminal flow/restart.
  - Verify: unit tests cover event mapping, cancellation, error routing and output lifetime across
    retries: output remains available on Error and is cleared when leaving that failed run with
    “Try Again”. The latest full unit run passed 338 tests.
  - Files: `Relente/Services/HelperCreationService.swift`, helper clients, creation models,
    focused `RelenteTests`

- [x] Task 12: Gate Done on resulting-volume verification
  - Acceptance: helper success is followed by an app-side check that the expected installer
    volume exists and contains the installer; verification failures route to Error and never mark
    the drive ready.
  - Verify: injected checks cover valid volume, missing volume and invalid contents.
  - Files: verification service/protocol, `Relente/Services/HelperCreationService.swift`, focused tests

- [x] Task 13: Update installer-first flow and fit feedback
  - Acceptance: flow selects the installer before the drive; each eligible drive communicates
    whether it fits the selected installer; too-small drives cannot be selected; Review reflects
    the same installer and destination.
  - Verify: model/view tests cover fit boundaries, selection behavior and navigation using sample
    data.
  - Files: `Relente/App/Assistant.swift`, `Relente/Views/InstallerView.swift`,
    `Relente/Views/DriveView.swift`, models and focused tests

- [x] Task 14: Show truthful creation phases and output
  - Acceptance: Creating says the installer is being prepared until `createinstallmedia` reports
    its first phase, then reflects actual preparation/erasure and copying output; phases without a
    percentage are indeterminate; Activity uses the approved accessible popover with a direct,
    labelled action to a larger full-log window; Error shows final output lines; output is never
    persisted; main geometry and breadcrumb position stay fixed.
  - Verify: previews and sample-driven UI tests cover phases, unknown progress, the Activity popover,
    failure and cancellation; check accessibility and classic controls.
  - Files: `Relente/Views/CreatingView.swift`, `Relente/Models/CreationState.swift`,
    `Relente/Models/CreationProgress.swift`, `Relente/Resources/Localizable.xcstrings`,
    focused UI tests

- [x] Task 15: Review affected screens and localize feedback
  - Acceptance: Installer, Drive, Review, Creating and Error clearly show current state, next
    action and destructive consequences; include English and Spanish; support VoiceOver, Reduce
    Motion, light/dark and macOS 14–15 classic controls.
  - Verify: screen previews and the end-to-end sample UI test cover the revised flow and status
    announcements.
  - Files: affected `Relente/Views`, `Relente/Components`, `Relente/Resources/Localizable.xcstrings`,
    `RelenteUITests`

### Checkpoint D: App flow

- [x] Unit tests cover event mapping, failure/cancel routing, output lifetime and verification.
- [x] The UI test follows installer → drive → review → create → done and representative failure
  and cancellation paths using sample services only.
- [x] Fixed geometry, accessible status/log content, translations, motion fallbacks, appearance
  previews and classic controls are reviewed; the full sample flow passes with classic controls.
- [x] A system-level pass with macOS VoiceOver and Reduce Motion enabled passed in the Creating/
  Activity flow; both system settings were restored to off afterwards.

## Phase 5: Product documentation and quality gates

- [x] Task 16: Update product and helper documentation
  - Acceptance: describe live creation, supported sources, helper security, cancellation,
    verification, retained output behavior and any proven permission requirement; keep Apple
    download/catalog work in roadmap step 9.
  - Verify: README, `docs/product.md`, SECURITY.md and BUILDING.md agree with the approved spec.
  - Files: `README.md`, `docs/product.md`, `SECURITY.md`, `BUILDING.md`

- [x] Task 17: Complete release readiness and feature records
  - Acceptance: Release enables the real service; spec/index/product status match shipped
    behavior; mark spec Done only in the final PR commit. Run required unit/UI tests, strict lint,
    Debug tests and universal Release build with warnings as errors.
  - Verify: all project quality gates pass; creation, cancellation and resulting-volume contents
    (`OS Can Be Installed: Yes`) are manually verified on Apple silicon. Intel validation is
    tracked separately in issue #40; physical startup is outside feature 010's scope.
  - Files: `Relente/App/Assistant.swift`, `Relente/Views/ReviewView.swift`,
    `specs/README.md`, `docs/product.md`, `README.md`, and changed security/build docs

### Checkpoint E: Definition of Done

- [x] Spec acceptance criteria and AGENTS.md Definition of Done are met or recorded as open items.
- [x] No test weakens a security rule; previews and UI tests never touch real disks.
- [x] Manual verification confirms the completed installer volume on Apple silicon. Intel
  validation is tracked separately in issue #40; physical USB startup is outside feature 010's scope.
- [x] No commit, push, PR or merge occurred without the owner's explicit request.

## Verification run · 28 October 2026

- Earlier unit run: 399 passed, 0 failed, 0 skipped on macOS 27.0.1 arm64. This includes cancellation
  before the helper runner starts and cancellation while it is active.
- Unit run before the final handler integration: 341 passed, 0 failed, 0 skipped on macOS 27.0.1 arm64. `xcodebuild test`
  required execution outside the sandbox because its testmanagerd connection is denied inside it.
- UI tests: 27 passed, 0 failed, 0 skipped on macOS 27.0.1 arm64 using Xcode's signed test runner.
  The latest full run used sample data and did not touch real disks. It passed after updating the
  keyboard helper to target the application directly and hiding System Settings, which had been
  intercepting UI automation.
- A fresh full UI run on 28 October 2026 passed all 27 tests on macOS 27.0.1 arm64 using
  `/tmp/Relente-010-DerivedData`; no real disks were touched. Xcode emitted XCTest main-thread and
  display-rectangle automation warnings, but the test command exited successfully.
- The full assistant flow also passed as a focused UI test with `-classicControls YES`; it used
  sample data and completed Installer → Drive → Review → Creating → Done → Installer.
- The 341-test unit run includes owned-image cleanup and process-runner coverage: 341 passed, 0 failed.
  The runner detaches through the tested cleanup scope for success, failure and cancellation
  results. No real installer process or disk was used.
- After adding that smoke test, strict Swift format lint and `git diff --check` both passed.
- `xcrun swift-format lint -r --strict Relente RelenteHelper Shared RelenteTests RelenteUITests`:
  passed.
- Latest strict lint and universal Release build with signing disabled: passed. Xcode's Swift macro
  plugin also required the Release build to run outside the sandbox.
- A signed Xcode Debug build and all 26 UI tests passed using sample data.
- A real creation on the approved SanDisk completed before the Task 25 copy monitor was added.
  Afterward, read-only inspection measured the source and destination `SharedSupport.dmg` at
  18,386,308,006 bytes each. This confirmed the selected file pair and final size, not live
  feedback or bootability. A later run with the monitor reached 27% (5.11 GB of 18.39 GB) and was
  cancelled by the owner. A second run showed measured ETA values fluctuating from about 29 to 32
  to 27 minutes over 3:48; the owner stopped it at 11% (2.14 GB). After cancellation, the
  destination image measured 2,197,815,296 bytes; `iostat` reported 2.15 MB/s in its first sample
  and 0 MB/s in the next two, confirming writes stopped. Neither run verified completion or
  bootability. The 30-second estimator window and brief-burst resistance pass in the full unit
  suite. On 28 October,
  the current signed build showed 391 MB / 32 min at 0:49, 575 MB / 32 min at 1:09, and 783 MB /
  31 min at 1:31 (4%) on the SanDisk; the owner stopped that run at Copy. A later owner-approved
  run completed on the same SanDisk in 31 minutes. During that run the ETA moved from 31 min at
  0:52 to 29 min at 1:57 and 25 min at 4:52, then descended without upward jumps in the later
  samples (23 min at 8:17, 18 min at 12:26, 15 min at 15:26, 10 min at 20:23, 5 min at 25:18,
  and under one minute at 29:53). The resulting volume is mounted, `OS Can Be Installed: Yes`, and
  its `SharedSupport.dmg` matches the source at 18,386,308,006 bytes. Issue #41 records further ETA
  smoothing and a review of whether seconds should be shown.
  That earlier 341-test unit suite and 26-test UI suite, strict lint, signed Debug build and universal
  Release build with warnings as errors all passed. Complete creation and the resulting installer
  volume are verified on Apple silicon. Physical USB startup is outside feature 010; Intel
  validation is tracked separately in issue #40.
- Earlier UI-test runs timed out while macOS enabled UI automation or were intercepted by System
  Settings; the latest full 26-test run passed after resolving those conditions.
- After adding the output-lifecycle regression test, all 337 unit tests and all 26 UI tests passed.
  Strict lint and the universal Release build with signing disabled also passed.
- `codesign` CLI reports `CSSMERR_TP_NOT_TRUSTED` for platform-signed apps on this macOS build,
  including Chess and Calculator. The helper uses `SecStaticCodeCheckValidity`; a direct call to
  that API with Relente's `anchor apple` requirement returned success for both installed installer
  apps and their `createinstallmedia` executables. The CLI result was not evidence that those
  installers were untrusted.
- XPC/helper integration tests passed: `HelperRequestHandler` streamed typed progress through the
  production receiver and returned its terminal outcome; simulated connection loss cancelled the
  active creation and released the operation gate. Contract tests reject missing and outdated
  protocol versions. Focused runs passed; full unit and universal Release verification are rerunning
  after these changes.
- Final automated verification after the XPC changes: 343 unit tests and 27 UI tests passed with
  zero failures on macOS 27.0.1 arm64. Strict recursive swift-format lint and `git diff --check`
  passed. The universal Release build completed successfully with signing disabled; warnings are
  errors in Release. UI automation emitted XCTest main-thread debugger/automation runtime warnings,
  but all tests passed. The full XPC transport is exercised by the real creation history above;
  automated tests cover its production handler/receiver/reply boundaries with injected disk and
  process dependencies.
