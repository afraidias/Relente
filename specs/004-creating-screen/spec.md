# 004 · Creating screen (+ Error)

**Status:** Done · **Roadmap step:** 3 · **Branch:** `feature/004-creating-screen`

## Objective
Show the user, while the bootable installer is being made, that the work is progressing, how much
is left and which phase it's in, so they leave the drive plugged in and wait with confidence. If
it fails or is cancelled, say plainly where it stopped, why, that no other disk was touched, and
offer a way forward. Fourth step of the assistant (4) and its failure variant (4b). Like 001–003,
this feature builds the static screens with sample data; the real process arrives in roadmap
step 7.

## Behavior

### 4 · Creating

#### Header
- Centered title "Creating Installer" and subtitle "Keep the drive plugged in. This can take a
  while."

#### Hero
- The chosen drive's illustration (`HeroArtwork`, accent halo) with the installer's real icon as
  a badge, as on the Review screen.
- A **progress ring** around the illustration (`ProgressRing` component): an accent arc over a
  gray track, filled to the overall progress (see *Overall progress* below).
- Below it: the overall percentage, large, e.g. "43 %", and under it the drive's name and
  capacity, e.g. "SanDisk Ultra · 32 GB".

#### Three figures
Side by side, centered (`BigStat`), in the same content column as the Review screen (560 pt when
built; 640 pt since spec 005):

| Label | Value | Caption |
| --- | --- | --- |
| COPIED | Bytes copied so far, e.g. "7.2 GB" | "of 16.8 GB" (installer size) |
| SPEED | Current copy speed, e.g. "48 MB/s" | — |
| REMAINING | Estimated time left, e.g. "About 4 min" | — |

- COPIED and SPEED only move during Copy: before it, COPIED is "0 bytes" and SPEED "—"; after it,
  COPIED is the full installer size and SPEED "—".
- REMAINING estimates the time left in the **current phase**:
  - During Copy: bytes left ÷ speed.
  - During any other phase that reports a percentage: time spent in the phase so far × what's
    left ÷ what's done (e.g. 30 s at 25 % → about 90 s left).
  - "Calculating…" while there's nothing to estimate from yet (Copy with speed 0, or a phase at
    0 %).
  - "Almost done" in a phase after Copy that reports no percentage at all.
- REMAINING reads "Less than a minute" under 60 s and "About N min" above it.

#### Phase bar
- A bar under the figures (`PhaseBar` component) with four equal segments and a label under each:
  **Format**, **Copy**, **Make bootable**, **Verify**.
- Finished phases are filled in the accent color with a checkmark before the label; the current
  phase fills in proportion to its own progress and its label is bold; pending phases are a gray
  track with a gray label.
- VoiceOver reads it as one element: "Phase 2 of 4, Copy".

#### Overall progress
One number from 0 to 100 % for the whole process, used by the ring, the percentage and, on
failure, STOPPED AT. Each phase has a fixed weight:

| Phase | Weight | Progress within the phase comes from |
| --- | --- | --- |
| Format | 5 % | "Erasing disk: X%" |
| Copy | 85 % | "Copying to disk: X%" |
| Make bootable | 5 % | Its percentage if the command reports one; otherwise 0 until it ends |
| Verify | 5 % | Relente's own check (defined in roadmap step 7) |

- Overall = sum of the weights of the finished phases + current phase weight × its progress.
- The exact output of `createinstallmedia` (whether Make bootable reports a percentage, and the
  order of the phases) hasn't been checked yet; it will be with real runs in roadmap step 7. The
  model doesn't assume either: any phase may or may not report a percentage, and the order of the
  bar comes from one list that is easy to change.
- The percentage shown is rounded **down**, so it only reads "100 %" once everything is done.

