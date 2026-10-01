# Tasks: 006 · Assistant navigation

Spec: [spec.md](spec.md) · Plan: [plan.md](plan.md)

Commands (from AGENTS.md; add `-derivedDataPath` to a scratch folder when Xcode is open):

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -scheme Relente -destination 'platform=macOS' -only-testing:RelenteTests
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build -scheme Relente -configuration Release -destination 'generic/platform=macOS' CODE_SIGNING_ALLOWED=NO
xcrun swift-format lint -r --strict Relente RelenteTests RelenteUITests
```

## Phase 1: Logic

- [x] Task 1: `AssistantStep`, `ScreenChange` and `Assistant` navigation and selections (test first)
  - Acceptance: a new `Assistant` starts on `.installer` with the first installer selected and no
    drive; `continueToDrive`, `continueToReview`, `goBack` follow the Flow table and report the
    right `ScreenChange` (direction and style); Continue on USB Drive does nothing without a
    pickable drive; `goBack` keeps both selections; selecting an installer the chosen drive is too
    small for clears the drive; `hasConfirmed` is false every time Review is entered;
    `moveSelection(by:)` moves among installers or pickable drives, skipping the others, without
    wrapping; while `isChangingScreen`, step-changing actions are ignored until
    `screenChangeDidEnd()`.
  - Verify: unit tests pass; lint clean.
  - Files: `Relente/Models/AssistantStep.swift`, `Relente/App/Assistant.swift`,
    `RelenteTests/AssistantTests.swift`

- [x] Task 2: `CreationService` and the simulated creation (test first)
  - Acceptance: `CreationEvent` and `CreationService` exist; in Debug,
    `SimulatedCreationService.timeline(for:)` goes through the four phases in order, its overall
    progress never goes backwards and ends at 100 %, COPIED never exceeds the installer's size;
    the normal run lasts about 15 s and `.fast` about 2 s; with the drive-disconnected failure it
    ends with `.failed` (reason `driveDisconnected`) during Copy; the Release build compiles with no
    simulation code. `Services.swift` placeholder deleted.
  - Verify: unit tests pass; Debug and Release builds pass; lint clean.
  - Files: `Relente/Services/CreationService.swift`, `Relente/Services/SimulatedCreationService.swift`,
    `Relente/Services/Services.swift` (deleted), `RelenteTests/SimulatedCreationServiceTests.swift`

- [x] Task 3: `Assistant` runs a creation (test first, with a stub service in the test file)
  - Acceptance: `canCreate` is false without a service and `eraseAndCreate` then does nothing; it
    also does nothing until `hasConfirmed`; with a service it goes to `.creating` and follows the
    events: progress updates `creation`, `.finished` goes to `.done` (crossfade) with a
    `CreationResult` naming the chosen installer and drive and the measured duration, `.failed`
    stays on `.creating` with the failure; `stop()` cancels the run and fails with reason
    `cancelled` at the last progress; `tryAgain()` goes to Review (back, unconfirmed);
    `startOver()` and `eject()` go to Installer (crossfade) keeping the installer and clearing the
    drive and the creation; `isSimulated` reports the service kind.
  - Verify: unit tests pass; lint clean.
  - Files: `Relente/App/Assistant.swift`, `RelenteTests/AssistantTests.swift`

### Checkpoint A: Logic
- [x] All unit tests pass; lint clean; Debug and Release builds with no warnings.

## Phase 2: Screens joined (no animation yet)

- [x] Task 4: `AssistantView` container and wiring
  - Acceptance: the app opens on Installer and every button of the Flow table works with the
    mouse; the USB Drive screen has a footer with Back and Continue; Review's "Erase and Create"
    is disabled with the help tag when there is no service; `RelenteApp` creates the `Assistant`
    with the simulation (Debug, reading `-simulationSpeed` and `-simulateFailure`) or with none
    (Release); `-startScreen` is gone; previews for the container exist.
  - Verify: Debug and Release builds pass; lint clean; walk the flow once in the running app.
  - Files: `Relente/Views/AssistantView.swift` (new), `Relente/Views/ContentView.swift` (deleted),
    `Relente/App/RelenteApp.swift`, `Relente/Views/DriveView.swift`, `Relente/Views/ReviewView.swift`

- [x] Task 5: Installer label on the USB Drive screen
  - Acceptance: under the subtitle, a gray capsule with the installer's real icon, its name and
    "26.0 · 16.8 GB"; also above the empty state; one VoiceOver element "Installer: macOS Tahoe
    26.0, 16.8 GB"; English and Spanish in the String Catalog; fits 800×560 in both languages.
  - Verify: previews (with drives, no drive, Spanish, dark, classic); lint clean.
  - Files: `Relente/Views/DriveView.swift`, `Relente/Views/NoDriveView.swift`,
    `Relente/Resources/Localizable.xcstrings`

- [x] Task 6: Simulation label
  - Acceptance: an orange capsule "SIMULATION · Nothing is erased" / "SIMULACIÓN · No se borra
    nada" under the header of Creating, Error and Done when the creation is simulated, read by
    VoiceOver; nothing shown otherwise; screens don't move vertically between with and without it
    beyond the label's own space.
  - Verify: previews with and without the label; lint clean.
  - Files: `Relente/Components/SimulationLabel.swift` (new), `Relente/Views/CreatingView.swift`,
    `Relente/Views/DoneView.swift`, `Relente/Resources/Localizable.xcstrings`

- [x] Task 7: Keyboard
  - Acceptance: Esc and Go › Back (⌘[) trigger Back on USB Drive and Review; Esc does nothing on Installer,
    Error and Done and keeps meaning Cancel on Creating; left and right arrows move the selection
    on Installer and USB Drive as soon as the screen appears; Return triggers only Continue, Try
    Again and Eject; Tab still reaches every button.
  - Verify: by hand in the running app (the UI test comes in Task 12); lint clean.
  - Files: `Relente/Views/InstallerView.swift`, `Relente/Views/DriveView.swift`,
    `Relente/Views/ReviewView.swift`, `Relente/Views/AssistantView.swift`

### Checkpoint B: Walkable
- [x] Tests, lint and builds pass. The owner walks the whole flow in the running Debug app with
  the mouse and the keyboard.

## Phase 3: Motion

- [x] Task 8: Screen transitions
  - Acceptance: forward slides in from the trailing edge, back from the leading edge;
    Creating → Done, Start Over and Eject crossfade; the footer doesn't move; a double click on
    Continue takes one step; with Reduce Motion every change is a crossfade.
  - Verify: by hand in the running app, with Reduce Motion on and off; unit tests still pass.
  - Files: `Relente/Views/AssistantView.swift`, `Relente/App/Assistant.swift`

- [x] Task 9: The drive travels
  - Acceptance: the chosen drive flies from its place in the list to Review, Creating and Done and
    back with Back and Try Again; its halo color follows the screen; previews are unaffected.
    Built with the plan's fallback (`SharedArtwork` overlay), not `matchedGeometryEffect`.
  - Verify: by hand in the running app, light and dark.
  - Files: `Relente/Components/SharedArtwork.swift` (new), `Relente/Components/InstallerBadge.swift` (new), `Relente/Views/AssistantView.swift`,
    `Relente/Views/DriveView.swift`, `Relente/Views/ReviewView.swift`, `Relente/Views/CreatingView.swift`
    (and `DoneView.swift` for the Done hero)

- [x] Task 10: The installer's icon travels
  - Acceptance: the icon flies from its Installer tile to the installer label, then to the badge
    on Review, Creating and Done, and back with Back; on Eject and Start Over it returns to its
    tile.
  - Verify: by hand in the running app.
  - Files: `Relente/Views/InstallerView.swift`, `Relente/Views/DriveView.swift`,
    `Relente/Views/ReviewView.swift`, `Relente/Views/CreatingView.swift`, `Relente/Views/DoneView.swift`

- [x] Task 11: VoiceOver focus
  - Acceptance: after each screen change VoiceOver announces the new screen and its focus is on
    the title; Review reads as spec 003 describes.
  - Verify: by hand with VoiceOver (⌘F5) in the running app.
  - Files: `Relente/Components/ScreenHeader.swift`, `Relente/Views/AssistantView.swift`

- [x] Task 11b: Rolling figures on Creating (asked by the owner at Checkpoint C)
  - Acceptance: the percentage, COPIED, SPEED and REMAINING roll like a counter (REMAINING
    downwards); with Reduce Motion they just change.
  - Verify: by hand in the running app and in the `RollingFigure` preview.
  - Files: `Relente/Components/RollingFigure.swift` (new), `Relente/Components/BigStat.swift`,
    `Relente/Views/CreatingView.swift`

- [x] Task 11c: Animated step indicator and sliding selection (asked by the owner at
  Checkpoint C)
  - Acceptance: one step indicator outlives the footers: its pill moves and its number rolls;
    on Installer and USB Drive the plate and capsule slide to the new item (mouse and arrows) and
    the names are white exactly where the capsule is, as it slides; with Reduce Motion both crossfade.
  - Verify: frames captured mid-animation (slowed down temporarily); unit and flow UI tests.
  - Files: `Relente/Models/AssistantStep.swift`, `Relente/Views/AssistantFooter.swift`,
    `Relente/Components/StepIndicator.swift`, `Relente/Components/SlidingSelection.swift` (new),
    `Relente/Components/PickItem.swift` (+ the footers' `AssistantFooter(for:)` call and
    `AssistantView`)

- [x] Task 11d: Review's usage bar, option C of the canvas (asked by the owner at Checkpoint C)
  - Acceptance: drive name and capacity above the bar; two segments with a gap, the free one with
    a minimum width; legend with each part's size; VoiceOver reads the free space too; fits
    800×560 in English and Spanish.
  - Verify: offscreen renders of Review (32, 64 and 18 GB drives, English and Spanish); build.
  - Files: `Relente/Views/ReviewView.swift`, `Relente/Resources/Localizable.xcstrings`

### Checkpoint C: Motion
- [x] The owner compares the running app with option C of the canvas, in light and dark, Liquid
  Glass and classic (`-classicControls YES`), with Reduce Motion and with VoiceOver.

## Phase 4: UI tests

- [x] Task 12: `AssistantFlowUITests`
  - Acceptance: one test walks Installer → USB Drive → Review → Creating → Done → Eject →
    Installer with `-simulationSpeed fast`, using Return for Continue and Eject; one checks Esc and
    ⌘[ go back from USB Drive and Review; one checks Return on Review doesn't start the creation.
    The Xcode template test is removed.
  - Verify: `xcodebuild test -only-testing:RelenteUITests/AssistantFlowUITests` passes.
  - Files: `RelenteUITests/AssistantFlowUITests.swift` (new), `RelenteUITests/RelenteUITests.swift`
    (deleted)

- [x] Task 13: Creating and Done UI tests by navigation
  - Acceptance: both files reach their screen by navigating; the Cancel sheet behaves as in spec
    005 and "Stop" shows Error; Try Again shows Review with the checkbox unchecked; Start Over
    shows Installer; VoiceOver reads the installer label and the simulation label.
  - Verify: the whole `RelenteUITests` target passes.
  - Files: `RelenteUITests/CreatingScreenUITests.swift`, `RelenteUITests/DoneScreenUITests.swift`,
    `RelenteUITests/AssistantNavigation.swift` (new: shared launch and walking steps)

## Phase 5: Docs

- [x] Task 14: Docs and status
  - Acceptance: `docs/product.md` describes the motion (option C), the installer label, Back keys,
    the Debug-only simulation, the animated step indicator and selection, and Review's usage bar
    (earlier specs aren't edited); BUILDING's layout says `App` holds the assistant's shared state; README marks step 4 done;
    this spec is Done and `specs/README.md` updated.
  - Verify: links work; lint clean.
  - Files: `docs/product.md`, `BUILDING.md`, `README.md`,
    `specs/006-assistant-navigation/spec.md` (+ `specs/README.md`)

### Checkpoint D: Complete
- [x] Every acceptance criterion checked or recorded in Open items; Definition of Done in AGENTS.md
  met; ready for the owner to ask for a commit and PR.
