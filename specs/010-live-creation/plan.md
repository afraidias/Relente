# Implementation Plan: 010 · Live installer creation

Spec: [spec.md](spec.md) · Tasks: [tasks.md](tasks.md)

> Owner-approved revision: preserve the existing Permissions design and drive presentation;
> require Full Disk Access and Background App Activity for live creation, with a helper-side
> non-destructive write probe as the gate at Review. Installer browsing and selection remain usable.
>
> Owner-approved amendment: measure the validated source/destination `SharedSupport.dmg` growth
> during Apple's silent Copy phase and present that measurement on the main Creating screen. Task
> 25 implements this behavior. A completed SanDisk run confirmed that the measured copy advanced
> to completion; issue #41 tracks further ETA smoothing and review of displayed time precision.

## Overview

Replace the Debug-only simulated creation with a typed helper operation that validates the
installer and confirmed removable drive, then runs Apple's signed `createinstallmedia`. That Apple
tool owns preparation and erasure; Relente must not call `diskutil eraseDisk` first. The app maps
the helper's real output to the existing Creating, Error and Done flow, verifies the resulting
volume before Done, and keeps command output in memory only for the current flow. The user selects
an installer before a destination so the drive screen can show whether it fits.

The step supports local `.app`, `.dmg` and `InstallAssistant.pkg` sources. Apple installer catalog
and downloads are separate roadmap step 9. The existing sample service continues to isolate
previews and UI tests from real disks and the helper.

## TCC investigation and revised execution decision

The current signed build launches `createinstallmedia` from the `SMAppService` root daemon. A
real run on macOS 27 erased the owner-approved test USB but failed to write `.IAPhysicalMedia` with
error 513. At the same time TCC reported that removable-volume authorization was unavailable for
the helper. The volume was writable and had enough space. A later app-side scoped write probe
succeeded while the helper operation still failed. macUSB documents Full Disk Access and
Background App Activity as requirements for its media creation workflow, noting removable-volume
access was insufficient on T2 and Apple silicon. The owner approved this permission model for
Relente. The helper's own probe remains the runtime gate for the selected USB.

