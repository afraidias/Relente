# Implementation Plan: 006 · Assistant navigation

Spec: [spec.md](spec.md) · Tasks: [tasks.md](tasks.md)

## Overview
Replace the single-screen `ContentView` with an assistant container driven by one `@Observable`
model, `Assistant`, that knows the current step, what was chosen and how the last screen change
should animate. The navigation and selection rules, and the run of a creation, live in that model
and are unit-tested without SwiftUI. Creation goes through a `CreationService` protocol; this
feature adds only a Debug-only simulated implementation (the live one comes in roadmap step 7),
and Release builds pass no service, which disables "Erase and Create". The views stay as they are,
plus a footer for the USB Drive screen, the installer label, the simulation label, keyboard
handling and the motion chosen on the canvas (option C). Nothing touches real disks or processes.

## Architecture Decisions

- **`Models/AssistantStep.swift`:** `nonisolated enum AssistantStep { installer, drive, review,
  creating, done }` (Error is the `creating` step with a failed `CreationState`, as in spec 004),
  with its footer step number and step name. Also `ScreenChange`: `direction` (`.forward`,
  `.back`) and `style` (`.slide`, `.crossfade`), a value type, so the Flow table of the spec is
  data the tests can check.
- **`App/Assistant.swift`:** `@MainActor @Observable final class Assistant`, the app's shared
  state (it lives next to the app entry point; `Models/` keeps only value types). It holds
  `installers`, `drives`, `step`, `selectedInstallerID`, `selectedDriveID`, `hasConfirmed`,
  `creation: CreationState?`, `result: CreationResult?`, `lastChange: ScreenChange` and
  `isChangingScreen`. Its methods are the user's actions: `continueToDrive()`,
  `continueToReview()`, `goBack()`, `eraseAndCreate()`, `stop()`, `tryAgain()`, `startOver()`,
  `eject()`, `selectInstaller(_:)`, `selectDrive(_:)`, `moveSelection(by:)` and
  `screenChangeDidEnd()`. Every action checks it is allowed on the current step and does nothing
  otherwise; while `isChangingScreen` is true, actions that change the step are ignored (the
  double-click guard). Dependencies come through `init(installers:drives:creationService:)`.
- **`Services/CreationService.swift`:** `protocol CreationService: Sendable` with
  `func create(installer:drive:) -> AsyncStream<CreationEvent>`, where `CreationEvent` is
  `.progress(CreationProgress)`, `.finished` or `.failed(CreationFailure)`. Stopping is
  cancelling the task that reads the stream. The assistant measures the duration itself (a
  `ContinuousClock` instant at the start), so Done shows the real time the simulation took.
  `canCreate` is `creationService != nil`. The `Services.swift` placeholder is deleted.
- **`Services/SimulatedCreationService.swift`, wrapped in `#if DEBUG`:** walks Format → Copy →
  Make bootable → Verify in about 15 s (2 s with `.fast`), emitting `CreationProgress` values built
  from the installer's size with a plausible speed. The sequence is a pure function
  (`SimulatedCreationService.timeline(for:)`), tested directly; the service only sleeps between
  steps. An optional failure (`.driveDisconnected`) stops it partway through Copy.
- **Launch arguments**, read once in `RelenteApp` inside `#if DEBUG`: `-simulationSpeed fast` and
  `-simulateFailure driveDisconnected`. Release builds create `Assistant` with no service.
  `-startScreen` and its `rootView` switch are removed; `-classicControls` stays.
- **`Views/AssistantView.swift`** replaces `ContentView`: a `VStack` with the current screen's
  content and, below it, the current screen's footer. Only the content is animated; the footer
  swaps without animation (`.transaction { $0.animation = nil }`), so it stays still. The content
  is keyed by step with `.id(step)` and a `.transition` chosen from `lastChange`:
  - slide forward: `.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))`
    (mirrored automatically in right-to-left layouts), the opposite for back;
  - crossfade: `.opacity`;
  - with `accessibilityReduceMotion`, always `.opacity`.
  Screen changes run inside `withAnimation(_:completionCriteria:_:completion:)` (macOS 14), whose
  completion calls `screenChangeDidEnd()`.
