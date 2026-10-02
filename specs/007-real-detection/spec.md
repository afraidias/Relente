# 007 · Real disk and installer detection

**Status:** Done · **Roadmap step:** 5 · **Branch:** `feature/007-real-detection`

## Objective
Replace the sample installers and drives with what is really on the Mac, so the assistant shows
the user's own macOS installers and the USB drives and SD cards they plug in, live. Until now the
screens only showed sample data. Relente still erases nothing in this step: the helper (step 6)
and the real `createinstallmedia` (step 7) come later, and the Debug simulation keeps standing in
for the creation.

This feature also does the work earlier specs deferred to roadmap step 5: only USB drives and SD
cards are shown (spec 002), an unplugged drive is handled on USB Drive and Review (specs 002, 003,
006), and Done's "Eject" ejects for real, including when it can't (spec 005).

The design of the Installer screen's new parts was chosen by the owner on a design canvas
("Relente · Installer detection"): option **B** for the screen with installers (chosen at the
first screen review, replacing option A) and **C3** for the empty state. When approving the spec, the owner asked for USB Drive's empty state (2b) to be
aligned with C3, so both empty states look the same (artboard "2b · USB Drive empty state aligned
with C3").

## Behavior

### Installers

**Where they come from**
- **Found automatically:** every `Install macOS *.app` at the top level of `/Applications`. The
  folder is watched while the app runs: an installer that appears (a download from the App Store
  finishing, a copy dragged in) or disappears updates the screen by itself.
- **Chosen by the user:** clicking the **add square** (a dashed square with a plus, below) opens
  the standard open panel, which accepts an installer app, a `.dmg` that contains one, or an
  `InstallAssistant.pkg`. The same files can be **dragged from the Finder** onto the square, or
  anywhere on the empty state. A valid file is added to the list and selected. Choosing a file
  that's already listed just selects it. Chosen files are remembered until the app quits.
- Nothing else is searched (no Downloads folder, no Spotlight), so macOS never asks the user for
  permission to read their folders.

**What is read from each one** (in the app, never in the helper):

| Kind | Name and version | Size (shown, and used for the required drive size) |
| --- | --- | --- |
| `.app` | From the app itself, e.g. "macOS Sequoia", "15.6" | The app bundle's size on disk |
| `.dmg` | From the installer app inside it, mounted read-only and hidden (`hdiutil attach -readonly -nobrowse`), then detached | The installer app's size inside the image |
| `.pkg` | From the package's own description, without installing or expanding its payload | The size it says it installs |

- An installer older than macOS Big Sur (11) is **shown but not supported**: dimmed, not
  selectable by mouse or keyboard, with a red "Not supported" chip and "Needs macOS Big Sur or
  later" below it, always visible (like too-small drives in spec 002).
- A chosen file that isn't a macOS installer (or a `.dmg` without one inside, or a damaged one)
  isn't added; an alert says so: **"“Name” Isn't a macOS Installer"** with "Choose an installer
  app, a disk image that contains one, or InstallAssistant.pkg." and "OK".
- Order: newest macOS version first; installers of the same version keep the order they were
  found in. When the list first fills, the newest supported installer is selected.
- Checking that installers are signed by Apple is the helper's job, right before creating (helper
  rule 4, roadmap steps 6–7); detection doesn't do it.

### Installer screen (changes spec 001)

**With installers (option B of the canvas)**
- As built in spec 001, plus the unsupported state above.
- The last item of the row is the **add square**: a dashed rounded square with a `plus` symbol,
  the size and place of an installer's icon, with **no text** under it (the row is top-aligned so
  it lines up with the icons). It's a button, never selected: clicking it opens the open panel.
  While a file is dragged over it, its border and plus turn the accent color. Its help tag (on
  hover) and VoiceOver hint say "Choose or drop an installer app, disk image or
  InstallAssistant.pkg."; VoiceOver names it "Add Installer…".
- At the bottom, only "Download from Apple…", as in spec 001.

**No installers (option C3 of the canvas, revised)**
- The screen keeps its header ("Choose an Installer" and its subtitle). Below it, centered, a
  native empty state like USB Drive's 2b, with the **add square** in the symbol's place,
  **"No Installers Found"** and "Download one from Apple, or add one you already have." (one
  sentence: the waiting indicator below already says it will appear by itself).
