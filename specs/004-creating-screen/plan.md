# Implementation Plan: 004 · Creating screen (+ Error)

Spec: [spec.md](spec.md) · Tasks: [tasks.md](tasks.md)

## Overview
Build the Creating screen (4) and its Error variant (4b) as static screens with sample data. The
logic (overall percentage, REMAINING, failure reasons) lives in `nonisolated` value-type models
tested with Swift Testing; two new components (`ProgressRing`, `PhaseBar`) and one screen file
draw them. Nothing touches real disks or processes.

## Architecture Decisions

- **Models (in `Relente/Models/`, one type per file):**
  - `CreationPhase`: `enum` with `format`, `copy`, `makeBootable`, `verify`. `CaseIterable`, and
    the case order *is* the bar order, so reordering after roadmap step 7 is a one-line change.
    Each phase has a `weight` (0.05 / 0.85 / 0.05 / 0.05) and a localized `name`.
  - `CreationProgress`: a snapshot of the process — `phase`, `phaseFraction: Double?` (`nil` = the
    phase reports no percentage), `phaseElapsed: Duration`, `copiedBytes`, `installerSize`,
    `bytesPerSecond`. Computed: `overallFraction` (clamped 0…1), `percent` (rounded down),
    `remaining: RemainingTime`. Sample snapshots (`samples`) for the previews.
  - `RemainingTime`: `enum` with `.calculating`, `.estimate(Duration)`, `.almostDone`, and a
    `text: LocalizedStringResource` ("Less than a minute", "About 4 min", "About 1 h 20 min",
    "Calculating…", "Almost done"). Kept separate so the thresholds are tested on their own.
  - `CreationFailure`: `reason` (`enum Reason`: `driveDisconnected`, `cancelled`,
    `installerDamaged`, `verificationFailed`, `unknown`) plus the `CreationProgress` at the moment
    it stopped. `title` and `recovery` are `LocalizedStringResource`; STOPPED AT and the frozen
    phase bar come from the stored progress, so both screens share the same numbers.
- **One screen, two states.** `CreatingView` takes `installer`, `drive` and a `CreationState`
  (`.running(CreationProgress)` / `.failed(CreationFailure)`), so 4 and 4b share one layout and the
  screen doesn't jump between them. The sections are separate `View` types in the same file:
  `CreatingHero`, `CreatingStats`, `FailureStats`, `CreatingFooter`, `CreationErrorFooter`.
  (A `CreationErrorCard` was built in Task 7 and removed after review: the reason now goes in the
  subtitle; see spec decision 9.) `CreationState` is a small enum in its own model file.
- **Components (in `Relente/Components/`):**
  - `ProgressRing`: a `Circle().trim` arc over a gray track, with a `tint` (accent, or danger when
    failed) and any content inside (the `HeroArtwork`). It carries the VoiceOver progress value.
  - `PhaseBar`: four equal segments driven by `CreationPhase.allCases`, the current phase and its
    fraction, and a `isFailed` flag that paints the current segment red.
  - Both animate value changes with `.animation(reduceMotion ? nil : .smooth, value:)`, reading
    `@Environment(\.accessibilityReduceMotion)`.
- **Cancel confirmation** is an `.alert` owned by `CreatingFooter` (`@State private var
  isConfirmingCancel`): "Keep Going" with `role: .cancel` and "Stop" with `role: .destructive`.
  All buttons (Stop, Try Again, Start Over) take closures that do nothing for now, like the Review
  screen's.
- **Previews** wrap the screen plus its footer at 800×560, as `ReviewScreenPreview` does.
- **No `.xcodeproj` edits:** the project uses synchronized folders, so new files are picked up
  automatically.

## Task List

### Phase 1: Models (logic first, test-driven)
- [x] Task 1: `CreationPhase` + `CreationProgress` overall percentage
- [x] Task 2: REMAINING (`RemainingTime`) and the copy figures
- [x] Task 3: `CreationFailure` and `CreationState`

### Checkpoint A: Models
- [x] All unit tests pass; lint clean; Debug build with no warnings.

### Phase 2: Components
- [x] Task 4: `ProgressRing`
- [x] Task 5: `PhaseBar`

### Checkpoint B: Components
- [x] Both previews render in light and dark; build with no warnings.
- [x] **Owner reviews the components in the Xcode Canvas.**

### Phase 3: Screens
- [x] Task 6: Creating screen (running state) with the Cancel alert
- [x] Task 7: Error screen (failed state)

### Checkpoint C: Screens
- [x] All previews from the spec render; everything fits 800×560; build with no warnings.
- [x] **Owner reviews the screens in the Canvas (Liquid Glass and Classic, light and dark).**

### Phase 4: Finish
- [x] Task 8: Spanish translations, `docs/product.md`, spec status and Definition of Done

### Checkpoint D: Complete
- [x] Every acceptance criterion in the spec is met or recorded in Open items.
- [x] Release build (universal, warnings as errors), tests and strict lint pass.
- [x] Ready for the owner to ask for a commit and pull request.

## Risks and Mitigations

| Risk | Impact | Mitigation |
| --- | --- | --- |
| On macOS, SwiftUI may make "Stop" the Return key in the alert instead of "Keep Going" | High (Return must never be destructive) | Check it by hand in the running app in Task 6 (a temporary preview-only launch path isn't needed: the Canvas preview is interactive). If it's wrong, mark "Keep Going" with `.keyboardShortcut(.defaultAction)` or fall back to `confirmationDialog`. |
| Spanish text ("Menos de un minuto", "Hacer arranque") overflows the 560 pt column or the phase labels | Medium | Check the Spanish previews (`.environment(\.locale, …)`) in Task 8; labels truncate in the middle on one line like on Review. |
| `Duration` formatting ("About 1 h 20 min") differs by locale or OS version | Low | Tests assert on the `RemainingTime` case and the whole minutes, not on the formatted string; the text is checked in previews. |
| Glass/prominent buttons render flat in offscreen snapshots | Low | The owner checks buttons in the Canvas (see memory note on separate DerivedData). |
| The real command's output differs from the spec (phase order, Make bootable percentage) | Low now | Already designed for: phase order is `allCases`, `phaseFraction` is optional. Revisited in roadmap step 7. |

## Rules check
- **Helper security:** not touched; no process, no disk access, no helper code.
- **Architecture:** views only present data; models are `nonisolated`, `Sendable`, `Equatable`
  value types; no services are needed yet (sample data only). No `ObservableObject`, no
  `DispatchQueue`, no `Task.detached`.
- **Platforms:** nothing above macOS 14; buttons use `.buttonStyle(.primary/.secondary)`; screens
  get a "Classic (macOS 14–15)" preview.
- **Accessibility and localization:** Reduce Motion handled in the components; VoiceOver labels
  on the ring, figures, phase bar and card; every string in the catalog with Spanish; Return is
  never destructive.
- **UI test:** the one flow test waits for navigation (roadmap step 4); nothing to add here.

## Open Questions
None.