- **Shared elements:** *(Changed while building: `matchedGeometryEffect` was dropped, because
  when screens slide the slide's offset adds to the flight and the drive starts outside the
  window. This is the fallback the Risks table planned.)* `Components/SharedArtwork.swift`: each
  screen marks where the drive and the installer's icon go with `.sharedArtwork(_:isActive:)`,
  which, inside the assistant (`\.assistantScreen` environment), hides the view (keeping its
  space) and reports its bounds through an anchor preference keyed by screen. `AssistantView`
  draws one drive and one icon over the screens at the shown screen's marks
  (`overlayPreferenceValue`), so changing screen inside the animation flies them from the old
  marks to the new ones; when a screen has no mark (Installer has no drive), the artwork comes
  and goes with its screen's transition. With Reduce Motion, each screen gets its own copy of
  the drive and the icon (`.id` per screen), so they fade with it instead of flying. Previews,
  outside the assistant, draw the artwork in place. `Components/InstallerBadge.swift` (icon plus Done's checkmark) is shared by Done and the
  overlay. The halo stays in each screen, so its color changes with the screen.
- **Footer and in-screen changes:** the footer follows its own state, changed outside the
  animation, so it swaps at once. Each screen gets `.geometryGroup()`, so what changes inside it
  while it slides (the phase bar filling up) moves with it.
- **Step indicator and selection** *(added at Checkpoint C, at the owner's request)*:
  `AssistantStep` holds each step's footer number and name, and `AssistantFooter(for:)` takes the
  step. Inside the assistant, each footer marks its indicator (`SharedArtwork.stepIndicator`) and
  `AssistantView` draws one `StepIndicator` there for every footer, so its pill and its number
  (`.numericText`) animate. The selection uses the same technique within a row:
  `Components/SlidingSelection.swift` draws one plate and one capsule behind the row at the
  selected `PickItem`'s marks (`matchedGeometryEffect` can't match shapes across buttons). Over
  the names it draws a white copy of each, masked by the moving capsule, so letters turn white
  exactly while the capsule is under them (a delayed color change looked laggy to the owner). Figures on Creating roll with
  `Components/RollingFigure.swift`.
- **USB Drive screen:** `DriveView` takes the chosen `installer` instead of `installerSize`, shows
  `DriveInstallerLabel` (a section view in the same file) under the header, also above the empty
  state. A new `DriveFooter` (Back + Continue) joins the other footers.
- **Simulation label:** `Components/SimulationLabel.swift`, an orange capsule with the text, shown
  under the header of Creating, Error and Done when `assistant.isSimulated`. The screens take an
  `isSimulated: Bool` (previews pass either value).
- **Keyboard:**
  - Esc on Back: `.keyboardShortcut(.cancelAction)` on a shared `BackButton`, used by
    `DriveFooter` and `ReviewFooter`. ⌘[: a Go menu (`App/AssistantCommands.swift`) with "Back",
    enabled by `Assistant.canGoBack`. *(Changed while building: an invisible second button with
    ⌘[ didn't receive the shortcut.)*
  - Arrows: the installer and drive rows get `.focusable()` with `.onMoveCommand`, calling
    `moveSelection(by: ±1)`; the row gets default focus with `.defaultFocus`, so arrows work as
    soon as the screen appears. Tab keeps moving between the buttons.
  - Return: `.keyboardShortcut(.defaultAction)` stays on Continue, Try Again and Eject only.
- **VoiceOver focus:** after each screen change the container posts
  `AccessibilityNotification.ScreenChanged` and `ScreenHeader` puts accessibility focus on the new
  screen's title (`@AccessibilityFocusState`), now marked as a header (`.isHeader`).
- **"Erase and Create" in Release:** `ReviewFooter` takes `canCreate`; when false the button is
  disabled with `.help("Available in a later version.")`.
- **UI tests:** a new `AssistantFlowUITests` walks the whole flow; `CreatingScreenUITests` and
  `DoneScreenUITests` reach their screens by navigating with `-simulationSpeed fast` (or normal
  speed when they need Creating to stay on screen). The Xcode template test in
  `RelenteUITests.swift` is replaced by the flow test.
- **No `.xcodeproj` edits:** the project uses synchronized folders.

## Task List

### Phase 1: Logic (test-driven)
- [x] Task 1: `AssistantStep`, `ScreenChange` and `Assistant` navigation and selections.
- [x] Task 2: `CreationService` and the simulated creation.
- [x] Task 3: `Assistant` runs a creation (progress, Done, Error, Stop, Try Again, Start Over,
  Eject).

### Checkpoint A: Logic
- [x] All unit tests pass; lint clean; Debug and Release builds with no warnings.

### Phase 2: Screens joined (no animation yet)
- [x] Task 4: `AssistantView` container, `DriveFooter`, `RelenteApp` wiring, `-startScreen`
  removed, "Erase and Create" disabled in Release.
- [x] Task 5: Installer label on the USB Drive screen.
- [x] Task 6: Simulation label on Creating, Error and Done.
- [x] Task 7: Keyboard: Esc and ⌘[ on Back, arrows on installers and drives.

### Checkpoint B: Walkable
- [x] Tests, lint and builds pass. The owner walks the whole flow in the running Debug app with
  the mouse and the keyboard (screens change without animation).

### Phase 3: Motion
- [x] Task 8: Slide and crossfade transitions, still footer, double-click guard, Reduce Motion.
- [x] Task 9: The drive travels (`matchedGeometryEffect`).
- [x] Task 10: The installer's icon travels.
- [x] Task 11: VoiceOver focus on the new screen's title.

### Checkpoint C: Motion
- [x] The owner compares the running app with option C of the canvas, in light and dark, Liquid
  Glass and classic, with Reduce Motion and with VoiceOver.

### Phase 4: UI tests
- [x] Task 12: `AssistantFlowUITests` (whole flow, Back keys, Return on Review).
- [x] Task 13: Creating and Done UI tests by navigation; Cancel → Error → Try Again / Start Over;
  VoiceOver of the new labels.

### Phase 5: Docs
- [x] Task 14: `docs/product.md`, BUILDING layout, README roadmap, spec Done,
  `specs/README.md`.

### Checkpoint D: Complete
- [x] Every acceptance criterion checked or recorded in Open items; Definition of Done in
  AGENTS.md met; ready for the owner to ask for a commit and PR.

## Risks and Mitigations
| Risk | Impact | Mitigation |
| --- | --- | --- |
| `matchedGeometryEffect` misbehaves when its views are inside screens that slide (jumps, doubles, the drive flying from the wrong place) | High | Task 9 starts with a spike on Drive → Review only. If it can't be made smooth, fall back to the canvas technique: one overlay in the container that draws the drive and the icon at frames reported by anchor preferences, animated between screens. The spec's behavior doesn't change either way. |
| Arrow keys need the row to have focus, which may fight with Tab or the focus ring | Med | `.focusable()` plus `.focusEffectDisabled()` on the row (the selection is already visible) and `.defaultFocus`; check Tab order by hand at Checkpoint B. |
| The invisible ⌘[ button is not triggered or shows up to VoiceOver | Low | Zero-size, `.accessibilityHidden(true)`, covered by the UI test of Task 12. Alternative: a "Back" menu command in the Go menu, which would also make ⌘[ discoverable. |
| UI tests are slow or flaky waiting for the simulation | Med | `-simulationSpeed fast` (about 2 s) and `waitForExistence` with generous timeouts; the Creating tests that need the screen to stay use normal speed. |
| Simulation code ending up in Release | High | The service file and the launch arguments are entirely inside `#if DEBUG`; the Release build of each checkpoint proves it compiles without them, and Release passes no service. |
| Animations on macOS 14–15 differ from macOS 26 | Low | Only standard SwiftUI transitions; the owner checks with `-classicControls YES` too (the window chrome is the same). |

## Rules check
- **Helper security:** not touched. The simulation calls no helper, no DiskArbitration, no
  `Process`; it only emits sample values, and only in Debug builds.
- **Architecture:** shared state is `@Observable` (`Assistant`), never `ObservableObject`; models
  are `nonisolated`, `Sendable`, `Equatable` value types; the service is a protocol injected
  through `init`, with a sample implementation (the simulation) and the live one in step 7; views
  take only the data they read; every new view has a `#Preview`. No `DispatchQueue`, no
  `Task.detached`: the creation runs in a task owned by `Assistant`, cancelled on Stop.
- **Platforms:** macOS 14 minimum kept: `withAnimation(completion:)`, `.onMoveCommand`,
  `.defaultFocus`, `AccessibilityNotification` and `@AccessibilityFocusState` exist on macOS 14.
  Liquid Glass only through the app's button styles.
- **Accessibility and localization:** new strings (installer label, simulation label, help tag)
  go to the String Catalog with Spanish and translator comments; "Erase and Create" is never the
  default action; Reduce Motion turns every change into a crossfade.

## Open Questions
None.
