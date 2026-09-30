# Tasks: 004 · Creating screen (+ Error)

Spec: [spec.md](spec.md) · Plan: [plan.md](plan.md)

Commands (from AGENTS.md; add `-derivedDataPath` to a scratch folder when Xcode is open):

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -scheme Relente -destination 'platform=macOS' -only-testing:RelenteTests
xcrun swift-format lint -r --strict Relente RelenteTests RelenteUITests
```

## Phase 1: Models

- [x] Task 1: `CreationPhase` and `CreationProgress` overall percentage (test first)
  - Acceptance: four phases in bar order with weights 5/85/5/5 summing to 1; overall = finished
    weights + current weight × fraction, clamped 0…1; a phase with no percentage (`nil`) counts 0
    until it ends; `percent` rounds down (99.9 → 99; only a finished Verify gives 100); moving to
    the next phase never lowers overall.
  - Verify: unit tests pass; lint clean.
  - Files: `Relente/Models/CreationPhase.swift`, `Relente/Models/CreationProgress.swift`,
    `RelenteTests/CreationProgressTests.swift`

- [x] Task 2: REMAINING and the copy figures (test first)
  - Acceptance: Copy → bytes left ÷ speed; other phase with a percentage → elapsed × left ÷ done;
    `.calculating` with speed 0 or a phase at 0 %; `.almostDone` after Copy with no percentage;
    under 60 s → "Less than a minute", otherwise "About N min". Copy progress clamped when copied
    bytes exceed the installer size; COPIED is 0 before Copy and the full size after. Sample
    snapshots for every phase.
  - Verify: unit tests pass; lint clean.
  - Files: `Relente/Models/RemainingTime.swift`, `Relente/Models/CreationProgress.swift`,
    `RelenteTests/CreationProgressTests.swift`, `RelenteTests/RemainingTimeTests.swift`

- [x] Task 3: `CreationFailure` and `CreationState` (test first)
  - Acceptance: five reasons, each with a non-empty title and recovery line; STOPPED AT percent
    and phase come from the stored progress (e.g. failure during Format is at most 5 %); sample
    failures for "drive disconnected" and "cancelled".
  - Verify: unit tests pass; lint clean.
  - Files: `Relente/Models/CreationFailure.swift`, `Relente/Models/CreationState.swift`,
    `RelenteTests/CreationFailureTests.swift`

### Checkpoint A
- [x] All unit tests pass, lint clean, Debug build without warnings.

## Phase 2: Components

- [x] Task 4: `ProgressRing`
  - Acceptance: arc over a gray track at the given fraction, tint configurable, content inside;
    VoiceOver reads "Creating installer, 43 percent" as a progress value; animates changes, none
    with Reduce Motion; `#Preview` at several fractions, accent and danger.
  - Verify: build; preview in the Canvas, light and dark.
  - Files: `Relente/Components/ProgressRing.swift`

- [x] Task 5: `PhaseBar`
  - Acceptance: four equal segments with labels; finished = accent + checkmark, current = partial
    fill + bold label, pending = gray; failed = current segment red; VoiceOver reads "Phase 2 of 4,
    Copy"; long labels truncate on one line; Reduce Motion respected; `#Preview` for each phase and
    a failed state.
  - Verify: build; preview in the Canvas, light and dark.
  - Files: `Relente/Components/PhaseBar.swift`

### Checkpoint B
- [x] Build without warnings; owner reviews both components in the Canvas.

## Phase 3: Screens

- [x] Task 6: Creating screen (running state)
  - Acceptance: header, hero (ring + drive + installer badge + percentage + name · capacity),
    COPIED / SPEED / REMAINING, phase bar, footer "Step 4 of 4 · Creating" with "Cancel"; the alert
    has "Keep Going" (Return and Esc) and "Stop" (destructive, never default); previews for Format,
    early Copy, mid Copy, Make bootable, Verify, Classic and Dark; fits 800×560.
  - Verify: build; in the Canvas, open the alert and check that Return keeps going; lint.
  - Files: `Relente/Views/CreatingView.swift`

- [x] Task 7: Error screen (failed state)
  - Acceptance: same layout; red halo, red ring frozen where it stopped, red `xmark` badge;
    STOPPED AT (red, "During Copy") and OTHER DISKS · Untouched (green); `CreationErrorCard` with
    icon, reason and recovery, read by VoiceOver; frozen phase bar with the failed phase in red;
    footer "Start Over" (secondary) and "Try Again" (primary, default); previews for "drive
    disconnected" and "cancelled", Classic and Dark; fits 800×560.
  - Verify: build; previews in the Canvas; lint.
  - Files: `Relente/Views/CreatingView.swift`
  - Changed after the owner's review (spec decisions 7 and 9): nothing moves between states, the
    reason and what to do are the subtitle (no card), OTHER DISKS was removed, and STOPPED AT
    has no "During Copy" caption (the phase bar shows it).

### Checkpoint C
- [x] All spec previews render; owner reviews the screens in the Canvas.

## Phase 4: Finish

- [x] Task 8: Spanish, docs and Definition of Done
  - Acceptance: every new string in `Localizable.xcstrings` with Spanish and translator comments on
    interpolated strings; Spanish previews fit 800×560; `docs/product.md` mentions "Cancel" with
    confirmation and "Try Again" / "Start Over"; spec criteria ticked (VoiceOver and Reduce Motion
    in the running app stay in Open items for roadmap step 4); README roadmap line updated; spec
    status stays Approved until the PR's last commit.
  - Verify: tests, strict lint and the universal Release build with warnings as errors pass.
  - Files: `Relente/Resources/Localizable.xcstrings`, `docs/product.md`, `README.md`,
    `specs/004-creating-screen/spec.md`, `specs/README.md`

### Checkpoint D
- [x] Definition of Done in AGENTS.md met; ready for the owner to ask for a commit and PR.
