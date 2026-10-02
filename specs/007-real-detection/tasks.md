# Tasks: 007 · Real disk and installer detection

Spec: [spec.md](spec.md) · Plan: [plan.md](plan.md)

## Where this was left (2026-10-02)

- Phases 1–4 done; Checkpoint C approved by the owner (2026-10-02).
- Checkpoint D done (2026-10-02), with macOS Sequoia 15.8.1 (15.69 GB) and a "16 GB" USB
  drive (15.5 GB, NTFS):
  - [x] Sequoia appeared on the Installer screen by itself while the app was running.
  - [x] Monterey 12.7.6 (12.43 GB) appeared the same way; the drive shows as "USB", "TOSHIBA USB
    FLASH DRIVE", 10.89 GB of 15.52 GB in use (option C, Task 10b).
  - [x] Unplugged on USB Drive: it disappeared and the empty state showed; plugged back in, it
    reappeared unselected within seconds.
  - [x] Unplugged on Review: back to USB Drive with no drive selected (VoiceOver not checked).
  - [x] Unplugged during the simulation: the Error screen with "The drive was disconnected.",
    stopped at 10 % in Copy.
  - [x] Found: "Try Again" after that showed an empty Review (the selection had been cleared).
    Fixed (spec Decision 13): it goes to USB Drive with no drive selected; test in
    `AssistantDetectionTests`. Checked again in the app by the owner.
  - [x] Eject on Done with a Finder window open on the drive: macOS ejected it (the Finder
    closes its windows itself) and the app went back to the Installer screen.
  - [x] Eject with a process holding the volume (a shell whose working folder was on it): the
    alert "“USB” Couldn't Be Ejected" with the generic reason (macOS named no app); "Cancel"
    stayed on Done, "Try Again" failed again, "Force Eject" ejected it and went back.
  - [x] Moving Monterey out of `/Applications` and back: it disappeared and reappeared by itself.
  - [x] The drive erased as APFS (GPT, EFI + an APFS container on a synthesized `disk7`): one
    drive, "USB", "Empty · 15.52 GB"; the container's disk isn't listed on its own.
  - Not checked (no hardware): an SD card, an external SSD or hard drive. `DriveCatalogTests`
    cover their rules.
  - Raised by the owner: watching `/Applications` costs 0.0 % CPU idle; making it event-driven
    (FSEvents) is issue #29 (needs a `DispatchQueue` exception).
  - The drive is "Too small" for Sequoia, which is right: the installer alone doesn't fit, so the
    limit stays. Monterey 12.7.6 (about 12 GB) is being downloaded to reach Review with it.
  - The owner skipped the `.dmg` check (it would need another 16 GB); the reader is covered by
    its tests.
- The Installer empty state's symbol was settled: the add square takes its place (no symbol).
- The owner keeps the roadmap order: downloading installers stays roadmap step 9.
- Task 16 and Checkpoint E done (2026-10-02): spec Done, index and README roadmap updated.

## Phase 1: Models and rules (test-driven)

- [x] Task 1: `MacOSVersion`, installer support, order and default selection
  - Acceptance: "10.15.7" < "11.0" < "15.6" < "15.10" < "26.0"; `isSupported` is true from 11;
    `InstallerSource.sorted` is newest first and stable; `defaultSelection` is the newest
    supported, `nil` when none is.
  - Verify: `MacOSVersionTests`, `InstallerSourceTests`.
  - Files: `Models/MacOSVersion.swift`, `Models/InstallerSource.swift`,
    `RelenteTests/MacOSVersionTests.swift`, `RelenteTests/InstallerSourceTests.swift`

- [x] Task 2: `InstallerMetadata` parsers
  - Acceptance: from an `Info.plist` fixture: name without "Install ", macOS major from the
    installer bundle version (16.x → 11, 21.x → 26, 15.x → 10.15); from a SharedSupport asset XML:
    the full `OSVersion`; from a `Distribution` fixture: `VERSION` and `installKBytes` in bytes;
    malformed input throws.
  - Verify: `InstallerMetadataTests`.
  - Files: `Models/InstallerMetadata.swift`, `RelenteTests/InstallerMetadataTests.swift`

