# Implementation Plan: 011 · Installer acquisition

Spec: [spec.md](spec.md)

## Overview

Add Apple full-installer listing and downloads to the existing Installer step. Keep local
installer discovery and selection working without network access, model the download as a substate
of Installer, and use the existing installer reader and `/Applications` watcher to validate,
select, and retain completed downloads. Build with injected sample services so previews and tests
never access Apple's service or real disks.

## Architecture Decisions

- Add an `InstallerAcquisitionService` protocol separate from `InstallerService`. It owns catalog
  listing, starting a selected download, progress, and cancellation. Inject live and sample
  implementations through `Assistant`, following the existing service pattern.
- Add value models for Apple catalog entries and acquisition state. Preserve version and build
  metadata where available; use the existing `MacOSVersion` and `InstallerSource` models rather
  than creating parallel version or installer identities. Extend installer metadata reading only
  where needed to expose a build for exact matching.
- Implement the live service with `Process` targeting the fixed
  `/usr/sbin/softwareupdate` executable and argument arrays. Capture stdout and stderr directly;
  do not invoke a shell or add networking to the privileged helper. Parse reported progress and
  forward output lines to the unprivileged UI for a bounded, in-memory activity view.
- Treat Download as a substate inside `.installer`; do not add a footer step. Disable Back during
  an active download; cancellation is available only through the active item's Cancel control.
  Present an automatically opened, dismissible details sheet at download start; keep the task in
  `Assistant`, so dismissing and reopening the sheet never changes acquisition state. Keep Use and
  Continue decisions in `Assistant`, and present the state through a dedicated view.
- Coordinate normal quit through an AppKit application delegate attached to `RelenteApp`: defer
  termination while the service requests cancellation and awaits its available completion signal.
  CLI exit is not proof that a service-owned transaction ended; the final task decides whether the
  required guarantee is achievable.
- Reuse completed downloads through `LiveInstallerService` and its existing installer reader.
  Recheck local matches and `/Applications` destinations immediately before starting; never
  replace an occupied destination. Identify structurally incomplete Apple installer apps in
  `/Applications`; because Apple places these apps there as `root:wheel`, send one typed request to
  the existing helper after explicit confirmation. The helper derives the authenticated caller UID,
  revalidates the exact bundle, and moves it to that user's Trash. Preserve helper errors; never
  inspect or delete system-managed update caches.
- On successful process completion, re-read the resulting installer through the existing reader
  before adding and selecting it. Incomplete, ambiguous, failed, or cancelled results remain
  unavailable.
- Keep cancellation verification as the final feature task, as directed by the owner. The known
  SIGINT/SIGTERM trials stop the CLI but do not prove that `softwareupdated` stops or clears cached
  data. Do not claim full cancellation or mark the feature complete unless that final check passes;
  otherwise return for the owner's behavior decision.

## Task List

### Phase 1: Acquisition models and parser

- Define catalog entry, build identity, progress, result, and failure values.
- Add parsing for `--list-full-installers` output and reported download progress, with sample
  fixtures for distinct builds, missing metadata, malformed output, and indeterminate progress.
- Expose installer build metadata where the existing reader can reliably obtain it.
- Add focused unit tests for parsing, matching, and ambiguous candidates.

### Checkpoint: Acquisition model

- Models are `Sendable` and testable without SwiftUI or real Apple downloads.
- Exact version/build matching and incomplete metadata fail closed.

### Phase 2: Service and download lifecycle

- Add the service protocol and sample implementation; inject both through app composition.
- Implement the live catalog and download commands with fixed executable paths and argument
  arrays, direct output capture, duplicate-request prevention, and honest progress states.
- Add destination collision checks and recheck local matches immediately before a download.
- Verify the completed app through the existing installer reader and `/Applications` watcher.
- Add service tests for command output, success, unavailable versions, failures, duplicate
  prevention, local reuse, collisions, and incomplete results.

### Checkpoint: Service

- Local installer flows work with networking unavailable.
- Sample tests never launch `softwareupdate`; the live service never replaces or deletes an
  existing installer.

### Phase 3: Installer navigation and Download interface

- Add Download as an Installer substate and preserve the existing assistant step count and
  installer-before-drive order.
- Prefetch Apple's catalog in the background while Installer is open and reuse the in-memory list
  on entry. Retain the final service-side version/build/destination checks before acquisition.