- **"Download from Apple…"** as the primary button (it still does nothing until roadmap step 9,
  like on the screen with installers).
- Below them, a small spinner and **"Waiting for an installer…"**. When an installer appears in
  `/Applications`, or one is chosen, the screen switches to the list by itself.
- "Continue" is disabled.
- If every installer found is unsupported, the list is shown (not the empty state), with
  "Continue" disabled.

### One empty state for both screens (changes spec 002)
Installer's empty state (C3) and USB Drive's (2b) are the same component, `EmptyStateView`, so
they look and behave alike:

| Part | Installer (C3, revised) | USB Drive (2b) |
| --- | --- | --- |
| Screen header | "Choose an Installer" and its subtitle | "Choose a USB Drive" and its subtitle (2b had none) |
| Under the header | — | The installer label (spec 006), as on the screen with drives |
| Symbol | The add square | `externaldrive.badge.plus`, gray |
| Title (`.headline`-sized, bold) | "No Installers Found" | **"No USB Drive Connected"** (was "Connect a USB Drive") |
| Description | As above | "Use a USB drive or SD card with at least *N*. 32 GB or more works for any version of macOS." (as in spec 002) |
| Actions | "Download from Apple…" | none |
| Waiting indicator | "Waiting for an installer…" | "Waiting for a drive…" |

- The block is centered in the space left under the header, at the same place on both screens.
- VoiceOver reads the header first (as on every screen), then the empty state's title,
  description and actions.

### Drives

**Which drives are shown** (the rule spec 002 deferred here): whole physical disks that are
external and **removable media**, connected over **USB** or through an **SD card** slot or
reader (a built-in SD slot counts, although macOS reports it as internal). Never shown: the
boot disk, internal disks, disk images, network volumes, and external SSDs and hard drives (which
report fixed, not removable, media). Drives appear and disappear live as they are plugged in and
out (DiskArbitration), on every screen.

**Kind:** "SD card" when it comes through an SD slot; otherwise "USB drive".

**Name (changes spec 002)**
- The drive's title is the name of its volume as the Finder shows it, e.g. "Photos 2023". With
  several named volumes, the first one on the disk; with none, its model.
- Its **model** is the vendor and product name the drive reports, e.g. "SanDisk Ultra"; "USB
  Drive" when it reports none. An SD card's model is always "SD Card": what macOS reports is the
  reader, not the card.
- On Review and Creating, the line under the hero shows **model · capacity**, e.g.
  "SanDisk Ultra · 32 GB" (only the capacity when the title already is the model).
- On the USB Drive screen (option C of the canvas "Relente · USB drive data", chosen at
  Checkpoint D, then aligned), every drive has the same three lines under its title, so they line
  up across drives:

  | Drive | Line 1 | Line 2 | Line 3 |
  | --- | --- | --- | --- |
  | Has data | The model | Gray usage bar, filled to the space in use | "10.89 GB of 15.52 GB in use" |
  | Empty | The model | Gray usage bar, no fill | "Empty · 32 GB" |
  | Data of unknown size | The model | Gray usage bar, no fill | "Contents unknown · 15.52 GB" |
  | Too small | The model | The red "Too small" chip | "8 GB · needs 17.8 GB" |

  Line 1 is one line, cut with "…" if it doesn't fit (the full model in the help tag). When the
  title already is the model, line 1 says what kind of drive it is: "USB Drive" or "SD Card".
  Nothing on this screen is orange or green any more: the subtitle already says the drive will be
  erased, and Review is where the user confirms it. VoiceOver reads the name and the three lines
  (the bar itself is hidden from it).

**Space in use (changes spec 002)**
- The sum of the space used on every mounted volume of the drive, including APFS volumes in a
  container on it. It's read from the volumes' figures; Relente never lists the drive's files, so
  macOS never asks for access to removable volumes.
- **Empty** when that sum is **under 100 MB**: a freshly formatted drive always uses a little
  space for its own file system, so comparing with 0 would almost never say "Empty". A drive with
  no partitions at all is also empty.
- **Unknown amount:** if a partition holds data that can't be measured (not mounted: Linux
  formats, a locked encrypted volume, an unknown format), the drive **has data of unknown size**.
  The USB Drive screen says **"Contents unknown"** (see the table above) and Review's WILL BE
  ERASED shows **"Unknown size"** in orange. System partitions that never hold user data (such as EFI) don't
  count.
