# Product and design

What Relente is, the assistant's screen flow and the design system. Specs refer to this document
for the overall picture; each spec defines its own screen in detail. The rules for building it are
in [AGENTS.md](../AGENTS.md).

## Name

*Relente* is Spanish for the cool dew that falls at night. It was chosen because it was unused and
unrelated to the app's function. The name must never include "Mac" (Apple trademark).

## Scope

macOS installers only, from Big Sur (11) onwards: a local `Install macOS *.app`, a
`.dmg` or an `InstallAssistant.pkg`, and later a downloader using Apple's catalog. Destinations are
USB drives and SD cards only; external SSDs and hard drives are hidden by default. No Windows or
Linux.

## Supported Macs

Relente supports macOS 14 Sonoma and later, on Apple silicon and Intel (Release builds are
universal). `@Observable` needs macOS 14 and `SMAppService` macOS 13. Target users often have older
Macs: macOS 14 is the last version for several Intel Macs (e.g. MacBook Air 2018–2019), and
macOS 26, the last release for Intel, supports only four Intel models. Every year, when a new macOS
ships, review whether to drop the oldest version; drop it only if keeping it is costly (e.g. whole
screens duplicated for it) or almost nobody uses it.

## Screen flow

An 800×560 pt window. The top bar only has the window buttons; titles are
centered; the footer shows the step indicator on the left (dots plus "Step X of 4 · Name") and the
buttons on the right. The footer stays still when the screen changes: its buttons swap at once and
the step indicator animates (the pill stretches to the new step and the number rolls).

0. **Permissions** (first launch only): app icon; three permissions as Settings-style icons with a
   status badge (System helper, Signature verified, Full Disk Access + "Open Settings…"); a
   reassurance line about Touch ID.
1. **Installer:** the `Install macOS *.app` in `/Applications`, found live, as Finder-style
   options with the real file icon (`NSWorkspace.shared.icon(forFile:)`), newest first, the newest
   supported one selected; the selected one has a gray plate behind it and its name in a blue
   capsule, which slide to a newly selected item (names are white exactly where the capsule is, as
   in a segmented control). Installers older than Big Sur are dimmed with "Not supported" and
   can't be selected. The last item is the **add square** (dashed, with a plus, no text): click it
   to choose an installer app, `.dmg` or `InstallAssistant.pkg` anywhere, or drop one on it; any
   other file shows "Isn't a macOS Installer". With 5 or more items (the add square counts), they
   become a grid of 5 columns of smaller items, which scrolls when even those don't fit; Up and
   Down then move a row (the same on step 2). "Download from Apple…".
   1b. **Download:** grid of 4 versions, with a progress ring on the one downloading.
   1c. **No installers:** the same empty state as 2b, with the add square as its symbol (it also
   takes drops), "No Installers Found", "Download from Apple…" and "Waiting for an installer…";
   the list replaces it as soon as an installer appears.
2. **USB drive:** under the header, a small gray label reminds which installer was chosen (its
   icon, name, version and size); drives as large Finder-style illustrations with status labels,
   selected like installers. Only USB drives and SD cards are shown (whole, external, removable
   disks; never the boot disk, internal disks, disk images or external SSDs and hard drives), and
   they appear and disappear live as they're plugged in and out. Each shows its volume name and
   three aligned lines: its model (or "USB Drive" / "SD Card" when the name is the model), a thin
   gray usage bar, and "10.89 GB of 15.52 GB in use", "Empty · 32 GB" (less than 100 MB in use) or
   "Contents unknown · 15.52 GB"; no orange or green chips, since the erase is confirmed on
   Review. A drive that's too small has the red "Too small" chip in the bar's place and "8 GB ·
   needs 17.8 GB" below. "Back" and "Continue".
   2b. **No drive:** "No USB Drive Connected", an empty state that waits for one to be plugged in,
   with the screen header and the installer label above it.
