# 006 · Assistant navigation

**Status:** Done · **Roadmap step:** 4 · **Branch:** `feature/006-assistant-navigation`

## Objective
Join the five static screens (001–005) into one assistant the user can walk through: Installer →
USB Drive → Review → Creating (+ Error) → Done, forwards and back, with the mouse or the keyboard,
and with animations that make it feel like one piece. Until roadmap step 7 there is no real
`createinstallmedia`, so the app must never pretend to erase or create anything: in Debug builds a
clearly labelled simulation stands in for it, so the whole flow can be walked and tested now; in
Release builds "Erase and Create" stays disabled until step 7.

This feature also closes the work earlier specs deferred to roadmap step 4 (see Open items of 003,
004 and 005).

The motion was chosen by the owner on a design canvas ("Relente · Assistant navigation",
option **C · Slide + the installer travels**), against a crossfade-only option and a version where
only the drive travels.

## Behavior

### Flow

| From | Action | Goes to | Transition |
| --- | --- | --- | --- |
| Installer | Continue | USB Drive | slide forward |
| USB Drive | Back | Installer | slide back |
| USB Drive | Continue | Review | slide forward |
| Review | Back | USB Drive | slide back |
| Review | Erase and Create (after confirming) | Creating | slide forward |
| Creating | the creation finishes | Done | crossfade |
| Creating | Cancel → "Stop" in the sheet | Error (reason "Cancelled") | none (same screen, state changes) |
| Creating | the creation fails | Error (its reason) | none (same screen, state changes) |
| Error | Try Again | Review | slide back |
| Error | Start Over | Installer | crossfade |
| Done | Eject | Installer | crossfade |

- The app always opens on the Installer screen (Permissions arrives in roadmap step 6 and is
  never reached from Done or Error).
- **Slide:** going forward, the new screen comes in from the trailing edge and the old one leaves
  by the leading edge; going back, the opposite. Start Over and Eject are jumps to the start, not
  steps, so they crossfade, and so does Creating → Done.
- **The footer doesn't move.** Only the screen's content slides or fades; the footer stays in
  place and its step indicator and buttons change.
- Leading and trailing follow the layout direction (in a right-to-left language the slide is
  mirrored).

### What travels between screens
Shared elements move between screens with `matchedGeometryEffect` (one `@Namespace` in the
assistant container), at the same time as the screens slide:

- **The chosen drive** flies from its place in the USB Drive list to the hero of Review, then to
  the hero of Creating (slightly smaller) and Done, and back along the same path with "Back" and
  "Try Again". Its halo changes color with the screen (blue, red on Error, green on Done).
- **The installer's icon** flies from its tile on the Installer screen to a new **installer
  label** on the USB Drive screen (below), then to the badge on the drive in Review, Creating and
  Done, and back along the same path with "Back". On Eject and Start Over it returns to its tile.

### New: installer label on the USB Drive screen
Changes the USB Drive screen built in spec 002. Under the screen's subtitle, a small gray capsule
with the chosen installer's real icon (16 pt), its name in semibold and its version and size in
secondary text, e.g. "macOS Tahoe 26.0 · 16.8 GB". It reminds the user what will go on the drive
and is the stop the installer's icon makes on its way to Review. It is not a control (clicking it
does nothing). VoiceOver reads it as one element: "Installer: macOS Tahoe 26.0, 16.8 GB".

### Selections
- The Installer screen starts with the first installer selected (as now).
- The USB Drive screen starts with **no drive selected** the first time; "Continue" is disabled
  until a pickable drive is chosen (spec 002).
- Going back keeps what was chosen: Back from USB Drive keeps the installer; Back from Review
  keeps the drive.
- Choosing another installer keeps the chosen drive only if it is still big enough for it;
  otherwise the drive selection is cleared.
- The Review checkbox is **unchecked every time** Review is shown, including after "Try Again"
  (spec 003): the erase is always confirmed again.
- **Start Over** and **Eject** go back to the Installer screen keeping the chosen installer and
  clearing the chosen drive.

### Keyboard
- **Return** triggers the screen's default action: Continue (Installer, USB Drive), Try Again
  (Error), Eject (Done). On Review, Return does nothing: "Erase and Create" is never the default
  action (AGENTS.md).
