# Tasks: 005 · Done screen

Spec: [spec.md](spec.md) · Plan: [plan.md](plan.md)

Commands (from AGENTS.md; add `-derivedDataPath` to a scratch folder when Xcode is open):

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -scheme Relente -destination 'platform=macOS' -only-testing:RelenteTests
xcrun swift-format lint -r --strict Relente RelenteTests RelenteUITests
```

## Phase 1: Models

- [x] Task 1: `CreationResult` — time text and volume name (test first)
  - Acceptance: `volumeName` is “Install macOS Tahoe” for the Tahoe sample (“Install ” + the
    installer's name); `durationText` in English reads "less than a minute" for 0 s and 59 s,
    "1 minute" for 60 s and 89 s, "2 minutes" for 90 s, "12 minutes" for 720 s, and shows hours and
    minutes for 80 minutes; a `sample` result exists for the previews.
  - Verify: unit tests pass; lint clean.
  - Files: `Relente/Models/CreationResult.swift`, `RelenteTests/CreationResultTests.swift`

- [x] Task 2: `MacArchitecture` and the card texts (test first)
  - Acceptance: `appleSilicon` and `intel` cases; `current` reads `hw.optional.arm64` (Apple
    silicon when it's 1, also under Rosetta; Intel when it's 0 or missing) and returns a valid case
    on the test Mac; per case, in English: name ("Apple silicon" / "Intel"), capsule ("HOLD" /
    "AT START-UP") and text with the volume name ("Hold the power button until you see the
    start-up options, then choose “Install macOS Tahoe”." / "Hold Option (⌥) right after turning
    on the Mac, then choose “Install macOS Tahoe”.").
  - Verify: unit tests pass; lint clean.
  - Files: `Relente/Models/MacArchitecture.swift`, `RelenteTests/MacArchitectureTests.swift`

### Checkpoint A: Models
- [x] All unit tests pass; lint clean; Debug build with no warnings.

## Phase 2: App-wide changes on the existing screens

- [x] Task 3: One content width, 640 pt
  - Acceptance: `Theme.Sizes.contentWidth` is 640; `ReviewView` and `CreatingView` use it and have
    no `560` of their own; the `WarningCallout` and `PhaseBar` previews use it; `grep -rn 560
    Relente` only finds the window height.
  - Verify: build and tests pass; lint clean; Review, Creating and Error previews fit 800×560.
  - Files: `Relente/Components/Theme.swift`, `Relente/Views/ReviewView.swift`,
    `Relente/Views/CreatingView.swift`, `Relente/Components/WarningCallout.swift`,
    `Relente/Components/PhaseBar.swift`

- [x] Task 4: Error screen without the ring
  - Acceptance: when failed, `CreatingHero` shows the red-haloed drive with the red badge in a
    frame of the ring's diameter and no ring; running is unchanged; switching between the
    "Copy" and "Error: drive disconnected" previews moves nothing (same positions for the name,
    figures and phase bar).
  - Verify: build passes; lint clean; previews compared side by side.
  - Files: `Relente/Views/CreatingView.swift`

- [x] Task 5: Icons on buttons
  - Acceptance: `PrimaryButtonStyle` and `SecondaryButtonStyle` show symbol and title
    (`.labelStyle(.titleAndIcon)`); "Download from Apple…" (`arrow.down.circle`), "Erase and
    Create" (`touchid`, still red and destructive), "Start Over" (`arrow.uturn.backward`) and "Try
    Again" (`arrow.clockwise`) use `Label`; Continue, Back, Cancel and the alert buttons stay text
    only; VoiceOver reads only the titles.
  - Verify: build passes; lint clean; owner checks the buttons in the canvas in the classic and
    Liquid Glass looks.
  - Files: `Relente/Components/ButtonStyles.swift`, `Relente/Views/InstallerView.swift`,
    `Relente/Views/ReviewView.swift`, `Relente/Views/CreatingView.swift`

### Checkpoint B: Existing screens
- [x] Tests, lint and build pass. Owner checks Review, Creating and Error in the Xcode canvas
  (light, dark, classic, Liquid Glass): 640 pt, no ring on Error, icons on the buttons.

## Phase 3: Done screen

- [x] Task 6: `KeyCap` and `StartUpCard` components
  - Acceptance: `KeyCap` draws a key with a label, a symbol, or a modifier glyph over its name,
    plain or highlighted (accent border, fill and glyph); `StartUpCard` draws the gray key band in
    keyboard order (Apple silicon: F10, F11, F12, power highlighted, then an accent arc; Intel: fn,
    control, option highlighted, command), the heading with its capsule, THIS MAC when
    `isThisMac`, and the text; the band is hidden from VoiceOver and the card reads as one element;
    `#Preview`s of keys and of both cards, light and dark.
  - Verify: build passes; lint clean; previews checked.
  - Files: `Relente/Components/KeyCap.swift`, `Relente/Components/StartUpCard.swift`

