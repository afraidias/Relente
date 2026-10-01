# Implementation Plan: 007 · Real disk and installer detection

Spec: [spec.md](spec.md) · Tasks: [tasks.md](tasks.md)

## Overview
Two new services feed the assistant with what's really on the Mac: an `InstallerService` that
watches `/Applications` and reads installers the user chooses, and a `DriveService` that follows
USB drives and SD cards with DiskArbitration and ejects them. Each has a live and a sample
implementation; tests, previews and `-sampleData YES` use the samples. All the rules (which disks
are shown, names, space in use, versions, order, what happens when something disappears) are
pure functions or `Assistant` logic, tested without real disks. The live code only translates
what macOS reports into plain values. The views change where the spec says: the Installer screen
(Choose, unsupported, empty state), a shared `EmptyStateView`, the drive's model line and
"Data will be erased", Review's "Unknown size", and Done's real Eject with its alert.

## Architecture Decisions

### Models (value types, `nonisolated`, `Sendable`, `Equatable`)
- **`InstallerSource`** gains `isSupported` (macOS 11 or later) and a comparable
  **`MacOSVersion`** (`Models/MacOSVersion.swift`: major, minor, patch, parsed from "15.6" or
  "10.15.7", compared numerically, so "10.15" < "11.0" < "15.10"). `version` stays the string
  shown. `InstallerSource.sorted(_:)` (newest first, stable) and `defaultSelection(in:)` (newest
  supported) are static functions, tested.
- **`Drive`** gains `model: String` and replaces `usedBytes: Int64` with
  **`usedSpace: UsedSpace`** (`.bytes(Int64)` or `.unknown`). `Status.willErase` carries a
  `UsedSpace`; `.empty` is `.bytes` under 100 MB (`Drive.emptyThreshold`). `ReviewSummary`'s
  `erasedBytes` becomes a `UsedSpace`. Samples gain one drive with unknown data.
- **`DiskDescription`** (`Models/DiskDescription.swift`): a plain struct with only the fields
  Relente reads from DiskArbitration (BSD name, whole or partition, internal, removable,
  ejectable, protocol, media UUID, vendor, model, serial, size, content type, volume name, mount
  point, physical store for APFS volumes). Built by the live service from the description
  dictionary; built by hand in tests.
- **`DriveCatalog`** (`Models/DriveCatalog.swift`): the pure rules, tested case by case:
  `isCandidate(_:bootDisks:)` (whole, external, removable, USB or SD, not a boot disk, not
  virtual), `drives(from descriptions:usedBytes:)` grouping partitions and APFS volumes under
  their physical whole disk, naming (volume name, first of several, model, generic "USB Drive" /
  "SD Card"), identity (media UUID or vendor+model+serial+size), and space in use (sum of mounted
  volumes; `.unknown` when a partition that isn't EFI / Apple_Boot / Microsoft Reserved has no
  mounted volume, or an APFS volume is locked).
- **`InstallerMetadata`** (`Models/InstallerMetadata.swift`): pure parsers, tested with fixture
  text in the tests: the app's `Info.plist` (name from `CFBundleDisplayName` minus "Install ";
  installer bundle version, whose major minus 5 gives the macOS major for Big Sur and later, and
  15.x / 14.x… for Catalina and earlier), the `SharedSupport` asset XML (`OSVersion`, the full
  version, e.g. "15.6"), and an `InstallAssistant.pkg`'s `Distribution` (`VERSION` in its
  `auxinfo`, and `installKBytes`).

### Services (protocols with live and sample implementations, injected through `init`)
- **`InstallerService`** (`Services/InstallerService.swift`):
  `func updates() -> AsyncStream<[InstallerSource]>` (the full list: found in `/Applications`
  plus chosen ones still on disk) and `func add(_ url: URL) async throws(InstallerError) -> InstallerSource`.
  `InstallerError` has a user-facing `LocalizedStringResource` ("Isn't a macOS Installer").
  - **`LiveInstallerService`:** an `actor`. Watches by listing `/Applications` (top level only)
    every 2 s (which also covers the app becoming active), comparing names and modification dates, and
    re-reading only what changed; results are cached by (path, modification date). Chosen files
    are checked for existence on the same tick. Reading is `@concurrent`:
    - `.app`: `Info.plist`; the full version from
      `Contents/SharedSupport/SharedSupport.dmg`'s asset XML, mounted read-only and hidden, then
      detached; falls back to the major version from the bundle when that fails. Size: the
      bundle's allocated size (directory enumeration).
    - `.dmg`: `hdiutil attach -readonly -nobrowse -noverify -plist`, find the
      `Install macOS *.app` at its root, read it as above, `hdiutil detach` in a `defer`-style
      path that also runs on errors. If `hdiutil info -plist` shows it already mounted, read it
      there and don't detach.
    - `.pkg`: `/usr/bin/xar -xf <pkg> -C <temporary folder> Distribution`, parse, delete the
      temporary folder.
    - `Process` with fixed executable paths and argument arrays (the helper's rule 1, followed in
      the app too); output read as property lists, never parsed as free text.
  - **`SampleInstallerService`:** the samples, plus a continuation tests use to change the list.