- The figures update live: if the drive is reformatted or files are added while Relente is open,
  its usage bar and Review's figures change.

### Many installers or drives (changes specs 001 and 002)
Chosen by the owner at Checkpoint D on the canvas "Relente · Many installers and drives" (option
1 + 3), after four installers and the add square overflowed the window. The same rule holds on
the Installer and USB Drive screens; on Installer, the add square counts as an item.

| Items | Layout |
| --- | --- |
| Up to 4 | One row of large items, as before (160 pt wide, 96 pt icons). |
| 5 or more | A grid of 5 columns of smaller items (118 pt wide, 64 pt icons), centered in the space under the header. |
| More than fit | The same grid scrolls vertically; the selected item is scrolled into view. Installers scroll from 11 items; drives, which show more lines each, from 6. |

- In the grid, Up and Down move the selection a row (5 items) among the items that can be chosen;
  Left and Right work as before.
- Under a small item, chips have no icon ("Too small", "Not supported"), so they fit; their text
  says what the icon would.
- When the grid scrolls, the items fade out over 16 pt at its top and bottom edges instead of
  being cut (the scroller doesn't fade), and the scrolling area keeps 24 pt from the header and
  20 pt from what's below it. Both asked by the owner when checking the grid in the app.
- The selection's plate and capsule slide as in a row (spec 006); the chosen item's artwork flies
  to the next screen from where it is. At rest, an item in the grid draws its own artwork, so it
  scrolls, fades and is clipped with the rest; it hands it to the assistant only while the screen
  changes (changes spec 006, where the assistant always draws it).

### Unplugging and plugging (changes specs 002, 003 and 006)

| Where | What happens |
| --- | --- |
| USB Drive | The unplugged drive disappears. If it was selected, the selection is cleared and "Continue" is disabled. If it was the last one, the screen switches to 2b by itself. |
| Review | Back to USB Drive (slide back, as with "Back") with no drive selected. VoiceOver announces "“Name” was disconnected." |
| Creating (Debug simulation) | The run fails with the existing reason "The drive was disconnected." |
| Error, Done | Nothing changes on screen. On Done, "Eject" then just returns to the Installer screen. On Error, "Try Again" goes back to USB Drive (slide back) with no drive selected instead of Review, even if the drive was plugged in again: after a disconnection the user picks the drive again. |
| A drive plugged in | Appears in the list wherever the user is; never selected by itself. |

The chosen installer disappearing works the same way: on USB Drive or Review the assistant goes
back to the Installer screen; on the Installer screen it disappears from the list and the newest
supported installer is selected.

### Eject (changes spec 005)
- "Eject" on Done unmounts every volume of the drive and ejects it, then returns to the Installer
  screen as before. While it works, "Eject" shows a small spinner and is disabled.
- **If macOS refuses** (e.g. a Finder window or another app is using it), Relente stays on Done
  and shows an alert like the Finder's: **"“Name” Couldn't Be Ejected"**, with the reason macOS
  gives (naming the app using it when macOS says which) and three buttons: **"Try Again"**
  (default, Return), **"Force Eject"**, and **"Cancel"** (Esc). Force Eject unmounts and ejects
  even if something is using the drive.
- If the drive is no longer connected, "Eject" returns to the Installer screen without an alert.
- In the Debug simulation, "Eject" ejects the real drive too (nothing was written to it).

### Sample data
- Previews, unit tests and the UI test use the sample installers and drives, never the Mac's.
- In Debug builds, the launch argument **`-sampleData YES`** makes the app use them instead of
  real detection, so the whole flow can be shown without installers or drives. Always off in
  Release. The sample installers include one older than Big Sur (Catalina), shown unsupported.
- With `-sampleData YES`, **`-sampleEmpty installers`** or **`-sampleEmpty drives`** starts with
  that list empty, so the UI test (and anyone checking the screens) can reach each empty state.

## Changes to earlier features
- **Spec 001 (Installer screen):** real installers instead of samples; the add square, by click
  or drag and drop; the unsupported state; the empty state (C3); order and default
  selection; with 5 or more items, a grid of smaller items that scrolls when needed.
- **Spec 002 (USB Drive screen):** 2b gets the screen header and the installer label above an
  empty state shared with Installer's, and its title becomes "No USB Drive Connected"; real drives, only USB drives and SD cards; the drive's title is
  its volume name; the capacity line and the status chips (orange "*N* will be erased", green
  "Empty") become three aligned lines: the model, a gray usage bar and its figures; only "Too
  small" keeps its red chip, in the bar's place, with "*N* · needs *M*" below; "Empty" means under 100 MB used; "Contents unknown" for an unknown amount; unplugging
  updates the screen; with 5 or more drives, the grid of smaller items (spec 002 said they'd
  wrap into a grid).
- **Spec 003 (Review screen):** "Unknown size" in WILL BE ERASED; the hero line is
  "model · capacity"; unplugging the drive goes back to USB Drive.
- **Spec 005 (Done screen):** "Eject" ejects for real, with a spinner and the alert when it fails.
- **Spec 006 (Assistant navigation):** the assistant's installers and drives change while it
  runs; in a scrolling grid the chosen item's artwork is drawn by the assistant only while the
  screen changes; artwork that one of the two screens has no place for (the drive between
  Installer and USB Drive) comes or goes with its screen instead of sliding in late on its own,
  which showed when a drive stayed chosen after going back (found at Checkpoint D); and starting
  over from Done or Error, nothing flies: the drive and the installer's icon fade with their
  screens, as the restart crossfades; the flow table gains "drive or installer disappears" → back to USB Drive or Installer.
- `docs/product.md` is updated (Installer screen, drive names, Eject).

## Acceptance criteria

**Installers**
- [x] An `Install macOS *.app` in `/Applications` appears on the Installer screen with its real
  name, version, size and icon; one added or removed while the app runs appears or disappears
  without relaunching. *(Checkpoint D: Sequoia 15.8.1 and Monterey 12.7.6 appeared while the app
  ran; Monterey moved out and back disappeared and reappeared.)*
- [x] The add square (click or drop) and the empty state (drop) accept an installer app, a `.dmg`
  containing one and an `InstallAssistant.pkg`, add it and select it; any other file shows the "Isn't a macOS
  Installer" alert and adds nothing. *(In the app: choosing Sequoia selects it without listing it
  twice; dropping another file shows the alert. The `.dmg` and the `.pkg` by hand: see Open
  items.)*