- Build the four-column version grid with the newest version per macOS release family
  visible by default and older versions in a native sheet that reuses the artwork grid. Make each
  artwork and metadata group the Download/Use action and keep the title close to its version. Reuse
  the flow's `ProgressRing` around active artwork and show percentage and cancellation directly
  beneath that version. Open a native installer details sheet as the acquisition starts, even when
  the selection came from older versions; keep that older-version picker behind the details sheet.
  Allow dismissing the details sheet without cancelling and reopen it from the active item. Center indeterminate
  and cancellation feedback inside the progress ring, and disable Cancel while cancelling. Remove the separate
  download status panel. Place the ring/artwork on the left and installer metadata, status, and the
  shared circular Stop cancel control on the right. Use one Liquid Glass close control, a collapsible Activity section expanded initially
  with a fade-only collapse,
  and a single leading-aligned error callout without duplicate grid text while the sheet is open.
  Omit status text redundant with its spinner or percentage. Center
  left-align the older-version sheet header with the family name in bold and “Older versions” as a
  gray subtitle, while centering version/size rows. Mark a selected local match in Download as shared
  installer artwork so it travels into USB Drive on Continue. Replace the ring with an enlarged success badge
  when the download completes, using a scale/fade transition or a Reduce Motion crossfade. Use
  version-led artwork without an exact local icon, and match Installer's
  scroll-edge fade and insets with visible indicators. Add pointing-hand cursors to clickable items.
  Place a labeled Back control beside Continue and matching rounded X buttons at the top right of both sheets.
- Retain the last 100 softwareupdate output lines in memory and present them below the installer
  information in its download details sheet during acquisition and after failure. Overlay a retry
  symbol on the failed installer's artwork and retry that version when its item is activated; keep
  catalog refresh separate.
- Add keyboard and VoiceOver behavior, previews including classic controls, and English/Spanish
  strings.
- Add sample-backed UI coverage for populated and empty Installer states, Download navigation,
  Use, progress, cancellation display, and return to Installer.

### Checkpoint: User flow

- The flow reaches USB Drive only after one complete usable installer is selected.
- In Download, Continue is enabled only when the selected catalog version matches the currently
  selected complete local installer; a non-local row cannot reuse a stale local selection.
- The actual selected installer size continues to drive the existing capacity check.

### Phase 4: Integration, recovery, and product documentation

- Validate successful download detection, reuse after relaunch, and continued use by the existing
  creation flow without weakening helper security checks.
- Validate no-network, storage, collision, failure, interrupted-download and incomplete-installer
  recovery paths.
- Add one typed helper request limited to moving a confirmed, revalidated incomplete installer app
  from `/Applications` into the authenticated caller's Trash. Keep the existing strict app scan,
  final snapshot check, explicit confirmation, and active-download guard. Reject symlinks, complete
  apps, changed apps, non-installer paths, and unsafe Trash destinations.
- Preserve the helper failure and map it to a localized, actionable message. Test successful
  routing and rejection/failure paths; manually validate one root-owned incomplete installer and
  confirm it appears in the user's Trash. Never add a general-purpose file operation or touch
  system-managed caches.
- Keep the Download screen's incomplete-installer warning compact, without a count and with a
  text-only review action only after the catalog loads successfully, and open a native review sheet
  with Finder icons, app metadata, and per-item Trash actions; keep item-specific confirmation in
  that sheet.
- Update `docs/product.md`, README roadmap/capability notes, and BUILDING only where the shipped
  behavior requires it; update the spec index status when the feature is complete.
- Run the project-required unit/UI tests, strict swift-format lint, and universal Release build.

### Final task: Normal-quit cancellation verification

- On the available macOS 27.0.1 system, verify normal quit requests SIGINT/cancellation, waits for
  the CLI to exit, leaves no selectable partial installer, and determine whether the
  service-owned transaction stops. Do not remove data from a system-managed cache.
- If service cancellation cannot be established, stop before declaring the feature complete and
  return to the owner for a behavior decision. Do not infer a guarantee from CLI exit alone.
- Other supported macOS releases cannot be tested on the available machine; record this limitation
  in the final validation notes.

## Risks and Mitigations

- **`softwareupdate` output varies:** Parsing may misread versions, progress, or completion.
  Isolate the parser and fail closed on unknown output.
- **CLI exits but system work or cache remains:** Normal quit may not stop the transfer, and storage
  may remain used. Verify cancellation last; never clean the system cache; block feature completion
  if cancellation cannot be confirmed.
- **Build metadata is missing or ambiguous:** A wrong installer could be selected. Require one
  complete exact match or block the version.
- **Apple destination is occupied:** A download could overwrite user data. Recheck before starting
  and block occupied or ambiguous destinations.
- **Installer reader rejects the result:** An invalid source could reach drive selection. Re-read
  through `InstallerReader` before adding or selecting it.
- **App exits while a command is active:** Child process and app state may diverge. Coordinate
  normal quit; force quit and crash recovery fail closed.

## Rules Check

- Acquisition stays in the unprivileged app and uses a fixed executable with argument arrays. The
  helper API and its security rules stay unchanged. No shell, new executable, or third-party
  dependency is added.
- Services are injected with live and sample implementations; models remain `Sendable`; work is
  asynchronous without `DispatchQueue` or `Task.detached`.
- No third-party dependency, minimum macOS change, or CI/signing/release change is planned.
- New views require previews, localized strings, light/dark and Reduce Motion support, and HIG
  review. Tests, builds, and strict lint are required before implementation is declared complete.
- No plan task writes feature code until the owner approves this plan; no task breakdown is created
  until that approval.

## Open Questions

None before task breakdown. The final cancellation verification has a defined stop-and-return path
if the required guarantee cannot be established.