- **`DriveService`** (`Services/DriveService.swift`): `func updates() -> AsyncStream<[Drive]>`
  and `func eject(_ drive: Drive, force: Bool) async throws(EjectError)`. `EjectError`:
  `.notConnected` and `.refused(reason: LocalizedStringResource)`, with a user-facing message.
  - **`LiveDriveService`:** a `@MainActor` class owning a `DASession` scheduled on the main run
    loop (`DASessionScheduleWithRunLoop`, no dispatch queues). Disk appeared / disappeared /
    description-changed callbacks update a dictionary of `DiskDescription`s and emit
    `DriveCatalog.drives(…)`. Space in use comes from each mount point's volume figures
    (`volumeTotalCapacity` − `volumeAvailableCapacity`), read without listing files. Boot disks:
    the physical whole disks behind `/` (through IOKit parents for APFS). Eject:
    `DADiskUnmount(whole disk, kDADiskUnmountOptionWhole [+ Force])`, then `DADiskEject`, wrapped
    in `withCheckedContinuation`; a dissenter becomes `.refused` with
    `DADissenterGetStatusString` when it has one. (`DADissenterGetProcessID` isn't in the SDK, so
    the app using the drive is named only when macOS's reason does.)
  - **`SampleDriveService`:** the samples, a continuation to plug and unplug drives in tests, and
    a configurable eject result.
- Logging: `Logger` categories `installer` and `disk`.

### The assistant
- `Assistant.init(installerService:driveService:creationService:)` replaces the arrays.
  `installers` and `drives` become `private(set) var`, fed by `start()`, which the app calls once
  (`.task` on the window) to iterate both streams.
- `updateInstallers(_:)` and `updateDrives(_:)` (internal, called from the streams and directly
  by tests) apply the spec's table: clear or keep the selection, go back from Review (slide back,
  `byUser: false`), fail a running creation with `.driveDisconnected`, and post
  `disconnectedDrive` for the VoiceOver announcement. The default installer selection uses
  `InstallerSource.defaultSelection`.
- `chooseInstaller(_ url:)`: calls `add`, selects the result or sets `installerError` for the
  alert.
- Eject becomes asynchronous: `eject()` sets `isEjecting`, calls the service; success or
  `.notConnected` restart; `.refused` sets `ejectFailure` (the alert). `retryEject()`,
  `forceEject()` and `dismissEjectFailure()` follow the alert's buttons.
- **App wiring (`RelenteApp`):** live services, except in Debug with `-sampleData YES` or when the
  process runs unit tests (`XCTestConfigurationFilePath` in the environment), which get the sample
  services, so tests never read `/Applications` or disks.

### Views
- **`Components/EmptyStateView.swift`:** symbol, title, description, optional actions and the
  waiting indicator, centered under a `ScreenHeader`. `NoDriveView` uses it (with the header and
  installer label now above it); a new `NoInstallerView` does too.
- **`InstallerView`:** unsupported items (disabled `PickItem` with the "Not supported" chip and
  caption, like `DriveItem`), the "Other Installer…" item (`PickItem` never selected, with
  `dropDestination(for: URL.self)` and a highlight while targeted; the empty state takes drops
  too) *(changed at Checkpoint C: it was a button beside "Download from Apple…")*, `fileImporter`
  for `.app`, `.dmg` and `.pkg`, and the alert for a file that isn't an installer. Arrow keys skip
  unsupported items (in `Assistant.moveSelection`).
- **`DriveView` / `DriveItem`:** title plus "model · capacity"; the "Data will be erased" chip.
  `ReviewView` and `CreatingView`: the model line; Review's "Unknown size".
