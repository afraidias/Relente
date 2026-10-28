# 010 · Live installer creation

**Status:** Done · **Roadmap step:** 7 · **Branch:** `feature/010-live-creation`

## Objective

Replace simulated creation with Apple's signed `createinstallmedia`, orchestrated entirely by
Relente through an execution and authorization path macOS permits to write removable volumes. Show
honest progress through preparation, erasure and copying. The user selects an installer before a
destination so Relente can compare the installer's size with available USB and SD cards. This
roadmap step covers using an already available installer; Apple's installer download flow is
tracked separately for roadmap step 9 in the capability map in `specs/README.md`.

## Behavior

### Prepare and create

- The user selects an installer before selecting a USB or SD card. The drive screen shows whether
  the selected installer fits each eligible drive before Review.
- Review remains the final confirmation. Every real erase still requires fresh administrator
  authorization through the helper, which revalidates the selected disk and its fingerprint.
- Before erasing, Relente validates the installer and Apple's signed `createinstallmedia` against
  Apple's signing anchor. It repeats the signature check immediately before running the executable.
- After authorization and validation, Relente starts the installer's signed `createinstallmedia`
  with fixed executable paths and argument arrays, attached to a pseudo-terminal. The execution
  context must be one macOS allows to write the selected removable volume under its TCC policy; a
  privileged daemon with no logged-in user authorization must not be assumed to have that access.
  The exact process boundary is decided in the approved implementation plan. Apple's command
  prepares and erases the destination as part of its own flow; Relente does not run
  `diskutil eraseDisk` first. It reports phases and percentages present in the command output and
  forwards timestamped output lines to the app. During Copy, when the validated source installer
  and destination expose the same regular `SharedSupport.dmg`, the helper also reports the
  destination file's measured byte size against the source file size. This provides real copy
  progress even while Apple's command is silent. If that measurement is unavailable or unsafe,
  progress remains indeterminate; Relente does not infer bytes from device throughput.
- Before any real erase, verify from the process that will write the USB that macOS permits it to
  write the selected volume. macUSB's documented workflow requires Full Disk Access and Background
  App Activity, and the scoped Removable Volumes probe in Relente's unprivileged app did not prove
  access for the root helper or Apple's child process. If the helper's harmless write probe fails,
  leave the user on Review, do not begin `createinstallmedia`, and explain how to enable Full Disk
  Access and Background App Activity. The user may browse Relente and select/download an installer
  without Full Disk Access; the permission is a hard gate before creation. Do not replace the OS
  permission with a checkbox.
- Before `createinstallmedia` reports its first phase, the Creating screen says the installer is
  being prepared; it does not claim the USB is already being formatted. It then distinguishes
  preparation/erasure from copying based on actual command output. It names the selected USB, asks
  the user to keep it connected, and shows the measured primary installer image bytes and a
  progress bar during Copy when available. A remaining-time estimate appears only after enough
  measurements establish a useful rate. Otherwise it shows a clear copying status with an
  indeterminate indicator and no empty numeric placeholders. No simulated progress is shown.
- Creating and Error have an **Activity** button that opens a compact, nonmodal popover anchored to
  the button. The main window does not resize; macOS positions the popover within the available
  screen. Clicking outside or pressing Escape closes it without affecting the operation or losing
  activity. The popover explains that it shows recent phase changes and errors, then
  offers one clearly labelled action to open the complete technical log in a larger, nonmodal
  window. Technical output is not shown in a narrow popover. Error retains the run's final activity
  and recovery information. The app keeps the lines in memory only until the creation flow ends; it
  does not save a log file or add a helper input channel.
- While formatting or preparing the drive, show the current known action and elapsed time; hide the
  copied amount and later phase bar until Copy begins. Show
  a percentage, copied amount or remaining estimate only when supported by a reliable measurement;
  unknown values are identified as unknown or calculating rather than zero. Do not display a device
  write rate: whole-device throughput is approximate and can be confused with installer bytes
  copied. A live process or an animated indicator alone does not prove disk activity.