- [x] Task 3: `Drive` model line and `UsedSpace`
  - Acceptance: `Drive` has `model` and `usedSpace`; "Empty" under 100 MB (99 MB empty, 100 MB
    not); `.unknown` gives `.willErase(.unknown)` with "Data will be erased"; too small beats
    data; `ReviewSummary` carries `UsedSpace`; screens compile with the sample data.
  - Verify: `DriveTests`, `ReviewSummaryTests`; Debug build.
  - Files: `Models/Drive.swift`, `Models/UsedSpace.swift`, `Models/ReviewSummary.swift`,
    `RelenteTests/DriveTests.swift`, `RelenteTests/ReviewSummaryTests.swift` (+ the views that
    read `usedBytes`, only to compile)

- [x] Task 4: `DiskDescription` and `DriveCatalog`
  - Acceptance: only whole, external, removable USB or SD disks, never a boot disk or virtual
    disk; partitions and APFS volumes grouped under their physical disk; naming (volume, first
    of several, model, generic); identity (media UUID, else vendor+model+serial+size); space in
    use (sum, unknown for unmounted non-system partitions and locked APFS volumes, EFI ignored,
    no partitions = empty); kind SD vs USB.
  - Verify: `DriveCatalogTests`.
  - Files: `Models/DiskDescription.swift`, `Models/DriveCatalog.swift`,
    `RelenteTests/DriveCatalogTests.swift`

### Checkpoint A
- [x] Unit tests pass; lint clean; Debug build with no warnings.

## Phase 2: The assistant follows live lists

- [x] Task 5: Service protocols, sample services, `Assistant` wiring
  - Acceptance: `InstallerService` and `DriveService` protocols with error types; sample
    services with test continuations; `Assistant(installerService:driveService:creationService:)`
    and `start()`; `RelenteApp` uses samples with `-sampleData YES` (Debug) or under unit tests,
    live services otherwise (live ones stubbed until Phase 4); UI tests launch with
    `-sampleData YES`.
  - Verify: `AssistantTests` updated; UI tests pass.
  - Files: `Services/InstallerService.swift`, `Services/DriveService.swift`,
    `Services/SampleInstallerService.swift`, `Services/SampleDriveService.swift`,
    `App/Assistant.swift`, `App/RelenteApp.swift`, `RelenteUITests/AssistantNavigation.swift`

- [x] Task 6: List updates
  - Acceptance: the spec's unplug table (USB Drive, Review, Creating, Error, Done); installer
    removed on Installer / USB Drive / Review; default selection when the list first fills;
    arrows skip unsupported installers; `disconnectedDrive` set on Review.
  - Verify: `AssistantTests`.
  - Files: `App/Assistant.swift`, `RelenteTests/AssistantTests.swift`

- [x] Task 7: Choosing an installer and ejecting
  - Acceptance: `chooseInstaller` selects the added installer or sets `installerError`; a URL
    already listed is selected; `eject()` restarts on success and on `.notConnected`, sets
    `ejectFailure` on `.refused`; retry, force and dismiss behave as the alert says.
  - Verify: `AssistantTests`.
  - Files: `App/Assistant.swift`, `RelenteTests/AssistantTests.swift`

### Checkpoint B
- [x] All unit tests pass; existing UI tests pass.

## Phase 3: Screens

- [x] Task 8: Shared empty state
  - Acceptance: `EmptyStateView`; `NoDriveView` with header, installer label and "No USB Drive
    Connected"; `NoInstallerView` (C3); previews; strings in Spanish.
  - Verify: previews; Debug build.
  - Files: `Components/EmptyStateView.swift`, `Views/NoDriveView.swift`,
    `Views/NoInstallerView.swift`, `Views/DriveView.swift`, `Resources/Localizable.xcstrings`

- [x] Task 9: Installer screen (button version, replaced by Task 9b)
  - Acceptance: "Choose Installer…" beside "Download from Apple…", file importer for `.app`,
    `.dmg`, `.pkg`; unsupported items dimmed with chip and caption; error alert; empty state when
    there are no installers.
  - Verify: previews (with installers, unsupported, empty, classic); Debug build.
  - Files: `Views/InstallerView.swift`, `Views/AssistantView.swift`,
    `Resources/Localizable.xcstrings`