- **`DoneView` / `DoneFooter`:** spinner and disabled "Eject" while ejecting; the alert ("Try
  Again" default, "Force Eject", "Cancel" with Esc).
- **`AssistantView`:** posts the VoiceOver announcement when `disconnectedDrive` changes.
- No `.xcodeproj` edits: the project uses synchronized folders.

## Task List

### Phase 1: Models and rules (test-driven)
- [ ] Task 1: `MacOSVersion`, `InstallerSource` support, order and default selection.
- [ ] Task 2: `InstallerMetadata` parsers (Info.plist, SharedSupport XML, Distribution).
- [ ] Task 3: `Drive` model line and `UsedSpace`; `ReviewSummary`; status chip text.
- [ ] Task 4: `DiskDescription` and `DriveCatalog` (filter, grouping, naming, identity, space).

### Checkpoint A: Rules
- [ ] Unit tests pass; lint clean; Debug builds with no warnings (views adapted to the model
  changes only as far as needed to compile).

### Phase 2: The assistant follows live lists (sample services)
- [ ] Task 5: Service protocols, sample services, `Assistant` init and `start()`, `RelenteApp`
  wiring with `-sampleData`.
- [ ] Task 6: `updateDrives` / `updateInstallers` rules (unplug on each screen, installer
  removed, default selection, arrow keys skip unsupported).
- [ ] Task 7: `chooseInstaller` and asynchronous eject with its failure states.

### Checkpoint B: Logic complete
- [ ] All unit tests pass; the existing UI tests pass with `-sampleData YES`.

### Phase 3: Screens
- [ ] Task 8: `EmptyStateView`; `NoDriveView` aligned with C3; `NoInstallerView`.
- [ ] Task 9: Installer screen: Choose button and file importer, unsupported items, error alert.
- [ ] Task 10: Drive, Review and Creating: model line, "Data will be erased", "Unknown size".
- [ ] Task 11: Done: Eject spinner and alert; VoiceOver announcement on unplug.

### Checkpoint C: Screens with sample data
- [ ] Previews for every new state; owner reviews the screens in the app with `-sampleData YES`
  (light, dark, classic look).

### Phase 4: Live services
- [ ] Task 12: `LiveDriveService`: DiskArbitration session, descriptions, space in use, boot
  disks.
- [ ] Task 13: `LiveDriveService` eject (unmount, eject, force, dissenter).
- [ ] Task 14: `LiveInstallerService`: `/Applications` watch, `.app` reading with the
  SharedSupport version.
- [ ] Task 15: `LiveInstallerService`: `.dmg` and `.pkg`, and `add`.

### Checkpoint D: Real hardware (manual, with the owner)
- [ ] With a real USB drive and an SD card: they appear and disappear; names, model, space and
  "Empty" are right; an external SSD (if available) doesn't appear; unplugging on USB Drive,
  Review and during the simulation; Eject, and Eject with a Finder window open on the drive.
- [ ] With a real installer in `/Applications`: name, version, size, icon; deleting it and
  copying it back updates the screen; choosing a `.dmg` and an `InstallAssistant.pkg`.

### Phase 5: Finish
- [ ] Task 16: UI test walks the flow with `-sampleData YES` (including the empty states);
  Spanish strings; `docs/product.md`, README roadmap, spec Done, index.

### Checkpoint E: Definition of Done
- [ ] Full test suite, lint, Debug and universal Release builds with no warnings; VoiceOver and
  Reduce Motion checked on the new states.

## Risks and Mitigations

| Risk | Impact | Mitigation |
| --- | --- | --- |
| No real installer on this Mac to check the version reading against | High | Fixture-based tests for the parsers; at Checkpoint D the owner downloads one (Open questions). The fallback (major version from the bundle) keeps the screen usable if the SharedSupport reading fails. |
| Some USB sticks report fixed media and get hidden | Medium | It's the spec's rule (external SSDs hidden); logged under `disk` with the reported values, so a real case can be studied. "Show all external drives" is an Open item. |
| APFS volumes on a USB drive live on a synthesized disk, not the drive's own partitions | Medium | `DriveCatalog` groups by physical store; tested with an APFS fixture; checked at Checkpoint D with an APFS-formatted drive. |
| Mounting `SharedSupport.dmg` for every installer is slow (seconds) | Low | Done once per installer (cached by path and modification date), off the main actor; the list shows the installer with the bundle's major version until the full one is read. |
| DiskArbitration's C callbacks and Swift 6 concurrency | Medium | Session on the main run loop, callbacks hop with `MainActor.assumeIsolated`; the service exposes only an `AsyncStream` of values. |
| Unit tests run inside the app, which would start live detection | Low | The app uses the sample services when `XCTestConfigurationFilePath` is set. |

## Rules check
- **Helper security:** nothing here runs in the helper or as root. Detection is read-only;
  disk images are mounted read-only and hidden (rule 4's wording) and always detached. External
  tools (`hdiutil`, `xar`) run with fixed paths and argument arrays, never a shell.
- **Architecture:** services are protocols with live and sample implementations injected through
  `init`; models are `nonisolated` `Sendable` value types with natural ids (file URL, media UUID);
  shared state stays in the `@Observable` `Assistant`; heavy work in `@concurrent` functions; no
  `DispatchQueue`, no `Task.detached`; one error type per service with a user-facing message.
- **Platforms:** all APIs used exist on macOS 14 (DiskArbitration, IOKit, `fileImporter`); no
  new dependencies; no CI, signing or entitlement changes (the app isn't sandboxed).
- **Tests and previews never touch real disks** (sample services; unit tests detect the test
  environment).

## Open questions
1. **A real installer for Checkpoint D.** None is in `/Applications` on this Mac. The owner can
   get one from the App Store, or with `softwareupdate --fetch-full-installer
   --full-installer-version 15.6` (about 15 GB, saved in `/Applications`). An old installer
   (Catalina or earlier) for the "Not supported" case is optional: the fixtures cover it.
2. **Hardware for Checkpoint D:** a USB drive whose contents can be looked at (nothing is
   erased), and an SD card if one is at hand.