Investigate the existing helper first. Apple's
[`NSRemovableVolumesUsageDescription`](https://developer.apple.com/documentation/bundleresources/information-property-list/nsremovablevolumesusagedescription)
documentation describes a user-controlled permission specifically for removable volumes. Apple's
[bootable installer guide](https://support.apple.com/es-es/101578) says Terminal may prompt for
access to a removable volume during `createinstallmedia`. An [Apple DTS discussion](https://developer.apple.com/forums/thread/802650)
describes a privileged helper inheriting removable-volume access after the GUI process triggers
the system access request. This is promising precedent, not proof for Relente's path. Apple's
[Full Disk Access guidance](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox)
describes a broad permission for access to files throughout the Mac. The owner chose this permission
after the scoped app probe failed to establish access for the helper. Relente documents macUSB's
published permission requirements but incorporates no macUSB source code.

### Implementation: helper-side Full Disk Access preflight

1. Add a typed XPC preflight that validates the confirmed disk fingerprint and mounted volume, then
   creates and removes a uniquely named temporary file without formatting or erasing.
2. Run the preflight after administrator authorization and before showing Creating or invoking
   `createinstallmedia`. If it fails, remain on Review and explain how to enable Full Disk Access
   and Background App Activity. Do not claim access based on the GUI app's own file probe.
3. Keep installer discovery/download and drive selection available when Full Disk Access is absent.
   Do not gate the entire app or use a checkbox as a substitute for the system setting.
4. Verify denial with injected services. Any real creation attempt still requires the owner's
   existing USB authorization; the preflight itself is non-destructive.

### Observed result on 27 October 2026

- On this macOS 27 Mac, the owner enabled Full Disk Access for `/Applications/Relente.app`, which
  had been disabled. The existing helper launched Apple's command against the approved SanDisk.
  An initial attempt was interrupted when an accessibility-tree query caused Relente to crash;
  the helper cancelled the child process on connection loss.
- A second attempt, without querying the live accessibility tree, ran for about 31 minutes.
  `createinstallmedia` exited with status 0, the helper returned success, and Relente showed Done.
  The resulting volume contained the installer app and `.IAPhysicalMedia`, with 18.5 GB used.
  A read-only `bless --info` query listed its EFI partition as a system partition. A real startup
  from that volume has not been tested.
- While the command was writing to the USB, Creating remained at 5%, displayed 0 copied bytes and
  estimated less than a minute. Those values did not describe the observed activity and duration.
  Preserve truthful unknown states and investigate actual output framing before changing parsing.
- Full Disk Access was returned to its original disabled state after the experiment. This one run
  shows a successful path with the permission enabled on this Mac; it does not establish whether
  that broad permission is necessary for every configuration, or which process identity received
  the effective authorization.

### Helper preflight denial verified on 27 October 2026

- Rebuilt and installed the signed Release app, then removed and reinstalled its system helper so
  the current app and helper both used protocol version 3.
- Left Full Disk Access disabled and Background App Activity enabled. Selected the 18.41 GB macOS
  27 installer and the approved 30.75 GB SanDisk, then confirmed the review screen.
- After the administrator authorization, the helper's temporary write check failed. Relente showed
  its Full Disk Access recovery alert and remained on Review. It did not start `createinstallmedia`
  or erase the USB. The review checkbox was cleared after the check; no privacy setting changed.
- The previously successful full creation with Full Disk Access enabled is still the evidence for
  the granted path. This run verifies the missing-permission gate, not a new granted-path creation.

### Helper XPC nonresponse observed on 27 October 2026

- A signed Debug build selected the real SanDisk and reached Review. Pressing "Erase and Create"
  left the action disabled without showing administrator authorization or entering Creating.
  `launchctl` showed the registered helper running, while both USB volumes remained unchanged.
- The app's protocol-version request had no deadline, so a helper that accepted the XPC connection
  but did not reply could leave the UI waiting indefinitely. Add one-shot reply completion and
  operation-specific deadlines: 10 seconds for protocol negotiation, 60 seconds for the harmless
  write check, 5 minutes for formatting and 90 minutes for installer creation. A missing reply
  invalidates the connection and logs the operation; Review and Error use existing recovery.
- The available certificate's display name contains `N5XTMFH66L`, but its certificate `OU` is
  `99TLZFAX53`. Keep app and helper requirements matched to the `OU`; Xcode builds outside the
  sandbox when passed the certificate's exact SHA-1 identity.
- Unit tests cover immediate response, timeout, ignored late response and Review recovery. The
  full unit suite, strict swift-format lint and universal Release build pass. No physical creation
  was attempted after the XPC change.

### Implementation after the experiment

- Keep the root helper's typed API, independent disk and fingerprint checks, Apple signature checks,
  and fresh erase authorization. Do not add a shell, arbitrary command API, or deprecated
  privilege-elevation API to bypass these safeguards.
- Remove the GUI app's scoped Removable Volumes probe. The helper's harmless write probe is the
  access gate after fresh authorization and before any destructive operation. Failure leaves Review
  visible with directions to enable Full Disk Access and Background App Activity.
- Verify denied, revoked and changed-disk paths before destructive work where detection is
  possible; clearly report an incomplete volume when access is denied after erasure. Update the
  Permissions and Error screens, English/Spanish strings, product and security documentation,
  sample-backed UI checks and focused service/security tests to match the proven approach.
- Investigate the accessibility recursion using sample data and a reproducible accessibility
  traversal, then fix it while retaining usable VoiceOver labels. Capture representative Apple
  output safely and fix progress/remaining-time handling without inventing bytes or estimates.
- Preserve the current Permissions hero, status, authorization callout and footer. Explain the
  helper, Full Disk Access and Background App Activity. Do not block browsing or installer/drive
  selection. Never read or mutate TCC's private database. The Review preflight decides whether the
  selected operation can proceed and gives recovery guidance when it cannot.
- Keep the creation view and footer spacious. Use a standard, nonmodal popover anchored to the
  Activity button, explaining that it shows recent creation steps and progress. Give it one direct,
  clearly labelled action for the complete technical log; open that log in a larger, nonmodal
  window. Do not toggle technical text inside the narrow popover. Close the popover with Escape or
  clicking outside; keep the running operation and in-memory history alive. Preserve an accessible
  Cancel action and avoid nested scrolling regions.
- Track elapsed time with a monotonic clock and animate its digits. Do not continuously sample the
  selected disk's `IOBlockStorageDriver` counter or display approximate whole-device throughput;
  it cannot tell the user how many installer bytes were copied. The owner-approved SanDisk run
  already compared Relente's temporary write-rate sample with system device statistics and
  confirmed the Toshiba had no writes. Installer bytes copied and remaining time stay unknown
  unless `createinstallmedia` provides meaningful measurements.
- If no supported path preserving all helper security rules is demonstrated, stop implementation
  and bring the evidence back for a revised spec and plan. Do not silently weaken the rules.

## Architecture Decisions

- Extend the shared XPC contract with typed creation request, phase/progress, timestamped output,
  cancellation and terminal result values. Output travels helper-to-app only. Keep fixed
  executable paths and argument arrays; add no shell, generic command API or networking.
- Keep the helper authoritative for fresh erase authorization, disk eligibility and fingerprint
  revalidation, installer and executable Apple-signature validation, process launch, cancellation
  and cleanup. Do not run the existing disk-format pipeline as a separate pre-step.
- Serialize one active creation operation. Validate the source before authorizing/destructive
  work where practical, then revalidate the selected disk immediately before launching
  `createinstallmedia`; check signatures again immediately before execution. Unknown command output
  cannot imply success. The app verifies the resulting volume before showing Done.
- Reuse existing creation models/services and sample implementations where their contracts fit.
  Keep progress values `Sendable`, inject process, signature, mount and verification boundaries,
  and make operation state actor-isolated. No `DispatchQueue` or `Task.detached`.
- Mount disk images read-only and hidden. Track mount ownership and detach only mounts created by
  this operation on every terminal path.
- For `InstallAssistant.pkg`, pass its selected URL to the helper. The helper copies it to a
  root-owned mode-0700 directory, checks that copy with `/usr/sbin/pkgutil --check-signature`, then
  expands the copy with the fixed `/usr/sbin/pkgutil --expand-full` operation. Never install it or
  run its scripts. Accept only Apple's trusted Software Update signer and certificate chain. Link
  `SharedSupport.dmg` into the extracted app and use only this helper-owned extraction. This binds
  the package signature to the resources used for creation and prevents same-user replacement
  after validation without staging a second full package copy in the app. Retain Apple-anchor code
  validation and full executable validation; skip only the legacy app resource envelope check for
  the helper-owned extraction. Remove the temporary directory on every terminal path.
- Keep timestamped output in memory for the active creation only. Show recent activity in the
  selected popover and offer full output when needed; Error retains the final activity. Never
  persist a log.
- Bound reply-bearing helper requests with operation-specific deadlines: 10 seconds for protocol negotiation,
  60 seconds for the harmless volume-write check, 5 minutes for formatting, and 90 minutes for
  `createinstallmedia` (the observed full run took about 31 minutes). On timeout, complete the
  request once with failure, invalidate the XPC connection, and log the operation and timeout.
  Keep raw connection details in logs; the UI uses the existing helper-unavailable or creation
  failure recovery path. Keep one-way cancellation fire-and-forget.
- Preserve the existing Permissions composition and drive screen visuals, including icons. Keep
  the four-step navigation and main Creating geometry; use the Activity popover without resizing
  the window. Localize in English and Spanish and provide VoiceOver and Reduce Motion behavior
  with sample-backed previews/tests.

## Task List

### Phase 1: Source and protocol boundaries

- Inspect current helper/XPC, creation services/models, installer sources, progress UI and build
  target membership before adding files; record the smallest compatible interface changes.
- Prove `pkgutil --check-signature` and `pkgutil --expand-full` behavior on a representative
  Apple `InstallAssistant.pkg` without installing it. Verify the extracted app, its
  `SharedSupport.dmg`, the `createinstallmedia` Apple signature, and the legacy resource-envelope
  behavior. Then verify private-directory permissions/cleanup and rejection of unsafe paths. Do not
  use a user package as a test fixture; use controlled fixtures or injected process results.
- Evidence: the representative Apple package was expanded without installation or scripts; its
  Apple Software Update chain, extracted app, SharedSupport hard-link behavior, legacy resource
  envelope and `createinstallmedia` signature were inspected. Security review found that checking
  the app-owned extraction did not bind those resource bytes to the signed package or prevent a
  same-user replacement. The helper now copies, verifies, and expands the selected package itself
  into one root-owned private directory before it may use the package resource exception. Unit
  tests cover signature parsing, preparation/cleanup, source provenance, signature-check policy
  and extraction ownership requirements.
- Define typed XPC creation request, progress/output events, cancellation and terminal outcome.
  Preserve protocol versioning and existing code-signing requirements.
- Define an exactly-once reply gate with a cancellable operation-specific timeout; test immediate
  replies, unanswered requests and late replies. Use it for helper calls without putting timeout
  logic on the main actor or giving long-running creation the short handshake deadline.

### Checkpoint A: Safe source and contract

- [x] Package preparation is demonstrated without host installation. The owner approved the
  package-signature trust model for the legacy app bundle resource envelope; implementation tests
  must still cover signature rejection, extraction cleanup and unsafe paths.
- [x] XPC surface remains typed and narrow; output is one-way and the contract has no generic
  process or network operation.
- [x] Existing helper security rules and app/helper trust requirements remain intact.

### Phase 2: Preflight, media preparation and progress parsing

- Add installer preflight for direct app sources and locate the fixed `createinstallmedia` path;
  reject unsupported or malformed input, symlinks and invalid Apple signatures before erasure.
- Add an owned, read-only disk-image mount scope and package preparation using the resolved
  fixed-method decision. Ensure each produces a validated installer app URL for the helper.
- Parse pseudo-terminal output into typed phases, optional percentages and timestamped plain-text
  output. Missing, unknown or reordered lines stay truthful and can never indicate success.

### Checkpoint B: Source safety and parser

- [x] Tests cover signature/preflight failures, missing executable, symlink rejection and source
  preparation cleanup.
- [x] Disk-image cleanup detaches operation-owned mounts on success, failure and cancellation but
  preserves mounts it did not create.
- [x] Parser fixtures cover supported output forms, unknown/reordered lines, missing percentages,
  large output volume and terminal error output.

### Phase 3: Helper creation operation

- Add a cancellable pseudo-terminal runner for the validated fixed `createinstallmedia` executable
  with `--volume` and `--nointeraction` arguments.
- Orchestrate fresh authorization, disk eligibility/fingerprint checks, installer preflight and
  immediate signature recheck before launch. `createinstallmedia` performs its own preparation
  and erasure; there is no separate `diskutil eraseDisk` call.
- Stream typed progress and timestamped output to the app. Handle operation serialization,
  cancellation, XPC disconnect, non-zero exit and cleanup. A successful process exit is necessary
  but not sufficient for app-level Done; volume verification follows in the app.

### Checkpoint C: Helper behavior

- [x] Fake-driven tests prove security-check ordering and cover authorization failure, changed or
  disconnected disk, invalid installer, signature changes, command failure, cancellation,
  disconnect and success.
- [x] No test launches the real destructive command; no shell, generic command runner or network
  access is introduced.

### Phase 4: App flow and screens

- Replace the live service's simulated creation events with the helper stream; retain deterministic
  sample services for previews and UI tests.
- Add truthful phase state and optional progress mapping; keep output scoped to the current run and
  clear it when the flow ends or restarts. Before the first parsed `createinstallmedia` update,
  label the helper-side source validation/preparation without claiming the USB is already erasing.
- During Apple's silent `Copying essential files...` phase, measure the validated source and
  destination `SharedSupport.dmg` sizes through the helper's typed XPC progress callback. Show the
  measured image bytes and progress on Creating; derive remaining time only after stable samples.
  Fall back to a clearly labelled indeterminate state when either file cannot be matched safely.
  Keep Activity focused on phases, errors and the technical log.
- Add the compact Activity popover, final Error events and a full-output view for long logs; keep
  technical text selectable, accessible and non-persistent.
- Update installer-first selection flow and show whether the selected installer fits each drive.
  Review Installer, Drive, Review, Creating and Error layouts for clear feedback throughout.
- Gate Done on successful helper completion and resulting-volume verification. Route cancellation
  and errors through the existing recovery flow; tell the user when erasure may have started.
- Update English/Spanish strings, previews and sample-driven UI coverage; check light/dark,
  VoiceOver, Reduce Motion and classic controls.

### Checkpoint D: App behavior

- [x] Unit tests cover mapping, parsing, output lifetime, verification gate, cancellation and
  failure routing.
- [x] UI test uses sample services only and follows installer → drive → review → create → done,
  plus representative error and cancellation paths.
- [x] Creating geometry and breadcrumb position stay fixed; VoiceOver and Reduce Motion behavior
  are checked.

### Phase 5: Product integration and release readiness

- Update `docs/product.md`, README, SECURITY.md and BUILDING.md if the shipped behavior or helper
  setup changes; update the spec index and mark the spec Done only in the feature's final PR commit.
- Complete the project quality gates from AGENTS.md: unit/UI tests, strict swift-format lint,
  Debug build/tests and universal Release build with warnings as errors. Do not weaken tests or
  rules to pass.
- Perform an owner-confirmed real-drive run on Apple silicon, including cancellation and post-run
  volume verification (`OS Can Be Installed: Yes`). Intel validation is tracked separately in
  issue #40; physical USB startup is outside feature 010's scope.

### Checkpoint E: Definition of Done

- [x] Spec acceptance criteria and the AGENTS.md Definition of Done are met, or explicitly recorded
  as open items in the spec.
- [x] Manual verification confirms the created installer volume on Apple silicon. Intel validation
  is tracked separately in issue #40, and physical USB startup is outside this feature's scope.
- [x] Product docs, spec index and status match the current approved behavior; the spec stays
  Approved until the final PR commit, per AGENTS.md.

## Risks and Mitigations

| Risk | Impact | Mitigation |
| --- | --- | --- |
| `createinstallmedia` output varies by macOS release | High | Parse defensively; optional percentages; unknown output never means success; keep captured fixtures and manual verification. |
| Package expansion layout or signature semantics differ from assumptions | High | Prove the fixed `pkgutil` method before implementing package support; reject symlinks and validate extracted app/executable in helper; revise scope if proof fails. |
| A later failure leaves an erased or partially written drive | High | Explain the destructive phase, preflight source first, revalidate disk and signatures, report recovery state accurately, and never show Done after failure. |
| Cancellation races process exit, XPC disconnect or image cleanup | High | Serialize one operation, make cancellation idempotent, scope resources to operation ownership, and test all terminal paths with injected boundaries. |
| XPC callbacks and Swift 6 isolation cause lifetime or concurrency bugs | Medium | Use `Sendable` payloads, actor-isolated operation state and deterministic injected tests. |
| Volume verification does not prove physical startup on every hardware configuration | Medium | Define Verify by mounted volume contents and macOS's `OS Can Be Installed` result; physical startup is outside 010. Intel validation is tracked in issue #40. |
| GUI app's removable-volume grant does not reach the daemon or Apple child process | High | Probe from the GUI app, inspect TCC attribution, test real creation, and do not ship the path until the relevant process identities are verified. |
| A scoped grant cannot be established before erase | High | Stop before destructive work and return with evidence; do not silently fall back to Full Disk Access. |
| An installer version does not expose a safe, matching `SharedSupport.dmg` at the source and target | Medium | Report measured copy progress only for a validated regular-file pair; otherwise keep the existing truthful indeterminate fallback. |

## Rules check

- **Helper security:** preserves all six AGENTS.md rules; the helper has typed operations only,
  fixed paths/argument arrays, mutual code-signing validation, independent disk checks, Apple
  signature validation, fresh authorization, no networking, `os_log`, and remains uninstallable.
- **Architecture:** injected service protocols and sample/live implementations; value models are
  `Sendable` and `Equatable`; shared state uses `@Observable`; heavy work stays in services; no
  `DispatchQueue` or `Task.detached`.
- **Platforms:** no deployment-target, signing, CI or dependency changes; gate APIs newer than
  macOS 14; preserve universal arm64 and x86_64 Release builds.
- **UI:** macOS HIG, screen-specific `#Preview`s, English/Spanish catalog strings, VoiceOver,
  Reduce Motion, light/dark and classic-control checks.
- **Quality:** run the existing required build, test and lint gates before saying the implementation
  works. Tests and previews never use real disks.
- **Workflow:** work stays on `feature/010-live-creation`; no commit, push, PR or merge without the
  owner's explicit request.

## Open Questions

- Which process identity received the effective access in the successful run, and can a narrower
  permission support the same flow on the supported macOS versions?
- Supported Apple package signer identities may change; reject unrecognized chains and update
  controlled fixtures when Apple changes the package format.