- [x] Task 9b: "Other Installer…" item with drag and drop (asked at Checkpoint C)
  - Acceptance: no "Choose Installer…" button at the bottom; the last item of the row is "Other
    Installer…" (dashed square, plus, ".app, .dmg or .pkg"), a button that opens the open panel
    and takes dropped files, highlighted while a file is over it; the empty state takes drops;
    VoiceOver label and hint; Spanish strings.
  - Verify: previews; Debug build; dropping a file in the app with `-sampleData YES` shows the
    "Isn't a macOS Installer" alert.
  - Files: `Views/InstallerView.swift`, `Resources/Localizable.xcstrings`

- [x] Task 10: Drive, Review and Creating
  - Acceptance: title + "model · capacity"; "Data will be erased" chip; Review's "Unknown size"
    in orange; VoiceOver labels updated.
  - Verify: previews; Debug build.
  - Files: `Views/DriveView.swift`, `Views/ReviewView.swift`, `Views/CreatingView.swift`,
    `Components/StatusChip.swift`, `Resources/Localizable.xcstrings`

- [x] Task 11: Done's Eject and the unplug announcement
  - Acceptance: spinner and disabled Eject while ejecting; alert with "Try Again" (Return),
    "Force Eject", "Cancel" (Esc); VoiceOver announces "“Name” was disconnected."
  - Verify: previews; Debug build; manual check with `-sampleData YES`.
  - Files: `Views/DoneView.swift`, `Views/AssistantView.swift`, `Resources/Localizable.xcstrings`

- [x] Task 9c: The add square (asked at Checkpoint D)
  - Acceptance: `Components/AddInstallerButton.swift`, a dashed square with a plus and no text,
    help tag and VoiceOver name and hint; last item of the row (top-aligned) and the empty
    state's symbol; the "Already have one?" link removed; shorter empty-state texts; strings.
  - Verify: previews; Debug build; snapshots.
  - Files: `Components/AddInstallerButton.swift`, `Components/EmptyStateView.swift`,
    `Views/InstallerView.swift`, `Views/NoInstallerView.swift`, `Resources/Localizable.xcstrings`

### Checkpoint C
- [x] Owner reviews the screens in the app with `-sampleData YES` (light, dark, classic).

## Phase 4: Live services

- [x] Task 12: `LiveDriveService` detection
  - Acceptance: DiskArbitration session on the main run loop; descriptions → `DiskDescription`;
    volume figures for space; boot disks excluded; emits through `DriveCatalog`.
  - Verify: Debug build; plugging a USB drive shows it.
  - Files: `Services/LiveDriveService.swift`, `Services/DiskDescription+DiskArbitration.swift`

- [x] Task 13: `LiveDriveService` eject
  - Acceptance: unmount whole + eject; force option; dissenter → `.refused` with macOS's reason;
    a missing disk → `.notConnected`.
  - Verify: manual, with a Finder window open on the drive.
  - Files: `Services/LiveDriveService.swift`

- [x] Task 14: `LiveInstallerService` for `/Applications`
  - Acceptance: lists `Install macOS *.app` every 2 s; re-reads only changed
    items; full version from SharedSupport (read-only, hidden, detached), bundle major as
    fallback; size from the bundle.
  - Verify: Debug build; an installer in `/Applications` appears.
  - Files: `Services/LiveInstallerService.swift`, `Services/InstallerReader.swift`

- [x] Task 15: `.dmg`, `.pkg` and `add`
  - Acceptance: `.dmg` attached read-only and hidden, read, always detached (not when it was
    already mounted); `.pkg` read with `xar` into a temporary folder that is deleted; `add`
    validates and throws "Isn't a macOS Installer"; chosen files that disappear drop out.
  - Verify: manual with a `.dmg` and an `InstallAssistant.pkg`.
  - Files: `Services/InstallerReader.swift`, `Services/LiveInstallerService.swift`