- **Back** answers **Esc** on USB Drive and Review (those screens have no Cancel button). It is
  also in a **Go** menu in the menu bar (Spanish: "Ir") as **Back ⌘[**, the standard Mac shortcut
  for going back, enabled only on those two screens. macOS moves ⌘[ to the same key position on
  other keyboard layouts (on a Spanish keyboard, the key right of P). On Creating, Esc keeps
  meaning Cancel (spec 004); on Installer, Error and Done, Esc does nothing.
- **Left and right arrows** move the selection between installers and between drives, skipping
  drives that can't be picked, without wrapping around. Tab still moves between controls as now.
- While a transition is running, buttons and shortcuts that change screen are ignored, so a
  double click or a held key can't skip a step.

### Creation until roadmap step 7

**Debug builds (⌘R in Xcode): a labelled simulation.**
- "Erase and Create" starts a **simulation**: nothing is erased, formatted or copied, and the
  helper is not involved. It runs through Format, Copy, Make bootable and Verify in about 15
  seconds, with plausible figures (COPIED, SPEED, REMAINING) from the sample data, and then goes
  to Done.
- A **simulation label** makes it impossible to mistake for the real thing: an orange capsule
  "SIMULATION · Nothing is erased" (Spanish: "SIMULACIÓN · No se borra nada") under the header of
  Creating, Error and Done while they show a simulated creation (screens built in specs 004 and
  005). VoiceOver reads it.
- Launch arguments (Debug only), for checking and for the UI tests:
  - `-simulateFailure driveDisconnected` makes the simulation fail partway through Copy with that
    reason, to see Error without cancelling.
  - `-simulationSpeed fast` makes it last about 2 seconds.
- The Debug-only `-startScreen` argument is removed: every screen is now reached by navigating.

**Release builds:** no simulation exists. "Erase and Create" stays disabled, with the help tag
"Available in a later version." (Spanish: "Disponible en una versión posterior."), so Creating,
Error and Done can't be reached. Roadmap step 7 replaces both with the real creation.

### Step indicator and selection
- **Step indicator:** one indicator stays in the footer across screens instead of being redrawn
  with each footer. When the step changes, the blue pill stretches to the new step, the dots fill
  in, and the step number rolls like a counter. The footer's buttons still swap at once.
- **Selection:** on Installer and USB Drive (specs 001 and 002), the gray plate and the blue name
  capsule slide from
  the previous item to the new one, with the mouse and with the arrows. Names are white exactly
  where the capsule is under them, as in a segmented control, so no name turns white late.

### Review's usage bar
Changes the usage bar built in spec 003. Chosen by the owner on the canvas (page "Usage bar",
option **C**) while building this feature:

- Above the bar, the drive's name as a section label on the leading side and its capacity on the
  trailing side ("SANDISK ULTRA … 32 GB").
- The bar is two segments with a 4 pt gap: the installer in the accent color, proportional to
  its share of the drive, and the free space in gray. The free segment keeps a minimum width, so
  it shows even when the drive is almost full.
- The legend gives each part's size: "● macOS Tahoe 16.8 GB" on the leading side and
  "● Free 15.2 GB" on the trailing side.
- VoiceOver still reads it as one element, now also saying what's left: "macOS Tahoe will use
  16.8 GB of 32 GB, 15.2 GB free".

### Changing figures
On Creating, the figures that change while the user watches roll like a counter
(`.contentTransition(.numericText(value:))` with a `.snappy` animation): the percentage under the
ring, COPIED, SPEED and REMAINING. Digits roll up when the figure grows and down when it shrinks
(REMAINING counts down). Not on the step indicator (the footer swaps at once by design), nor on
figures that don't change while shown (Review, STOPPED AT, Done's time).

### Reduce Motion
Nothing slides or flies: every screen change is a crossfade, and the drive and the installer's
icon simply appear in their new place with it. The figures change without rolling; the step
indicator and the selection crossfade instead of sliding.

## Acceptance criteria
Logic (unit tests on the assistant's model, without SwiftUI):
- [x] The assistant starts on Installer with the first installer selected and no drive selected.
- [x] Every row of the Flow table takes the assistant to the right screen, and the actions that
      aren't available on a screen do nothing (e.g. Continue on USB Drive without a pickable drive,
      Erase and Create without confirming).
- [x] Back keeps the installer and the drive; Start Over and Eject keep the installer and clear
      the drive.
- [x] Choosing an installer the chosen drive is too small for clears the drive.
- [x] The Review confirmation is unchecked every time Review is entered, including after Try
      Again.
- [x] Moving the selection with the arrows skips drives that can't be picked and doesn't wrap.
- [x] Each screen change reports its direction (forward, back) and kind (slide, crossfade) as in
      the Flow table.
- [x] The simulated creation goes through the four phases in order, its progress never goes
      backwards, it ends in Done with a result naming the chosen installer and drive, and with
      `-simulateFailure driveDisconnected` it ends in Error with that reason.
- [x] Cancel → Stop ends in Error with reason "Cancelled" at the percentage it had reached, and
      the simulation stops.

In the running app (UI tests, sample data, `-simulationSpeed fast`):
- [x] One UI test walks the whole flow: Installer → USB Drive → Review → Creating → Done → Eject →
      Installer, using Return for Continue and Eject.
- [x] UI test: Esc and Go › Back go back from USB Drive and from Review; Return on Review doesn't
      erase. (⌘[ itself is checked by hand: its key depends on the keyboard layout.)
- [x] UI test: on Creating, the Cancel sheet behaves as in spec 005 (Return and Esc keep going;
      only a click on "Stop" stops), and "Stop" shows Error; Try Again goes to Review with the
      checkbox unchecked; Start Over goes to Installer.
- [x] The existing VoiceOver UI tests for Creating and Done reach their screens by navigating
      instead of `-startScreen`.
- [x] VoiceOver reads the installer label as one element and the simulation label on Creating,
      Error and Done.

Checked by hand in the running app (Debug build):
- [x] The slides, the drive and the installer's icon move as in option C of the canvas, in light
      and dark mode, with Liquid Glass and with `-classicControls YES`. *(Motion: frames captured
      mid-animation, slowed down. Looks: every screen in the running app with Liquid Glass and
      classic controls, and rendered offscreen in dark mode.)*
- [x] With Reduce Motion on, every change is a crossfade and nothing flies (Creating → Done
      included), and the figures don't roll. *(Frames with Reduce Motion on in System Settings.
      The drive and the icon still flew; fixed by giving each screen its own copy of them under
      Reduce Motion.)*
- [ ] On Creating, the percentage, COPIED, SPEED and REMAINING roll like a counter, REMAINING
      downwards. *(Deferred, see Open items: Reduce Motion was on while checking, which turns the
      rolling off.)*
- [x] The step indicator's pill moves to the new step and its number rolls; the selection's plate
      and capsule slide to the new item. *(Frames captured mid-animation, slowed down.)*
- [x] Review's usage bar matches option C of the canvas, fits 800×560 in English and Spanish, and
      shows a free segment on an almost full drive. *(Offscreen renders: 32, 64 and 18 GB.)*
- [ ] VoiceOver: after each screen change the focus lands on the new screen's title, and Review
      reads as described in spec 003 (the check deferred from 003). *(What each element reads
      was checked in the running app, including Review and Creating, and Xcode's accessibility
      audit passes on this feature's new elements; where the focus lands needs VoiceOver itself:
      deferred, see Open items.)*
- [x] A Release build shows "Erase and Create" disabled with its help tag, and no simulation code
      is compiled in it. *(The "Can't create yet (Release)" preview; neither
      `SimulatedCreationService` nor its launch arguments are in the Release binary. The label
      view is compiled but never shown there: without a service, `isSimulated` is always false.)*

## Boundaries
- **Always:** keep the simulation and its launch arguments inside `#if DEBUG`, so a Release build
  can't erase or pretend to.
- **Never:** call the helper, DiskArbitration or `createinstallmedia` from this feature; the
  simulation touches no disk.

## Edge cases
- **Double click or held Return on Continue:** only one step is taken (changes are ignored during
  a transition).
- **Back from Review right after choosing a different drive:** impossible; Review always shows the
  drive chosen on USB Drive.
- **No drives (sample data can't produce it yet):** the USB Drive screen shows its empty state
  (spec 002); Back still works, Continue stays disabled; the installer label is still shown.
- **The chosen drive becomes too small after changing installer:** the selection is cleared and
  Continue is disabled until another drive is chosen.
- **Cancel sheet open when the simulation finishes:** the sheet closes and Done is shown; the user
  didn't stop it.
- **Window closed during a simulated creation:** the simulation stops with the window; asking
  before quitting is roadmap step 7 (spec 004).

## Out of scope
- Real disk and installer detection, unplugging a drive, ejecting for real: roadmap step 5.
- Permissions screen, helper, Touch ID / password prompt (and the `lock` symbol on Macs without
  Touch ID): roadmap step 6.
- The real creation, keeping the Mac awake, asking before quitting while creating: roadmap step 7.
- Download screen (1b) and "Download from Apple…": roadmap step 9; the button keeps doing nothing.

## Decisions
1. **Option C of the canvas: slide + the drive and the installer's icon travel.** Chosen by the
   owner over a crossfade-only version and one where only the drive travels. A slide tells the
   user they moved a step forward or back.
2. **The installer label on the USB Drive screen** is added so the installer's icon has somewhere
   to travel through (`docs/product.md` had it flying from step 1 straight to Review, skipping
   step 2, which isn't possible when screens change one at a time). It also reminds the user what
   will go on the drive. `docs/product.md` is updated to describe it.
3. **The footer stays still; only the content moves.** Like Apple's own assistants, the buttons
   stay where the hand is.
4. **Creating → Done, Start Over and Eject crossfade.** They are not a step to the side but an
   ending or a restart (Creating → Done was already deferred as a crossfade by spec 005).
5. **The creation is simulated only in Debug, and labelled.** Chosen by the owner so the app never
   deceives the user: the simulation exists only in builds made from Xcode, says so on screen,
   and Release builds keep "Erase and Create" disabled until roadmap step 7. It lets the whole
   flow, its animations and its UI tests be built and checked now.
6. **Back answers Esc and ⌘[.** USB Drive and Review have no Cancel button, so Esc (which always
   cancels, `docs/product.md`) takes the user back; ⌘[ is the standard Mac shortcut for Back.
   Apple's guidelines and its assistants place Back beside Continue, so USB Drive gets one too
   (spec 002's footer only had Continue).
   ⌘[ lives in a Go menu rather than on the button: a button takes only one shortcut, an invisible
   second button didn't receive it, and Apple's guidelines want shortcuts findable in the menu bar
   (Finder has the same Go › Back ⌘[).
7. **Selections are kept when going back, the confirmation never is.** Re-choosing is tedious;
   re-confirming an erase is the point.
8. **`-startScreen` is removed.** With navigation, a second way to open screens would let tests
   pass on screens the user can't reach the same way.
9. **Rolling figures** (asked by the owner while building the motion): only where a figure
   changes in front of the user, so the effect means "this is live".
10. **Animated step indicator and selection** (asked by the owner at the same time): the
    indicator is one view that outlives the footers, so the step can move instead of being
    redrawn; the selection slides because the plate and capsule are one shape that moves, like
    the drive between screens.
11. **Review's usage bar, option C** (asked by the owner while building): separating the two
    parts and giving their sizes in the legend makes the split readable at a glance. It changes
    Review's usage bar from spec 003; `docs/product.md` describes it as it is now, and spec 003
    isn't edited.

## Open questions
None.

## Open items
- **Roadmap step 5:** if the chosen drive is unplugged on USB Drive or Review, clear it and go back
  to USB Drive (from specs 002 and 003); eject for real on Done (spec 005).
- **Roadmap step 6:** show the `lock` symbol on "Erase and Create" on Macs without Touch ID
  (spec 005).
- **Roadmap step 7:** replace the simulation with the real creation, enable "Erase and Create" in
  Release, and remove the simulation label and its launch arguments (keep a sample service for
  previews and tests); everything else already listed in spec 004's open items. With Reduce Motion
  off, check by hand that Creating's figures roll (REMAINING downwards) once real progress drives
  them.
- **Roadmap step 8:** with VoiceOver on, check that after each screen change the focus lands on
  the new screen's title; part of the accessibility pass before the first release.