- Keep the existing Permissions screen's header, app-icon hero, status, authorization callout and
  footer. Briefly explain that the helper performs the privileged operation on the chosen drive
  after administrator authorization. Explain that Full Disk Access and Background App Activity are
  required for live creation in the current helper workflow; keep both distinct from helper
  approval and per-erase administrator authorization. Do not block installer browsing/downloads;
  block the final create action until the helper confirms it can write to the selected USB.
- Keep the existing drive-selection visuals and drive icons. The installer-fit information
  already in scope remains; redesigning drive icons is outside this feature.
- The assistant verifies that creation completed and that the resulting volume contains the
  installer, then shows the existing Done screen without a simulation label.
- If preparation, copying, or verification fails, the existing Error screen explains the reason
  and recovery action. Cancelling stops the active helper operation; once `createinstallmedia`
  begins erasing, the drive may be unusable until another creation attempt.
- Each reply-bearing helper request has an operation-appropriate deadline; the one-way cancel
  message remains fire-and-forget. If the helper does not reply, Relente invalidates that XPC
  connection, records the operation and timeout in its helper log, and returns through the existing
  recovery path. In particular, helper startup/version checks must not leave Review disabled
  indefinitely; no raw XPC diagnostic is shown to the user.
- Once the real creation service is available in Release, "Erase and Create" is enabled there.

### Installer sources

- Support the installer app directly.
- Support a disk image by mounting it read-only and hidden in the helper, using the installer app
  inside it, and detaching it after use.
- Support an InstallAssistant.pkg, which spec 007 deferred to this roadmap step. The privileged
  helper copies the user-selected package into a root-owned mode-0700 temporary directory, checks
  that copy's signature with `/usr/sbin/pkgutil --check-signature`, and expands it with the fixed
  `/usr/sbin/pkgutil --expand-full` command; it never installs the package or runs its installation
  scripts. Accept only Apple's trusted Software Update package signer and certificate chain. The
  helper-owned extraction binds the verified package payload to the resources used for creation
  and prevents the logged-in user from replacing them after validation.
  The helper independently validates the extracted installer app and the
  `createinstallmedia` executable against Apple's signing anchor immediately before execution.
  For Apple packages whose app bundle has a legacy resource envelope rejected by current macOS,
  the helper may skip only bundle-resource validation after verifying the package signature; it
  still validates the app's signed code and all executable signatures. Relente creates the
  package's expected `Contents/SharedSupport/SharedSupport.dmg` hard link inside the private
  extraction, rejects unsafe paths, and removes temporary files on every terminal path.
- Reject symbolic links and reject installers or executables that fail Apple's signature check.

### Interface and accessibility

- Preparation/erasure and Copying are visual states inside step 4, not new assistant or breadcrumb
  steps. While formatting, show one focused progress bar and only the elapsed-time figure; show
  the copied amount and four-phase bar once the installer copy begins. Activity keeps the
  principal layout spacious and its controls usable at supported display sizes, with no clipped
  content or obstructed critical actions.
- Show phase progress from `createinstallmedia`; during silent Copy, use the validated
  `SharedSupport.dmg` file-size measurement described above when available. Fall back to a clear
  indeterminate state when no reliable measurement exists.
- Review the Installer, Drive, Review, Creating, and Error screens for the updated flow and feedback.
  Each state tells the user what is happening and what action, if any, is needed next.
- Add English and Spanish strings. VoiceOver announces the preparation/erasure and copying status changes;
  Reduce Motion uses the existing crossfade behavior.

## Changes to earlier features

- **Spec 003 (Review):** "Erase and Create" becomes available in Release after its existing
  confirmation and authorization flow.
- **Spec 001 (Installer screen):** installer selection is the first step; local installers are
  available here, while Apple's download catalog is a later roadmap step.
- **Spec 002 (USB drive screen):** shows fit information for the selected installer before the
  user chooses a destination; its existing appearance and icons remain unchanged.
- **Spec 004 (Creating screen):** preparation/erasure and copying become distinct visual states within the
  same step; real helper progress replaces simulated phases, and nonmodal Activity details replace
  the inline Details disclosure.
- **Spec 007 (Real detection):** `.dmg` and `InstallAssistant.pkg` sources can be used to create
  the bootable installer, completing its roadmap step 7 open item.