3. **Review:** the drive as the hero; WILL BE ERASED / WILL BE INSTALLED / FREE AFTERWARDS; usage
   bar (the drive's name and capacity above it; the installer and the free space as two segments
   with a gap; a legend with each part's size); orange warning with a checkbox, unchecked every
   time Review is shown; "Back" and the red "Erase and Create" with the Touch ID symbol. If the
   drive is unplugged, the assistant goes back to step 2 and VoiceOver says so; if the installer
   disappears, on steps 2 or 3, back to step 1.
4. **Creating:** progress ring around the drive; COPIED / SPEED / REMAINING; a 4-phase bar
   (Format, Copy, Make bootable, Verify). The percentage and the three figures roll like a counter
   as they change. "Cancel" (also Esc) asks for confirmation in a sheet that
   looks like a macOS alert: "Keep Going" answers Return and Esc; "Stop", which leaves the drive
   unusable until it's erased again, only a click.
   4b. **Error:** same layout, nothing moves, in red: no ring (its space is kept), a red halo and
   badge, the reason and what to do as the subtitle, and "STOPPED AT X %". "Try Again" (default)
   returns to Review (to step 2 instead if the drive was unplugged, to pick it again); "Start Over"
   returns to the Installer screen.
5. **Done:** the drive with a green halo and the installer's icon, checked, as its badge; under
   it the name the drive has now ("Install macOS Tahoe"); the subtitle says to eject it and plug
   it into the Mac and how long it took. "Start up from the drive": one card per kind of Mac
   (Apple silicon, Intel) with a strip of its keyboard and the key to hold highlighted, "This Mac"
   on the matching one. A help "?" in the footer's bottom-leading corner opens a popover with the
   causes when the drive doesn't show up. "Eject" (default) ejects the drive and returns to the
   Installer screen, never to Permissions. If macOS refuses (the drive is in use), an alert gives
   the reason with "Try Again" (Return), "Force Eject" (click only) and "Cancel" (Esc).

Step pills are always blue, whatever the screen's state. Step names in the footer are nouns: Installer, USB Drive, Review, Creation, Done (Spanish:
Instalador, Memoria USB, Revisión, Creación, Listo). Spanish text is Spanish from Spain.

Moving between screens (chosen on a design canvas, spec 006): going forward, the new screen slides
in from the trailing edge; going back, from the leading edge. Creating → Done, "Start Over" and
"Eject" crossfade instead, since they're an ending or a restart. The chosen drive flies from its
place in the USB drive list to the hero of Review, Creating and Done; the installer's icon flies
from its tile to the installer label on step 2 and then to the badge on the drive. Both are drawn
once by the assistant over the screens, at places the screens mark (`SharedArtwork`). With Reduce
Motion, every change is a crossfade, nothing flies or rolls, and selections fade.

Keyboard: Return is the screen's default action (Continue, Try Again, Eject; never "Erase and
Create"). "Back" answers Esc and is in the menu bar as **Go › Back** (⌘[, which macOS moves to the
same key position on other keyboard layouts). Left and right arrows move the selection on steps 1
and 2, skipping drives that can't be used.

Until roadmap step 7, Debug builds simulate the creation (about 15 s, nothing is erased) and say so
with an orange "SIMULATION · Nothing is erased" label on Creating, Error and Done; Release builds
keep "Erase and Create" disabled with the help tag "Available in a later version."

Debug builds launched with `-sampleData YES` show sample installers and drives instead of the
Mac's (add `-sampleEmpty installers` or `-sampleEmpty drives` to see an empty state); tests and
previews always use them.

## Design system

- System colors so dark mode just works: accent (blue), success (green), warning (orange), danger
  (red), secondary.
- System text styles only, never fixed sizes (`Theme.Fonts`): title `.title.bold()` (22 pt), gray
  subtitle `.body` (13 pt), section labels `.subheadline.weight(.semibold)` (11 pt), small text
  `.callout` (12 pt).
- Reusable components, one `View` each (e.g. `StatusChip`, `HeroArtwork`, `PickItem`, `BigStat`,
  `PhaseBar`, `StepIndicator`, `WarningCallout`, `KeyCap`, `StartUpCard`).
- One content width for the column under the hero (figures, bars, callouts, cards):
  `Theme.Sizes.contentWidth` (640 pt), the same on every screen.
- Buttons: `.buttonStyle(.primary)` for the main action, `.buttonStyle(.secondary)` for others,
  `role: .destructive` for erasing. On macOS 26+ they are Liquid Glass capsules at the regular
  control size; on macOS 14–15, the classic bordered styles.
- Icons on buttons only when the action has a well-known system symbol that adds meaning
  (download, Touch ID, start over, try again, eject), shown before the title; "Continue", "Back",
  "Cancel" and alert buttons stay text only. Help is the standard round "?" button.
- Every screen follows Apple's Human Interface Guidelines for macOS; an exception is recorded in
  its spec's Decisions. Help buttons go in the bottom-leading corner; Esc always cancels.
- Progress rings only while something is in progress: a finished or stopped screen uses the halo
  and badge colors instead.
- Window: fixed 800×560 content under a hidden title bar. Every screen's header sits
  `Theme.Sizes.headerTopPadding` (28 pt) below it, clear of the window buttons.
- Cards only for grouping (Download, error details, "How to boot"); never for picking options or
  showing progress.