- [x] Task 7: `DoneView` — header, hero and start-up cards
  - Acceptance: `DoneView(result:thisMac:)`; `ScreenHeader` "Installer Ready" with the subtitle
    "Eject it and plug it into the Mac you want to install. It took 12 minutes."; `DoneHero` with
    `HeroArtwork` at 104 pt, success halo, `FileIcon` badge with a small green checkmark, and the
    volume name below (semibold, truncated in the middle), read by VoiceOver as "Install macOS
    Tahoe, on SanDisk Ultra"; `DoneStartUp` with the label "HOW TO START UP FROM IT" and the two
    `StartUpCard`s side by side in `Theme.Sizes.contentWidth`, THIS MAC on the one matching
    `thisMac`. Previews for Apple silicon, Intel, a long drive name and a run under a
    minute (footer can be a placeholder until Task 8).
  - Verify: build passes; lint clean; previews checked.
  - Files: `Relente/Views/DoneView.swift`, `Relente/Models/CreationResult.swift` (samples, if
    needed)

- [x] Task 8: `DoneFooter` — help popover and "Eject"
  - Acceptance: "Step 4 of 4 · Done" with a green current pill; a `HelpLink` that opens a popover
    "The Mac doesn’t show the drive?" with the four tips (the last one with the installer's name),
    closed by Esc or a click outside; "Eject" with the `eject` symbol, primary and the default
    action, doing nothing for now; previews of the whole screen with the popover closed and open,
    classic look, light and dark.
  - Verify: build passes; lint clean; previews checked; Return triggers "Eject" (not help).
  - Files: `Relente/Views/DoneView.swift`

- [x] Task 9: Spanish, and fitting the window
  - Acceptance: every new string is in `Localizable.xcstrings` with Spanish and a translator
    comment where it interpolates; every changed screen (Review, Creating, Error, Done) fits 800×560
    in English and Spanish without scrolling; no card text needs more than three lines and the
    capsules fit next to the headings.
  - Verify: tests pass; lint clean; previews in both languages checked (a temporary render test if
    needed, removed afterwards).
  - Files: `Relente/Resources/Localizable.xcstrings`, and copy tweaks in
    `Relente/Views/DoneView.swift` or `Relente/Models/MacArchitecture.swift` if something doesn't fit

- [x] Task 9b: Help next to the section, by cause; step names and Spanish wording
  - Acceptance: the help button sits at the end of the "START UP FROM THE DRIVE" line and its
    popover lists three causes (Connection, Intel Mac with the T2 chip, Compatibility), each with
    a symbol, a bold title and one line; the footer only has "Eject"; the subtitle says "…the Mac
    where you want to install macOS…"; step names are Review/Revisión and Creation/Creación; the
    Spanish texts in the spec's wording table are changed, including "Hacer booteable"; stale
    catalog entries are removed; every changed screen fits in Spanish (USB drive chip
    "Demasiado pequeña" included).
  - Verify: tests pass; lint clean; Spanish renders checked.
  - Files: `Relente/Views/DoneView.swift`, `Relente/Views/CreatingView.swift`,
    `Relente/Views/ReviewView.swift`, `Relente/Components/StepIndicator.swift`,
    `Relente/Resources/Localizable.xcstrings`

- [x] Task 9c: Apple's Human Interface Guidelines review (added after the owner asked for it)
  - Acceptance: Esc presses "Cancel" on Creating; the cancel confirmation is a sheet where Return
    and Esc keep going and only a click stops; the help button is in the footer's bottom-leading
    corner; every step pill is blue; the T2 help icon is `cpu`; Spanish section label "ARRANCAR
    DESDE EL USB"; Debug-only `-startScreen creating`; UI tests for the confirmation.
  - Verify: unit and UI tests pass; lint clean; renders checked.
  - Files: `Relente/Views/CreatingView.swift`, `Relente/Views/DoneView.swift`,
    `Relente/Views/AssistantFooter.swift`, `Relente/Components/StepIndicator.swift`,
    `RelenteUITests/CreatingScreenUITests.swift`

### Checkpoint C: Done screen
- [x] Tests, lint, Debug and universal Release builds pass (the Release command in AGENTS.md).
  Owner reviews Done in the Xcode canvas, including Liquid Glass.

## Phase 4: Docs

- [x] Task 10: Docs and status
  - Acceptance: `docs/product.md` describes Done as built, Error without the ring, and in the
    design system the 640 pt content width and the rule for icons on buttons (and lists
    `KeyCap` and `StartUpCard`); spec acceptance criteria ticked or pointing to Open items; spec status Done;
    `specs/README.md` and the README roadmap line (005 ✓) updated.
  - Verify: links work; lint clean.
  - Files: `docs/product.md`, `specs/005-done-screen/spec.md`, `specs/README.md`, `README.md`

### Checkpoint D: Complete
- [x] Every acceptance criterion checked or recorded in Open items; Definition of Done in
  AGENTS.md met; ready for the owner to ask for a commit and PR.
