# 007 · Real disk and installer detection

**Status:** Approved · **Roadmap step:** 5 · **Branch:** `feature/007-real-detection`

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
- Below the title, the line that showed the capacity now shows **model · capacity**, e.g.
  "SanDisk Ultra · 32 GB" (only the capacity when the title already is the model). The same line
  is used under the hero on Review and Creating.

**Space in use (changes spec 002)**
- The sum of the space used on every mounted volume of the drive, including APFS volumes in a
  container on it. It's read from the volumes' figures; Relente never lists the drive's files, so
  macOS never asks for access to removable volumes.
- **Empty** when that sum is **under 100 MB**: a freshly formatted drive always uses a little
  space for its own file system, so comparing with 0 would almost never say "Empty". A drive with
  no partitions at all is also empty.
- **Unknown amount:** if a partition holds data that can't be measured (not mounted: Linux
  formats, a locked encrypted volume, an unknown format), the drive **has data of unknown size**.
  Its chip says **"Data will be erased"** (warning, orange) and Review's WILL BE ERASED shows
  **"Unknown size"** in orange. System partitions that never hold user data (such as EFI) don't
  count.
- The figures update live: if the drive is reformatted or files are added while Relente is open,
  its chip and Review's figures change.

### Unplugging and plugging (changes specs 002, 003 and 006)

| Where | What happens |
| --- | --- |
| USB Drive | The unplugged drive disappears. If it was selected, the selection is cleared and "Continue" is disabled. If it was the last one, the screen switches to 2b by itself. |
| Review | Back to USB Drive (slide back, as with "Back") with no drive selected. VoiceOver announces "“Name” was disconnected." |
| Creating (Debug simulation) | The run fails with the existing reason "The drive was disconnected." |
| Error, Done | Nothing changes on screen. On Done, "Eject" then just returns to the Installer screen. |
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
  Release.

## Changes to earlier features
- **Spec 001 (Installer screen):** real installers instead of samples; the add square, by click
  or drag and drop; the unsupported state; the empty state (C3); order and default
  selection.
- **Spec 002 (USB Drive screen):** 2b gets the screen header and the installer label above an
  empty state shared with Installer's, and its title becomes "No USB Drive Connected"; real drives, only USB drives and SD cards; the drive's title is
  its volume name and the capacity line becomes "model · capacity"; "Empty" means under 100 MB
  used; the new "Data will be erased" chip for an unknown amount; unplugging updates the screen.
- **Spec 003 (Review screen):** "Unknown size" in WILL BE ERASED; the hero line is
  "model · capacity"; unplugging the drive goes back to USB Drive.
- **Spec 005 (Done screen):** "Eject" ejects for real, with a spinner and the alert when it fails.
- **Spec 006 (Assistant navigation):** the assistant's installers and drives change while it
  runs; the flow table gains "drive or installer disappears" → back to USB Drive or Installer.
- `docs/product.md` is updated (Installer screen, drive names, Eject).

## Acceptance criteria

**Installers**
- [ ] An `Install macOS *.app` in `/Applications` appears on the Installer screen with its real
  name, version, size and icon; one added or removed while the app runs appears or disappears
  without relaunching.
- [ ] The add square (click or drop) and the empty state (drop) accept an installer app, a `.dmg`
  containing one and an `InstallAssistant.pkg`, add it and select it; any other file shows the "Isn't a macOS
  Installer" alert and adds nothing.
- [ ] A `.dmg` is mounted read-only and hidden to be read, and is always detached afterwards, also
  when reading fails.
- [ ] Reading an installer's name, version and size from its files is covered by tests with
  fixture files (an app's `Info.plist`, a package description), including versions older than Big
  Sur being unsupported.
- [ ] Unsupported installers are dimmed, show "Not supported" and "Needs macOS Big Sur or later",
  can't be selected by mouse or arrow keys, and VoiceOver reads them as dimmed.
- [ ] Installers are sorted newest first, and the newest supported one is selected when the list
  first fills (tested).
- [ ] With no installers, the C3 empty state is shown with "Continue" disabled, and it switches to
  the list by itself when one appears.
- [ ] Installer's and USB Drive's empty states use the same `EmptyStateView` and match the table
  in "One empty state for both screens" (header, symbol, title, text, waiting indicator).

**Drives**
- [ ] Only whole, external, removable disks over USB or SD appear; the boot disk, internal disks,
  disk images and fixed external drives never do. The filtering is a pure function of the disk's
  description, covered by tests for each case.
- [ ] Plugging in a USB drive or SD card adds it within a couple of seconds; unplugging removes
  it.
- [ ] The drive's title, model line, kind and identity (media UUID) come from the disk's
  description; naming rules are tested (volume name, first of several, model fallback, generic
  fallback).
- [ ] Space in use: the sum over mounted volumes; under 100 MB is "Empty" (tested at 99 and
  100 MB); an unmeasurable partition gives "Data will be erased" and "Unknown size" on Review
  (tested); too small still beats having data.
- [ ] Unplugging the selected drive on USB Drive clears the selection; on Review it goes back to
  USB Drive and VoiceOver announces it; during the simulation it fails with "The drive was
  disconnected." (tested on the assistant with a sample drive service).
- [ ] The chosen installer disappearing on USB Drive or Review goes back to the Installer screen
  (tested).

**Eject**
- [ ] "Eject" ejects the drive (it disappears from the Finder) and returns to the Installer
  screen.
- [ ] When the drive is in use, the alert appears with the reason; "Try Again", "Force Eject" and
  "Cancel" behave as described; Return never force-ejects.
- [ ] A drive already unplugged just returns to the Installer screen (tested).

**General**
- [ ] Services are protocols with a live and a sample implementation, injected through `init`;
  tests and previews never touch real disks or `/Applications`.
- [ ] `-sampleData YES` shows the sample data in Debug; the UI test walks the whole flow with it.
- [ ] New strings are in English and Spanish; new views have previews (including the empty state,
  the unsupported installer, "Data will be erased", and the classic look).
- [ ] Works in light and dark mode, with VoiceOver and with Reduce Motion.
- [ ] Follows Apple's Human Interface Guidelines for macOS (checked on the empty state, the new
  button, the alerts).

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
- **Many drives:** the list wraps into a grid (spec 002).

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

## Open questions
None.

## Open items
- **Roadmap step 6:** the helper re-validates the drive (helper rule 3) and the Permissions
  screen; detection here is only what the app shows.
- **Roadmap step 7:** create from a `.dmg` (mounted read-only) and from an `InstallAssistant.pkg`;
  check the installer's Apple signature right before creating (helper rule 4).
- **Roadmap step 9:** "Download from Apple…" (on both Installer states).
- **No roadmap step yet:** a "show all external drives" option for external SSDs, hard drives
  and USB sticks that report fixed media; remembering chosen installers across launches. Each
  goes in an `idea` issue if the owner wants it.
