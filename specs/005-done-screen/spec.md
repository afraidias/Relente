# 005 · Done screen

**Status:** Done · **Roadmap step:** 3 · **Branch:** `feature/005-done-screen`

## Objective
Tell the user, once the bootable installer is made, that it's ready and what to do next: eject
it, plug it into a Mac and start up from it, showing which key to hold on the Mac's keyboard. Last step of the assistant (5). Like 001–004, this
feature builds the static screen with sample data; ejecting for real and moving between screens
arrive in later roadmap steps.

The whole app must look like one piece: no screen may look different from the rest. So Done is
built from the components the other screens already use (`ScreenHeader`, `HeroArtwork`,
`FileIcon`, `AssistantFooter`, `Theme`), and this feature also makes changes to earlier screens
for the same reason: one content width for every screen, no ring on the Error screen, icons on the
buttons whose action has a well-known symbol, and the fixes found by reviewing the whole app
against Apple's Human Interface Guidelines.

## Behavior

The design was chosen on a design canvas after several rounds, comparing it with renders of the
real screens ("Keyboard cards (owner's idea) in Done", and "Ayuda junto a la sección · contenido
por causas" for the help).

### 5 · Done

Same structure as Review and Creating: header, the drive as the hero, the content column below
it, and the footer.

#### Header
- `ScreenHeader`: title "Installer Ready" and subtitle "Eject it and plug it into the Mac where
  you want to install macOS. It took 12 minutes." (total time from the data).
- The time is the total from the start of Format to the end of Verify, written in full: "less
  than a minute" under 60 s, otherwise rounded to the nearest minute, e.g. "12 minutes",
  "1 minute", "1 hour, 5 minutes" (system duration formatting, full width).

#### Hero
- The drive's illustration (`HeroArtwork` at the size used on Review, 104 pt) with a **green**
  (success) halo and, as on Review and Creating, the installer's real icon (`FileIcon`) as the
  badge, with a small green checkmark on it.
- Below it, the name the drive now has, e.g. **“Install macOS Tahoe”** (`.body.weight(.semibold)`):
  `createinstallmedia` renames the volume, and that's the name the user will look for in the
  Mac's start-up options and in Finder.
- No progress ring and no capacity: it's finished, and the capacity no longer matters.

#### Start up from the drive
In the content column, the section label **START UP FROM THE DRIVE** (Spanish: "ARRANCAR DESDE EL
USB") and two cards side by side, one per kind of Mac. Each card has:

- **A strip of the keyboard** (a gray rounded band) with a few keys drawn as keycaps and the key
  to hold highlighted in the accent color (accent border, light accent fill, accent glyph):

  | Card | Keys shown (left to right) | Highlighted | After the keys |
  | --- | --- | --- | --- |
  | Apple silicon | F10, F11, F12, power | power (`power` symbol) | a small spinning-style arc (the start-up options loading) |
  | Intel | fn, control (⌃), option (⌥), command (⌘) | option | — |

  The keys are in the order they have on a Mac keyboard (the power button comes right after F12
  on Apple silicon keyboards; option sits between control and command). Modifier keys show their
  glyph and their name, as printed on the keyboard. The strip is decorative for VoiceOver.
- **A heading** with the kind of Mac and a small accent capsule saying when to press:
  - "Apple silicon" · **HOLD**
  - "Intel" · **AT START-UP**
- On the card that matches **this Mac**, a green **THIS MAC** capsule after the heading. Both
  cards are always shown, since the drive is often used on another Mac.
- **One or two lines of text:**
  - Apple silicon: "Hold the power button until you see the start-up options, then choose
    “Install macOS Tahoe”."
  - Intel: "Hold Option (⌥) right after turning on the Mac, then choose “Install macOS Tahoe”."

  (“Install macOS Tahoe” is the volume name from the data.)
- Cards are allowed for "How to boot" (`docs/product.md`). They're built from two new small
  components, each in its own file: `KeyCap` (one key: a label or symbol, optional name,
  highlighted or not) and `StartUpCard` (strip of keys, heading, capsules and text). They use the
  app's text styles and colors.

#### Help
- The **help button** (the standard round "?" button of macOS) sits in the footer's
  bottom-leading corner, before the step indicator, apart from the action buttons, where Apple's
  guidelines put it. It opens a popover anchored to it (above the button), titled
  "Drive not showing up at start-up?" (Spanish: "¿No aparece la memoria al arrancar?"), with one
  entry per cause; each has a system symbol in the accent color with no background, sized as
  Apple's guidelines say (the font of its title at the large symbol scale, on the title's
  baseline, in a fixed-width column), a bold title and one line:

  | Symbol | Title | Text |
  | --- | --- | --- |
  | `externaldrive.badge.plus` | Connection | "Plug it straight into the Mac, not into a hub, and try another port." |
  | `cpu` | Intel Mac with the T2 chip (2018–2020) | "Start up in Recovery (⌘R) and, in Startup Security Utility, allow booting from external media." |
  | `laptopcomputer` | Compatibility | "It only shows up on Macs that support macOS Tahoe." (the installer's name from the data) |

- It doesn't repeat what the cards already say (how long to hold the power button).
- The popover closes when clicking outside it or pressing Esc.

#### Footer
- `AssistantFooter`: the help button, then "Step 4 of 4 · Done"; every pill is blue, as on every
  screen.
- Right: only **"Eject"** with the `eject` symbol (primary, default action: Return is safe because
  ejecting erases nothing). It will eject the drive and return to the Installer screen, never to
  Permissions. For now it does nothing.

### Changes to earlier screens

#### One content width: 640 pt
- The column that holds the figures, bars, callouts and steps is **640 pt** on every screen
  (Review, Creating, Error and Done), instead of 560 pt. It's one value in `Theme`
  (`Theme.Sizes.contentWidth`), used by every screen and component preview instead of their own
  constants.
- Checked with renders of the real screens: Review, Creating and Error keep their balance at 640 pt.

#### 4b · Error without the ring
- The Error screen no longer draws the red progress ring: the red halo and the red badge already
  say it stopped, and STOPPED AT says where. The ring's space is kept, so nothing moves when
  Creating turns into Error. Spec 004 is updated to match.

#### Icons on buttons
A button gets an SF Symbol before its title when its action has a well-known system symbol that
adds meaning. Buttons that move through the assistant or dismiss (Continue, Back, Cancel) and the
buttons of alerts stay text only, as in macOS dialogs.

| Screen | Button | Symbol |
| --- | --- | --- |
| Installer | Download from Apple… | `arrow.down.circle` |
| Installer, USB drive | Continue | — |
| USB drive, Review | Back | — |
| Review | Erase and Create | `touchid` |
| Creating | Cancel | — |
| Creating (alert) | Keep Going, Stop | — |
| Error | Start Over | `arrow.uturn.backward` |
| Error | Try Again | `arrow.clockwise` |
| Done | Eject | `eject` |
| Done | Help | the standard round "?" help button |

- Both button styles show the symbol and the title, on Liquid Glass (macOS 26+) and on the classic
  look (macOS 14–15). VoiceOver reads only the title.

#### Apple's Human Interface Guidelines
The whole app was reviewed against Apple's Human Interface Guidelines for macOS. Most of it
already follows them (default button on the right and on Return, destructive buttons never
default, system colors and symbols, title-case buttons, "…" on buttons that ask for more input,
a fixed-size window). These changes follow from the review:

- **Esc presses "Cancel"** on the Creating screen (`.cancelAction`). It only opens the
  confirmation, so it's safe.
- **The cancel confirmation is a sheet that looks like a macOS alert,** instead of the native
  alert, so that Return *and* Esc keep going (a native alert gives each button one key; spec 004,
  decision 8). It slides down from the window's title bar and blocks it until answered, laid out
  like a macOS 27 alert (checked against the Finder's "Empty Trash" alert): the app's icon centered
  on top, then, leading, the title "Stop creating the installer?" in bold, the message
  "“SanDisk Ultra” will be left unusable until it's erased again." in the regular text color, and
  two large buttons (as in macOS alerts) side by side, of equal width,
  filling the sheet: **"Stop"** (secondary style, gray like the
  other choice in a macOS alert, `role: .destructive`, only a click) and **"Keep Going"** (primary, Return and Esc). For now
  "Stop" only closes the sheet.
- **The help button goes in the bottom-leading corner** of the window (see Done's Help).
- **Every step pill is blue,** on every screen. The current step's pill turned red on Error and
  green on Done; the halo, the badge and the title already say that, and the odd color clashed
  with the blue ones.
- Picking an installer or a drive with the arrow keys is part of navigation (roadmap step 4; see
  Open items).

#### Step names and Spanish wording
Every step name in the footer is a noun, in English and Spanish:

| Step | English | Spanish |
| --- | --- | --- |
| 1 | Installer | Instalador |
| 2 | USB Drive | Memoria USB |
| 3 | Review | Revisión (was "Revisar") |
| 4 | Creation (was "Creating") | Creación (was "Crear") |
| 5 | Done | Listo |

Step 2's footer arrives with navigation (roadmap step 4); it uses these names.

All Spanish text is Spanish from Spain (tuteo, Apple Spain's terms such as "tecla Opción" and
"opciones de arranque"). It was reviewed as a whole, and these texts change:

| English | Spanish before | Spanish now |
| --- | --- | --- |
| Make bootable (phase) | Hacer arrancable | Hacer booteable |
| START UP FROM THE DRIVE | ARRANCAR DESDE LA MEMORIA | ARRANCAR DESDE EL USB |
| Couldn't Create the Installer | No se pudo crear el instalador | No se ha podido crear el instalador |
| Keep Going (cancel alert) | Continuar | Seguir |
| Too small | Muy pequeña | Demasiado pequeña |
| This can't be undone. Other disks won't be touched. | No se puede deshacer. Los demás discos no se tocarán. | No se puede deshacer. No se tocará ningún otro disco. |
| Try again to erase the drive and start over. | Reinténtalo para borrar la memoria y empezar de nuevo. | Inténtalo de nuevo para borrar la memoria y empezar de cero. |
| Use a USB drive or SD card with at least %@. %@ or more works for any version of macOS. | …Con %2$@ o más sirve… | …Una de %2$@ o más sirve… |

"Booteable" isn't in the dictionary, but it's the word people use for a USB drive that starts up
a Mac; the owner chose it. Specs 002–004 describe English text, so only spec 004 notes a
change (the step name).

### Checking Done in the running app
Navigation arrives in roadmap step 4, so the running app can't reach Done yet. To check
VoiceOver and Reduce Motion in the running app now, Debug builds accept `-startScreen done`
(like `-classicControls`): the app opens on Done with the sample result and this Mac's
architecture. It's always off in Release. A UI test launches the app that way and checks what
VoiceOver reads.

## Acceptance criteria
- [x] The result is a model (`CreationResult`: installer, drive, total duration, volume name)
  covered by tests: the time reads "less than a minute" under 60 s, rounds to the nearest minute
  (89 s → 1 minute, 90 s → 2 minutes), and uses hours from 60 minutes; the volume name is
  “Install macOS Tahoe” for the Tahoe sample.
- [x] Which kind of Mac this is (Apple silicon or Intel) is a value that can be injected, so
  previews and tests can put THIS MAC on either card; the live detection reports Apple silicon even
  when the app runs under Rosetta. Tested with injected values.
- [x] "Eject" is the only button in the footer, primary and the default action (Return).
- [x] The help button sits in the footer's bottom-leading corner and opens the popover with the
  three causes (symbol, title, line); Esc or a click outside closes it.
- [x] Esc presses "Cancel" on Creating; the cancel confirmation is a sheet where Return and Esc
  keep going and only a click on "Stop" stops; covered by a UI test.
- [x] Step names are nouns (Review/Revisión, Creation/Creación) and the Spanish texts in the
  wording table are changed.
- [x] Every step pill is blue on every screen (no red on Error, no green on Done).
- [x] Done uses only existing components and `Theme` text styles, colors and sizes, plus the new
  `KeyCap` and `StartUpCard`, each in its own file with a `#Preview`; no fixed font sizes.
- [x] Each card shows its keys in keyboard order with the right key highlighted (power on Apple
  silicon, option on Intel), its heading and capsule, and THIS MAC only on the matching card.
- [x] `Theme.Sizes.contentWidth` is 640 and Review, Creating, Error and Done use it; no screen or
  preview keeps its own 560.
- [x] The Error screen has no ring, and switching between the Creating and Error previews moves
  nothing.
- [x] The buttons in the icons table show their symbol and title in both button styles; the others
  stay text only.
- [x] Previews: Done on Apple silicon, Done on Intel, a long drive name, a run under a minute, the
  help popover open, the classic (macOS 14–15) look, light and dark.
- [x] Everything fits the 800×560 window without scrolling, in English and Spanish, on every
  changed screen.
- [x] All text localized in English and Spanish, with translator comments on interpolated
  strings.
- [x] VoiceOver: the hero reads as one element ("Install macOS Tahoe, on SanDisk Ultra"); each
  card reads as one element, e.g. "Apple silicon, this Mac: hold the power button until you see
  the start-up options, then choose Install macOS Tahoe." (the key strip is not read); the help
  button reads "Help".
  Checked by a UI test in the running app (`-startScreen done`), which also checks that the key
  strips aren't read and that Esc closes the help popover.
- [x] Reduce Motion: nothing on this screen animates on its own; the popover appears without
  animation. Checked in the running app (`-startScreen done`) with Reduce Motion on: the popover
  fades in without moving (checked by the owner).
- [x] `docs/product.md` updated: the Done screen as built, the Error screen without the ring, and
  in the design system the 640 pt content width, the rule for icons on buttons and the new
  components. Spec 003 notes the new width; spec 004 the width and the ring change.

## Edge cases
- Very long installer names → the volume name under the hero is truncated in the middle on one
  line; the card texts wrap to three lines at most (“Install macOS Big Sur” is the longest);
  VoiceOver reads the full names.
- Spanish texts in the cards are longer → still three lines at most, checked in the Spanish
  preview; the capsules ("MANTÉN", "AL ENCENDER", "Este Mac") fit next to the heading.
- "Demasiado pequeña" is longer than "Muy pequeña" → the chip under a drive still fits on one
  line, checked in the Spanish preview of the USB drive screen.
- A run under a minute (a very fast drive, or in testing) → "It took less than a minute."
- A run over an hour (a slow USB 2 drive) → "It took 1 hour, 20 minutes."
- Big Sur installer on the drive → the same keys and tips apply.
- The installer file no longer exists (moved after creating) → `FileIcon` falls back to the
  generic icon of its type, as on the other screens.

## Out of scope
- Navigation: "Eject" going to the Installer screen, and the transition from Creating to Done
  (roadmap step 4).
- Ejecting the drive for real, and what happens if it can't be ejected (roadmap step 5, with real
  disk detection).
- Measuring the real duration and reading the real volume name (roadmap step 7).
- Which Macs each macOS version supports (a table per version): not planned yet; the help popover
  only says the Mac must support it.
- Notifying the user (notification or sound) when it finishes while the app is in the background
  (not planned yet; would be its own spec).

## Decisions
1. **Done follows the Review and Creating pattern** (header, hero, content column, footer).
   Earlier rounds tried cards with step lists, key figures, callouts, three "what's next" steps
   (approved first) and a picture of the start-up screen. Keeping Creating's exact layout so
   nothing moved was measured and dropped; moving from Creating to Done will be a crossfade
   (roadmap step 4).
2. **The hero shows the name the drive now has.** After `createinstallmedia` the drive is called
   “Install macOS Tahoe”, and that's what the user will look for when starting up the Mac.
3. **No progress ring on Done or Error.** A ring is a progress indicator; once it's finished or has
   stopped, the colored halo and the badge say it better. Error keeps the ring's space so nothing
   moves from Creating.
4. **No "Verified" figure and no capacity.** Done is only reached when Verify passed, so saying it
   again added nothing; the capacity no longer matters once the drive is made.
5. **Both start-up keys, with THIS MAC on the matching one.** The drive is often used on a
   different Mac. Detection uses the hardware (not the app's architecture), so a Mac with Apple
   silicon is never labelled Intel.
6. **Troubleshooting lives in a help popover, ordered by cause.** The hub and port advice, the T2
   setting and compatibility matter only when something goes wrong, so they're one click away
   instead of on the screen. A popover, not a sheet: three short entries don't need a modal. A
   first version listed four mixed tips; it was reordered by cause, dropped the tip that repeated
   the Apple silicon card, and added the missing step for T2 Macs (Recovery with ⌘R).
7. **Only "Eject" on the right; help in the bottom-leading corner.** A "Make Another" button was
   tried and dropped: it crowded the footer and "Eject" already leads back to the start. The help
   button was first next to "Eject", where it read as part of the main action, then next to the
   section label; it ended in the bottom-leading corner, where Apple's guidelines put it.
8. **One content width, 640 pt, for every screen.** 560 pt was too narrow for Done, and a second
   width would make screens differ. 700 pt was considered and rejected: too close to the window's
   edges, with figures too far apart. 640 pt was checked on the real Review, Creating and Error.
9. **Icons on buttons only where the symbol adds meaning.** Eject, download, retry, start over and
   Touch ID have symbols people know; "Continue", "Back" and "Cancel" read better as plain text,
   which is also how macOS dialogs do it. One rule for the whole app keeps screens alike.
10. **Start-up help as keyboard cards (the owner's design).** Replaced the three "what's next"
    steps after approval: showing the actual keys on a drawing of the keyboard, with the one to
    hold highlighted, answers "which key?" at a glance, and it's all native drawing (keycaps and
    SF Symbols), no images. "Eject and plug it in" moved to the subtitle, which is what steps 1
    and 2 said. Cards are allowed for "How to boot" in `docs/product.md`.
11. **Spanish from Spain, reviewed as a whole; step names are nouns.** The owner asked for every
    Spanish text to read as natural Castilian Spanish, so the whole catalog was reviewed and the
    texts in the wording table changed (e.g. "No se ha podido…" for something that just happened,
    "Seguir" so it isn't confused with "Continuar"). Step names mixed nouns, verbs and adjectives;
    they're now all nouns, in both languages. "Hacer booteable" uses the word people use.
12. **The app follows Apple's Human Interface Guidelines, always.** The owner asked for it, so the
    whole app was reviewed and the gaps fixed here (Esc on "Cancel", a confirmation sheet that
    takes Return and Esc, help in the bottom-leading corner, blue step pills). The rule goes into
    AGENTS.md and the Definition of Done in a separate `docs:` pull request, so it applies to
    every feature from now on; any exception is recorded in its spec's Decisions.

## Open questions
None.

## Open items
- **Roadmap step 4:** make "Eject" return to the Installer screen (never Permissions); crossfade
  from Creating to Done; add Done to the UI test that walks the whole flow; check Reduce Motion on
  the transition from Creating to Done; let the installers and drives be picked with the arrow
  keys (Apple's guidelines).
- **Roadmap step 5:** eject the drive for real (DiskArbitration) and handle a drive that can't be
  ejected (e.g. a Finder window using it).
- **Roadmap step 6:** on Macs without Touch ID, show a `lock` symbol on "Erase and Create" instead
  of `touchid`, since they'll be asked for the password.
- **Roadmap step 7:** measure the real total time, and read the real volume name that
  `createinstallmedia` leaves on the drive.