- **Spec 008 (System helper):** explain the helper's role and the Full Disk Access and Background
  App Activity requirements in
  Permissions. Retain the helper's narrow, typed role in authorization and disk
  revalidation, and add only the operations needed for live creation, progress, timestamped output
  and cancellation. Keep all existing helper security rules. The selected execution boundary for
  `createinstallmedia` must also preserve macOS TCC access to removable volumes. Use a new launchd
  label because macOS retained a stale Background Task Management record for the previous label
  after repeated local registrations. Preserve the app and helper's mutual code-signing Team ID
  `99TLZFAX53`, which matches the `OU` in the owner's installed Apple Development certificate.
  Require a successful harmless helper-side write probe before creation.

## Acceptance criteria

- [x] The helper revalidates the disk and compares the confirmed fingerprint before invoking
  `createinstallmedia`; it requires the existing fresh erase authorization.
- [x] An invalid or unsupported installer is rejected before the disk is erased.
- [x] The helper checks Apple's signature on the installer and `createinstallmedia` immediately
  before execution; it rejects symbolic links.
- [x] `createinstallmedia` runs in an execution context macOS permits to write the selected
  removable volume under TCC; the app does not rely on root privileges alone for this access.
- [x] Full Disk Access and Background App Activity are explained in Relente. The helper's typed
  write preflight runs before creation; if it fails, the user remains on Review and the USB is not
  erased. A later access failure has a distinct recovery action and warns that the drive may have
  been erased.
- [x] The helper exposes only typed operations with fixed executable paths and argument arrays;
  it adds no shell, generic command runner, or network access.
- [x] Disk images are mounted read-only and hidden for use, then detached on success, failure, or
  cancellation.
- [x] `InstallAssistant.pkg` is copied into private temporary storage and its copied package
  signature is checked before expansion. Only Apple's trusted Software Update signer and chain are
  accepted. The package is expanded without installation scripts; its signature authenticates
  resources. The helper validates the extracted app's code and `createinstallmedia` against Apple.
  It may skip only legacy bundle-resource validation when a trusted Apple package signature covers
  those resources. The package's `SharedSupport.dmg` is hard-linked to its expected app location.
  No installer executable or resource is allowed to come from outside the verified package. All
  temporary files are removed on success, failure, or cancellation.
- [x] The helper reports real `createinstallmedia` progress through XPC and can
  cancel the currently running operation.
- [x] macOS resolves and starts the bundled helper through `SMAppService`, and the app completes
  an XPC protocol-version request before any disk operation.
- [x] Every reply-bearing XPC request is bounded by an operation-appropriate deadline. A helper
  that accepts a connection but never replies cannot leave the app stuck; the connection is
  invalidated and the timeout is logged without exposing raw diagnostics in the UI. Cancellation
  remains a one-way message.
- [x] Activity opens as a compact popover anchored to its button without resizing the main window;
  it dismisses using Escape or a click outside without affecting the operation. It presents observed
  events and access to selectable technical output, including on Error; it stays within the screen,
  remains keyboard and VoiceOver accessible, and does not crash during accessibility traversal.
- [x] Output lines remain in memory only for the current creation and are not written to a file.
- [x] The Creating step shows actual preparation/erasure and copying phases from
  `createinstallmedia`; silent Copy uses measured `SharedSupport.dmg` byte growth where safely
  available and a clear indeterminate fallback otherwise. Elapsed time is shown; remaining time
  uses a stable measured rate or an explicit unknown/calculating state. The screen does not display
  whole-device write throughput or empty numeric placeholders.
- [x] Permission setup retains the existing screen design and explains the helper, Full Disk Access
  and Background App Activity. Installer browsing/download and drive selection remain available
  without Full Disk Access. Before any destructive work, the helper proves it can write to the
  selected volume; failure blocks creation on Review, causes no erase, and presents recovery
  guidance. No manual acknowledgement substitutes for macOS permission.
- [x] The existing drive-selection design and icon assets remain unchanged; installer-fit feedback
  continues to identify drives that are too small.
- [x] The app handles missing progress percentages and command output that differs from the
  expected phase order without getting stuck or showing false completion.