- [x] Task 10b: The drive's usage bar, option C (asked at Checkpoint D)
  - Acceptance: on USB Drive, the model on one line (cut with "…", full in the help tag, none when
    it's the name), a gray usage bar and "*N* of *M* in use" / "Empty · *M*" / "Contents unknown ·
    *M*"; too small keeps "model · capacity", the red chip and "Needs"; no orange or green chips;
    the row is top-aligned; strings in Spanish; the unused chip strings removed.
  - Verify: `DriveTests` (usage fraction: in use, empty under 100 MB, unknown, never over 1);
    screenshots in English and Spanish; the real drive in the app.
  - Files: `Models/Drive.swift`, `Views/DriveView.swift`, `Components/StatusChip.swift`,
    `Resources/Localizable.xcstrings`, `RelenteTests/DriveTests.swift`

- [x] Task 10d: Three aligned lines under every drive (asked at Checkpoint D, "C · alineada")
  - Acceptance: line 1 the model, or "USB Drive" / "SD Card" when the name is the model; line 2
    the bar, or the red "Too small" chip, always 20 pt tall; line 3 the usage text, or "*N* ·
    needs *M*" for a drive that's too small; "Needs %@" replaced; Spanish strings.
  - Verify: `DriveTests` (`subtitle`); offscreen renders of 3 and 6 drives; the full suite.
  - Files: `Models/Drive.swift`, `Views/DriveView.swift`, `Resources/Localizable.xcstrings`,
    `RelenteTests/DriveTests.swift`

- [x] Task 10c: Many installers or drives (asked at Checkpoint D, canvas option 1 + 3)
  - Acceptance: up to 4 items, the large row as before; from 5 (the add square counts), a grid of
    5 columns of small items (128 pt, 64 pt icons) centered under the header, scrolling when it
    doesn't fit, the selection scrolled into view; Up and Down move a row; chips without icon in
    small items; the sliding selection works in both; previews with many installers and drives.
    The sample installers include Catalina (unsupported). When it scrolls: a 16 pt fade at the
    top and bottom (not on the scroller), 24 pt from the header and 20 pt from below; the chosen
    item's artwork is handed to the assistant only while the screen changes, so it doesn't float
    over the header when scrolled away. Found by the owner: a drive kept chosen after going back
    slid in late on its own; artwork without a place on one of the two screens now stays with
    its screen (`SharedArtwork.stayingWithScreens`, `SharedArtworkTests`; checked in frames).
  - Verify: `PickLayoutTests`; offscreen renders (4, 5 and 15 installers, 6 drives, light and
    dark); a temporary build with 15 installers and 10 drives checked by the owner (scrolling,
    arrows, the flight to and from the grid); the full suite.
  - Files: `Components/PickLayout.swift`, `Components/PickItemSize.swift`,
    `Components/PickCollection.swift`, `Components/PickItem.swift`,
    `Components/ArrowKeySelection.swift`, `Components/AddInstallerButton.swift`,
    `Components/StatusChip.swift`, `Components/SharedArtwork.swift`, `Views/AssistantView.swift`,
    `Views/InstallerView.swift`, `Views/DriveView.swift`, `App/RelenteApp.swift`,
    `RelenteTests/PickLayoutTests.swift`

### Checkpoint D
- [x] Real hardware and a real installer, as listed in the plan (2026-10-02; what wasn't
  available is listed under "Where this was left").

## Phase 5: Finish

- [x] Task 16: UI test, strings and docs
  - Acceptance: the flow UI test covers the empty states with `-sampleData YES`; every new
    string translated; `docs/product.md`, README roadmap (step 5 ✓), spec Done, index updated.
  - Verify: full suite, lint, Debug and Release builds.
  - Files: `RelenteUITests/AssistantFlowUITests.swift`, `docs/product.md`, `README.md`,
    `specs/007-real-detection/spec.md`, `specs/README.md`
  - Done (2026-10-02): `-sampleEmpty installers|drives` and the two empty-state UI tests;
    `docs/product.md` and BUILDING; every string has Spanish (an empty key from the "Isn't a
    macOS Installer" alert title was removed). The UI test found that VoiceOver couldn't reach
    the add square in the empty state (ContentUnavailableView merged it into the title), so
    `EmptyStateView` no longer uses a `Label`; its look is unchanged (compared in screenshots).
  - Left for after Checkpoint D: spec Done, `specs/README.md`, README roadmap (step 5 ✓).

### Checkpoint E
- [x] Definition of Done (AGENTS.md). (2026-10-02: full suite, lint, Debug and universal Release
  builds with no warnings; VoiceOver and Reduce Motion on the new states by the owner; dark mode
  in screenshots.)