- [ ] A `.dmg` is mounted read-only and hidden to be read, and is always detached afterwards, also
  when reading fails. *(In the code: `hdiutil attach -readonly -nobrowse`, detached in a `defer`.
  Not checked by hand: the owner skipped the `.dmg` at Checkpoint D; see Open items.)*
- [x] Reading an installer's name, version and size from its files is covered by tests with
  fixture files (an app's `Info.plist`, a package description), including versions older than Big
  Sur being unsupported. *(`InstallerMetadataTests`, `MacOSVersionTests`.)*
- [ ] Unsupported installers are dimmed, show "Not supported" and "Needs macOS Big Sur or later",
  can't be selected by mouse or arrow keys, and VoiceOver reads them as dimmed. *(Catalina in the
  sample data: "macOS Catalina, 10.15.7 · 8,1 GB, No compatible, Requiere macOS Big Sur o
  posterior", not enabled, in the accessibility tree; arrows skip it in
  `AssistantDetectionTests`. Listening with VoiceOver: see Open items.)*
- [x] Installers are sorted newest first, and the newest supported one is selected when the list
  first fills (tested). *(`InstallerSourceTests`; Sequoia before Monterey in the app.)*
- [x] With no installers, the C3 empty state is shown with "Continue" disabled, and it switches to
  the list by itself when one appears. *(UI test with `-sampleEmpty installers`; in the app when
  Sequoia finished downloading.)*
- [x] Installer's and USB Drive's empty states use the same `EmptyStateView` and match the table
  in "One empty state for both screens" (header, symbol, title, text, waiting indicator).
  *(Compared in screenshots; VoiceOver reaches the add square since Task 16.)*

**Drives**
- [x] Only whole, external, removable disks over USB or SD appear; the boot disk, internal disks,
  disk images and fixed external drives never do. The filtering is a pure function of the disk's
  description, covered by tests for each case. *(`DriveCatalogTests`; in the app, an APFS
  drive shows once, not its synthesized container disk. No SD card or external SSD at hand.)*
- [x] Plugging in a USB drive or SD card adds it within a couple of seconds; unplugging removes
  it. *(A USB drive, at Checkpoint D; no SD card at hand.)*