#### Footer
- Left: "Step 4 of 4 · Creating" ("Step 4 of 4 · Creation" since spec 005: step names are nouns).
- Right: a **"Cancel"** button (secondary style). No button is the default action; Esc presses
  "Cancel" (since spec 005, as Apple's guidelines ask), which only opens the confirmation.
- "Cancel" asks for confirmation in an alert (since spec 005, a sheet that looks like a macOS
  alert; see spec 005):
  - Title "Stop creating the installer?"
  - Message "“SanDisk Ultra” will be left unusable until it's erased again."
  - Buttons **"Keep Going"** (the default action: Return keeps going) and **"Stop"**
    (`role: .destructive`). Esc does nothing (the alert stays open); see decision 8. Since spec
    005, Return and Esc both keep going, and only a click on "Stop" stops.
- For now "Stop" only closes the alert; going to the Error screen comes with navigation (roadmap
  step 4) and actually stopping the process with roadmap step 7.

### 4b · Error

Same layout as Creating, so the screen doesn't jump:

- Title "Couldn't Create the Installer". The subtitle is the **reason** (in the primary color)
  followed by **what to do** (gray), on one line, e.g. "The drive was disconnected. Plug it in
  again and try again." (decision 9). The sample reasons are:

| Reason | Reason line | What to do |
| --- | --- | --- |
| Drive disconnected | "The drive was disconnected." | "Plug it in again and try again." |
| Cancelled | "You stopped the process." | "Try again to erase the drive and start over." |
| Installer damaged | "The installer couldn't be verified." | "Download the installer again, then try again." |
| Verification failed | "The drive didn't pass the final check." | "Try again, or use a different drive." |
| Unknown | "Something went wrong while creating the installer." | "Try again. If it keeps happening, use a different drive." |

- Hero: the halo turns red (danger) and the ring is no longer drawn (its space is kept, so nothing
  moves; changed by spec 005, it was a red ring frozen where it stopped); the badge is a red
  `xmark.circle.fill` instead of the installer icon.
- Below it: the drive's name and capacity. The percentage moves to the figures; its space stays
  empty so nothing moves (decision 7).
- One figure, centered, instead of three: **STOPPED AT**, the overall percentage when it stopped
  (e.g. "43 %", danger red), with no caption: the phase bar already shows the phase it stopped in.
  The row keeps the height of the three figures, so nothing moves.

- The phase bar stays, frozen: finished phases filled, the failed phase in red up to where it
  stopped, the rest gray.
- Footer: "Step 4 of 4 · Creating" (now "Creation", spec 005), with the current step's pill in red
  (earlier steps stay blue: they did finish; since spec 005 every pill stays blue); **"Start Over"** (secondary) and **"Try Again"** (primary,
  default action: Return is safe because it only goes back to Review, where the checkbox has to be
  ticked again). For now both buttons do nothing.

## Acceptance criteria
- [x] Progress is computed in a model (`CreationProgress`: current phase, progress within the
  phase, bytes copied, installer size, speed) covered by tests: overall fraction from the weights;
  finished phases count in full; the result is clamped to 0…1; the percentage is rounded down (99.9
  % shows 99 %, only a finished Verify shows 100 %); overall never goes back when moving to the
  next phase.
- [x] Tests for REMAINING: bytes left ÷ speed during Copy; elapsed × left ÷ done in a phase that
  reports a percentage; "Calculating…" with speed 0 or a phase at 0 %; "Almost done" in a phase
  after Copy with no percentage; a phase with no percentage counts 0 toward overall until it ends.
  Tests for the "Less than a minute" and "About N min" thresholds.
- [x] The failure is a model (`CreationFailure`: reason, overall fraction and phase it stopped at)
  with a user-facing `LocalizedStringResource` title and recovery line for every reason; tested.
- [x] "Cancel" shows the confirmation alert; Return chooses "Keep Going"; neither Return nor Esc
  can choose "Stop", which is destructive and never the default.
- [x] On the Error screen, "Try Again" is the default action and "Start Over" is secondary.
- [x] New components `ProgressRing` and `PhaseBar`, each in its own file with a `#Preview`.
- [x] Previews: Format, early Copy (speed unknown), mid Copy, Make bootable, Verify; Error for
  "drive disconnected" and "cancelled"; the classic (macOS 14–15) look; light and dark.
- [x] Everything fits the 800×560 window without scrolling, in English and Spanish.
- [x] All text localized in English and Spanish, with translator comments on interpolated
  strings.
- [ ] With Reduce Motion, the ring and the phase bar change without animation; otherwise they
  animate smoothly between values. *(Implemented; the static screens never change values, so it's
  checked in the running app; see Open items.)*
- [ ] VoiceOver: the ring reads "Creating installer, 43 percent" as a progress value; each figure
  reads as "label, value"; the phase bar reads as one sentence; the Error screen's subtitle reads its reason
  and what to do. *(Labels implemented and checked in previews; see Open items.)*
- [x] `docs/product.md` updated: the Creating screen has "Cancel" with confirmation, and the Error
  screen has "Try Again" and "Start Over".

## Edge cases
- Speed 0 or unknown during Copy → SPEED "—", REMAINING "Calculating…".
- Bytes copied greater than the installer size (the real copy can be slightly larger) → COPIED
  shows the real bytes, but the Copy progress is clamped to 100 %.
- Estimates over an hour → "About 1 h 20 min" (system duration formatting).
- Failure during Format → STOPPED AT is at most 5 % and the Format segment turns red; the drive may
  still have its old data, but the message stays the same ("wasn't finished").
- Failure at 0 % → STOPPED AT "0 %".
- Very long drive names → truncated in the middle on one line, in the hero and in the alert;
  VoiceOver reads the full name.

## Out of scope
- Navigation between screens, the drive flying in from Review, and "Stop" / "Try Again" /
  "Start Over" actually moving (roadmap step 4).
- The real `createinstallmedia` process, parsing its output, measuring speed, the real Verify
  check, and keeping the Mac awake while creating (roadmap step 7).
- The helper and authorization (roadmap step 6).
- The Done screen (spec 005).

## Decisions
1. **Cancel with confirmation.** The user can stop, but only after being told the drive will be
   left unusable; "Keep Going" is the safe default.
2. **One weighted overall percentage** (Format 5, Copy 85, Make bootable 5, Verify 5) instead of
   restarting at 0 in each phase: the ring never goes backwards, and STOPPED AT is one clear
   number. Copy dominates because it's almost all of the time.
3. **REMAINING estimates the current phase from whatever it reports** (bytes and speed in Copy,
   elapsed time and percentage elsewhere) and says "Almost done" only when a phase reports
   nothing. It doesn't add later phases yet: their typical durations will be measured in roadmap
   step 7.
4. **Nothing is assumed about the command's exact output.** Whether Make bootable reports a
   percentage, and the order of the phases, will be checked with real runs in roadmap step 7.
5. **Verify is Relente's own check** after `createinstallmedia` finishes (the volume exists and
   holds the installer). This spec only shows the phase; how it checks is defined in roadmap
   step 7.