- [x] Success is shown only after the resulting USB volume passes the Verify check.
- [x] Failures and cancellation use the existing recovery flow and never report the drive as
  ready.
- [x] Unit tests cover progress parsing, phase changes, errors, cancellation, and helper security
  checks. UI tests use sample data and never touch real disks.
- [x] A manual real-drive run verifies creation, cancellation, and the resulting installer volume
  on Apple silicon. Confirm the volume is mounted, contains the expected installer and reports
  `OS Can Be Installed: Yes`; physical startup testing is outside this feature's scope. Intel
  validation is tracked separately in issue #40.
- [x] New UI strings are localized in English and Spanish; preparation/erasure and copying status is accessible
  with VoiceOver and Reduce Motion.

## Boundaries

- The helper keeps the security rules in `AGENTS.md` and `SECURITY.md`; this feature adds no
  general command API or networking.
- Command output is sent one way from helper to app as text; it never becomes a helper request.
- Tests and previews never erase real drives. A real-drive test is manual and explicitly confirmed
  in the app.
- Completion notifications (issue #19) remain a separate idea, outside this feature's scope.
- Downloading installers from Apple remains roadmap step 9; this feature does not implement the
  existing "Download from Apple…" control.

## Edge cases

- The selected disk is disconnected, replaced, or changes fingerprint before creation: refuse
  the request or report the existing disk-changed/disconnected error.
- The installer or `createinstallmedia` is moved, replaced, damaged, or unsigned: fail before
  erasing whenever preflight can detect it, and fail safely if the second signature check detects
  a change.
- The disk image is already mounted: use the existing mount without detaching a mount Relente does
  not own.
- Package signature validation or preparation fails, or the package has no supported installer app:
  fail before creation and remove the operation's temporary directory.
- `createinstallmedia` emits no percentage for a phase: measure silent Copy from the validated
  source and destination `SharedSupport.dmg` when possible; otherwise keep a truthful indeterminate
  state.
- The operation is cancelled after erasure starts: report that the USB may be unusable; do not show
  Done.
- The command emits many output lines: retain them only for the current creation, keep Activity
  scrollable, and show recent lines on Error without clipping the window.
- macOS denies access to the removable volume: identify the blocked access, do not report success,
  and explain whether the selected volume may have been erased or left incomplete.

## Decisions

1. **Preparation/erasure and copying states inside one Creating step.** This makes the destructive
   phase visible and distinguishes it from copying without changing the four-step flow or moving
   the breadcrumb.
2. **Progress uses measurements, not guesses.** Use Apple's reported phase and percentage where
   available. During silent Copy, measure the destination `SharedSupport.dmg` against the
   validated source file when both are safe to inspect. Derive a remaining-time estimate only
   from a stable measured byte rate. If no reliable measurement exists, show an indeterminate
   state with a clear status; never invent progress or use whole-device throughput.
3. **No artificial minimum display time.** A short format can transition quickly; the UI does not
   delay the actual operation just to hold the screen.
4. **Preflight before erase and recheck before execution.** This avoids erasing a drive for an
   invalid installer and still meets helper rule 4 immediately before running it.
5. **Prepare `InstallAssistant.pkg` in Relente without installing it.** Apple's documented command
   line flow installs the package's app into `/Applications` before running `createinstallmedia`
   ([Apple Support](https://support.apple.com/en-ca/102662)). The helper verifies and expands a
   root-owned private copy of the selected package without running installer scripts. It uses only
   that extraction, which binds the signed package payload to the resources consumed by
   `createinstallmedia` and prevents same-user replacement after validation. The helper validates
   the extracted app code and `createinstallmedia`; only an obsolete bundle-resource envelope may
   be skipped for this root-owned extraction.
6. **Show command output in temporary Activity details.** The lines help explain slow progress
   and failures, while keeping logs out of persistent storage and preserving the helper's one-way,
   typed interface. This includes [issue #20](https://github.com/afraidias/Relente/issues/20).
7. **Use in-bundle Service Management association.** The helper plist omits the legacy
   `AssociatedBundleIdentifiers` key; macOS associates an in-bundle `BundleProgram` with its parent
   app automatically.
8. **Give the daemon a fresh Service Management identity.** Repeated development registrations
   from different app copies left stale Background Task Management records; `launchd` then failed
   to resolve the otherwise-correct bundle-relative `BundleProgram` with `EX_CONFIG`. A new plist
   filename, launchd label and Mach service name let Service Management create a clean record
   without resetting system-wide background items. The helper's code-signing identifier remains
   tied to its executable, not its Mach service name.
9. **Accept Apple's installer signature format.** Direct installer apps and
   `createinstallmedia` are validated against the Apple anchor with `SecStaticCodeCheckValidity`.
   Some Apple InstallAssistant packages have a valid Apple package signature but use a legacy app
   resource envelope that current macOS rejects. For that source only, the helper rechecks and
   expands a trusted package copy in a root-owned private directory. It may omit resource validation
   for that helper-owned app bundle while continuing to validate its signed code and validating
   `createinstallmedia` normally.
10. **Treat removable-volume TCC access as a creation requirement.** A real run showed
    `createinstallmedia` failing to create `.IAPhysicalMedia` with Cocoa error 513 while macOS's
    TCC logs reported an unavailable `kTCCServiceSystemPolicyRemovableVolumes` authorization for
    the root launchd helper, which has no logged-in user audit identity. `diskutil info` confirmed
    that the destination was mounted read-write with sufficient free space. Therefore root
    authorization and a writable mount do
    not establish that the command can write the volume. The app-side scoped probe also succeeded
    without granting access to the helper, so the approved implementation uses Full Disk Access and
    a helper-side write preflight before creation.
11. **Present activity without blocking or crowding creation.** The owner selected a compact
    popover anchored to the Activity button after reviewing alternatives. It provides a readable
    sequence and a single, explicit action for the complete technical log, which opens directly in
    a larger window. Keeping the technical text out of the popover prevents the narrow view from
    clipping it and removes the ambiguous switch between "activity" and "technical output".
    It preserves the main window layout; a macOS sheet is modal and is reserved for short decisions
    such as confirming cancellation. Use an indeterminate indicator when progress is unknown, in
    accordance with Apple's [popover guidance](https://developer.apple.com/design/human-interface-guidelines/popovers),
    [progress guidance](https://developer.apple.com/design/human-interface-guidelines/progress-indicators)
    and [sheet guidance](https://developer.apple.com/design/human-interface-guidelines/sheets).
12. **Keep the current Permissions and drive designs.** Extend the existing Permissions screen
    with helper context and the access guidance supported by the proven flow. Keep the existing
    drive visuals and icons; a future exploration may use Apple-provided icons or Icon Composer.
13. **Gate live creation on the helper's actual write access.** A GUI-app removable-volume probe
    succeeded while the root helper and Apple's child process still failed with error 513. The
    owner approved Full Disk Access and Background App Activity after reviewing macUSB's documented
    workflow. Relente therefore keeps browsing and drive selection available, then runs a harmless
    helper-side write probe at Review and blocks before erasing if access is unavailable. This is a
    requirement for Relente's current helper architecture, not a claim that Apple requires Full
    Disk Access for every USB creation app.

## Open questions

## Open items

- **Roadmap step 7, before release:** verify Full Disk Access/TCC behavior on the other supported
  macOS versions. On macOS 27, TCC's unified log identifies the denied removable-volume request as
  `com.afraidias.Relente.Helper` running as root (`auid=0`, `euid=0`); TCC returned no
  authorization. With Full Disk Access disabled, the helper preflight blocked before erase. With it
  enabled for Relente, the owner-approved SanDisk creation completed. This confirms the helper
  identity and permission behavior on the validation Mac, but not whether other macOS versions
  attribute or require access the same way. The runtime preflight remains the safety gate.
- **Roadmap step 8:** Intel validation is tracked separately in issue #40 and is outside the scope
  and release criteria of feature 010.
- **Roadmap step 7, separate idea:** completion notifications (issue #19).
- **Roadmap step 9:** showing Apple-compatible versions and downloading installers from Apple,
  avoiding duplicate downloads and retaining completed downloads for reuse (see capability map in
  `specs/README.md`).