- [x] The drive's title, model line, kind and identity (media UUID) come from the disk's
  description; naming rules are tested (volume name, first of several, model fallback, generic
  fallback). *(`DriveCatalogTests`; "USB", "TOSHIBA USB FLASH DRIVE" in the app.)*
- [x] Space in use: the sum over mounted volumes; under 100 MB is "Empty" (tested at 99 and
  100 MB); an unmeasurable partition gives "Contents unknown" and "Unknown size" on Review
  (tested); too small still beats having data. *(`DriveCatalogTests`, `DriveTests`,
  `ReviewSummaryTests`; 10.89 GB of 15.52 GB, then "Empty" after erasing as APFS, in the app.)*
- [x] Unplugging the selected drive on USB Drive clears the selection; on Review it goes back to
  USB Drive and VoiceOver announces it; during the simulation it fails with "The drive was
  disconnected." (tested on the assistant with a sample drive service). *(Also each case by hand,
  with VoiceOver and Reduce Motion on; "Try Again" afterwards goes to USB Drive, Decision 13.)*
- [x] The chosen installer disappearing on USB Drive or Review goes back to the Installer screen
  (tested).

**Eject**
- [x] "Eject" ejects the drive (it disappears from the Finder) and returns to the Installer
  screen. *(Checkpoint D, also with a Finder window open on the drive.)*
- [x] When the drive is in use, the alert appears with the reason; "Try Again", "Force Eject" and
  "Cancel" behave as described; Return never force-ejects. *(Checkpoint D, with a process holding
  the volume; macOS named no app, so the generic reason showed.)*
- [x] A drive already unplugged just returns to the Installer screen (tested).

**General**
- [x] Services are protocols with a live and a sample implementation, injected through `init`;
  tests and previews never touch real disks or `/Applications`.
- [x] `-sampleData YES` shows the sample data in Debug; the UI test walks the whole flow with it.
- [x] New strings are in English and Spanish; new views have previews (including the empty state,
  the unsupported installer, "Contents unknown", and the classic look).
- [x] Works in light and dark mode, with VoiceOver and with Reduce Motion. *(Checkpoint C for the
  screens; the usage bar in dark mode, Liquid Glass and classic, in screenshots; VoiceOver and
  Reduce Motion by the owner on USB Drive, Review and the Installer empty state.)*
- [x] Follows Apple's Human Interface Guidelines for macOS (checked on the empty state, the new
  button, the alerts). *(Decisions 8, 10 and 12.)*

## Boundaries
- **Always:** detection runs in the app, unprivileged; it only reads. Disk images are mounted
  read-only and hidden, and always detached.
- **Never:** write to a drive or an installer during detection; list the files on a drive; search
  folders other than `/Applications` without the user choosing a file.

## Edge cases
- **A drive without a media UUID** (some MBR-formatted drives): its identity comes from the
  vendor, model, serial number and capacity instead, so it stays the same when plugged in again.
- **Two drives with the same volume name** (e.g. two "UNTITLED"): both shown; the model line and
  the capacity tell them apart.
- **A USB card reader with no card:** no media, so nothing is shown until a card is inserted.
- **A USB drive that reports fixed media** (some fast USB sticks): hidden like an external SSD.
  Showing it is the "show all external drives" option, not in this step (Open items).
- **The drive Relente is installing to, renamed by the creation:** on Done the name shown is the
  new volume name (as already built in spec 005).
- **A `.dmg` that is already mounted:** it's read from where it's mounted, and not detached.
- **An installer still downloading** (an incomplete app in `/Applications`): if its files can't be
  read, it's not listed yet; it appears when complete.
- **A `.dmg` or `.pkg` chosen and then moved or deleted:** it disappears from the list like an
  installer removed from `/Applications`.
- **Many installers or drives:** the grid in "Many installers or drives".

## Decisions
1. **Search only `/Applications`, plus choosing or dropping a file.** Chosen by the owner: macOS asks for
   permission to read Downloads, Desktop and Documents, and a permission prompt in the first
   screen is a bad first impression. The open panel gives access to any file without a prompt.
2. **Detect `.dmg` and `.pkg` now, use them later.** Chosen by the owner: the screen shows
   everything the user has; creating from them needs the helper and is roadmap step 7.
3. **Installers older than Big Sur are shown dimmed**, not hidden, so the user knows why they
   can't be used (same pattern as "Too small").