6. **Error offers "Try Again" and "Start Over".** "Try Again" returns to Review with the same
   drive and installer, so the erase is confirmed again; it can be the default action because it
   erases nothing by itself.
7. **The Error screen keeps the Creating layout** (hero, figures, phase bar) as `docs/product.md`
   describes, with STOPPED AT instead of the three figures and the reason in the subtitle.
   **Nothing moves** when it fails: both states are the same height, and the percentage under the
   hero keeps its (now empty) space, below the drive's name.
8. **In the Cancel alert, Return keeps going and Esc does nothing.** A native macOS alert gives
   each button a single key, so "Keep Going" can answer Return or Esc, not both (checked with a UI
   test while building). Return was chosen: it's the key people press by reflex, and Apple
   recommends making the safe button the default in destructive alerts. A custom sheet could take
   both keys but would look less native. *Changed by spec 005:* following Apple's guidelines
   (Esc always cancels), it's now a custom sheet where Return and Esc both keep going.
9. **The reason goes in the subtitle, not in a card or an alert, and there's no OTHER DISKS
   figure.** Chosen by the owner after seeing the screen: a card needed its space reserved while
   running (pushing the title against the ring), an alert on top of an error screen interrupts
   twice and hides the reason once dismissed, and "OTHER DISKS · Untouched" wasn't clear. The
   subtitle keeps the reason visible and frees the space.

## Open questions
None.

## Open items
- **Roadmap step 4:** make "Stop" go to the Error screen (reason "Cancelled"), "Try Again" go to
  Review and "Start Over" go to Installer; check VoiceOver and Reduce Motion in the running app.
  Add a UI test for the Cancel alert: Return keeps going, Esc leaves the alert open, and only a
  click on "Stop" stops (checked by hand with a temporary UI test while building 004). *Done in
  spec 005, for the sheet that replaced the alert (Return and Esc both keep going).*
- **Roadmap step 7:** run `createinstallmedia` for real (at least Big Sur, Sonoma and Tahoe) and
  record its exact output: whether Make bootable reports a percentage and the order of the phases;
  reorder the phase bar if needed. Measure how long Make bootable and Verify usually take, and if
  it's stable, add it to REMAINING during Copy and count it down afterwards. Feed
  `CreationProgress` from `createinstallmedia` and measure the speed;
  define the Verify check; tune the phase weights with real timings; map real failures to
  `CreationFailure` reasons; keep the Mac awake and ask before quitting or closing the window while
  creating.
