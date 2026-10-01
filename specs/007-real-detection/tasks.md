# Tasks: 007 · Real disk and installer detection

Spec: [spec.md](spec.md) · Plan: [plan.md](plan.md)

## Where this was left (2026-10-01)

- Phases 1–4 done; Checkpoint D (real hardware) not done yet: no installer in `/Applications`
  and no USB drive at hand. To get an installer:
  `softwareupdate --fetch-full-installer --full-installer-version 15.8.1` (about 15.7 GB).
- **Pending decision:** the Installer empty state's symbol. The owner doesn't like
  `arrow.down.app` and is choosing between `laptopcomputer.and.arrow.down` and
  `arrow.down.app.dashed` (`Views/NoInstallerView.swift`).
- The owner keeps the roadmap order: downloading installers stays roadmap step 9.

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

### Checkpoint C
- [ ] Owner reviews the screens in the app with `-sampleData YES` (light, dark, classic).

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

### Checkpoint D
- [ ] Real hardware and a real installer, as listed in the plan.

## Phase 5: Finish

- [ ] Task 16: UI test, strings and docs
  - Acceptance: the flow UI test covers the empty states with `-sampleData YES`; every new
    string translated; `docs/product.md`, README roadmap (step 5 ✓), spec Done, index updated.
  - Verify: full suite, lint, Debug and Release builds.
  - Files: `RelenteUITests/AssistantFlowUITests.swift`, `docs/product.md`, `README.md`,
    `specs/007-real-detection/spec.md`, `specs/README.md`

### Checkpoint E
- [ ] Definition of Done (AGENTS.md).