4. **Empty state C3**, chosen on the canvas: the 2b look the app already has, under the screen's
   header, plus "Waiting for an installer…" because the folder is watched.
5. **Volume name as title, model below.** Chosen by the owner: the Finder shows the volume name,
   and that's how people recognize their drives; many models are generic ("USB DISK").
6. **"Empty" below 100 MB, from volume figures.** Chosen by the owner: file system overhead
   would otherwise make no drive "Empty", and reading the drive's files would trigger a macOS
   permission prompt.
7. **Unmeasurable data counts as data.** Chosen by the owner: the safe side; the user is warned
   something will be lost even when Relente can't say how much.
8. **An eject alert like the Finder's, with Force Eject.** Chosen by the owner. "Cancel" is added
   (Esc) because Apple's guidelines want an alert to be dismissable without acting; "Try Again" is
   the default because it's the safe action.
9. **Both empty states are one component.** Asked by the owner when approving: the two screens
   that wait for something look and behave the same. 2b gains the screen header, which it didn't
   have, so the title stays where it is on every other screen; its own title becomes "No USB
   Drive Connected" to pair with "No Installers Found", while the header already says what to do.
10. **An add square as the last item, not a button beside Download (option B).** Chosen by the
   owner at the first screen review: two buttons side by side competed with each other; an item
   in the row says "another one of these", and it can take a dropped file, as in the Finder. Then,
   at Checkpoint D, the owner removed its texts ("Other Installer…", ".app, .dmg or .pkg") and
   put it in the empty state in place of the symbol, replacing the "Already have one? Choose
   Installer…" link: the plus says "add" on its own, and the help tag explains it on hover. The
   texts of both empty states were shortened at the same time.
11. **Chosen installers aren't remembered after quitting.** Keeps this step small; remembering
   them needs security-scoped bookmarks (Open items).
12. **A gray usage bar instead of colored chips (option C).** Chosen by the owner at Checkpoint
   D, after seeing a real drive: the orange chip shouted on a screen where nothing is erased yet,
   and the long model wrapped the capacity onto a second line. Apple's guidelines keep color for
   what needs attention; here only "Too small" does, because it blocks the drive. The warning
   stays where the user confirms the erase (Review). Options A (gray text) and B (gray chip) are
   on the canvas. Then, seeing drives at different heights, the owner asked for three lines on
   every drive, always in the same place ("C · alineada" on the canvas): the kind of drive fills
   line 1 when the title is the model, and a too-small drive's chip takes the bar's place.
13. **After a disconnection, "Try Again" goes to USB Drive.** Chosen by the owner at Checkpoint
   D, where "Try Again" after unplugging during the simulation showed an empty Review: the drive
   is picked again rather than reselected by itself, the safe side for an app that erases disks.
   The other failures keep going back to Review (spec 004).
14. **Up to 4 large items in a row; from 5, a grid of smaller ones that scrolls if needed.**
   Chosen by the owner on the canvas (option 1 + 3): the large items fit 4 to a row in the
   800 pt window, and a second row of them wouldn't fit, so the grid shrinks the items (like
   the Finder's icon sizes) and scrolls only when even those don't fit. A horizontally scrolling row
   (option 2) was set aside: horizontal scrolling is hard to discover with a mouse.

## Open questions
None.

## Open items
- **Roadmap step 6:** the helper re-validates the drive (helper rule 3) and the Permissions
  screen; detection here is only what the app shows.
- **Roadmap step 7:** create from a `.dmg` (mounted read-only) and from an `InstallAssistant.pkg`;
  check the installer's Apple signature right before creating (helper rule 4). Check by hand that
  a real `.dmg` and `InstallAssistant.pkg` are read, and the `.dmg` detached afterwards (skipped
  at Checkpoint D of this spec).
- **Roadmap step 8:** listen with VoiceOver to an installer older than Big Sur (dimmed, "Not
  supported"); only its accessibility tree was checked, with the sample Catalina. Part of the
  accessibility pass before the first release (issue #25).
- **Roadmap step 9:** "Download from Apple…" (on both Installer states).
- **No roadmap step yet:** a "show all external drives" option for external SSDs, hard drives
  and USB sticks that report fixed media; remembering chosen installers across launches. Each
  goes in an `idea` issue if the owner wants it.
