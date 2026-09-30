# 003 · Review screen

**Status:** Approved · **Roadmap step:** 3 (static screen with sample data)

## Goal
Show the user, one last time, exactly which drive will be erased and what will end up on it, and make them confirm on purpose before anything is touched. Third step of the assistant, and the only one that can destroy data.

## Behavior

### Header
- Centered title "Review and Create" and subtitle "Make sure this is the right drive. Everything on it will be erased."

### Hero
- The chosen drive is the hero (new `HeroArtwork` component): its large illustration (USB drive or SD card) on a soft circular halo in the accent color, with the chosen installer's real icon as a **badge** on its bottom-trailing corner (the installer tile from step 1 will fly there in roadmap step 4).
- Below it: the drive's name and its capacity, e.g. "SanDisk Ultra · 32 GB".

### Three figures
Side by side, centered (new `BigStat` component: small uppercase label on top, large number below, optional caption under it):

| Label | Value | Caption | Color |
| --- | --- | --- | --- |
| WILL BE ERASED | Space in use on the drive, e.g. "9.8 GB" | — | Warning (orange); secondary gray when the drive is empty |
| WILL BE INSTALLED | Installer size, e.g. "16.8 GB" | Installer name, e.g. "macOS Tahoe" | Primary |
| FREE AFTERWARDS | Drive capacity − installer size, e.g. "15.2 GB" | — | Primary |

- An empty drive shows "Nothing" under WILL BE ERASED.
- FREE AFTERWARDS is never negative (clamped to 0). It's an estimate: the real figure depends on how `createinstallmedia` lays out the volume (measured in roadmap step 7).

### Usage bar
- A horizontal bar the width of the three figures showing the drive **after** creation: an accent-colored segment for the installer and a gray track for the free space, proportional to the capacity.
- A small legend under it: "● macOS Tahoe" and "● Free".
- VoiceOver reads it as one element: "macOS Tahoe will use 16.8 GB of 32 GB".

### Warning
- Orange callout (new `WarningCallout` component): warning icon, bold line "Everything on “SanDisk Ultra” will be permanently erased." and a second line "This can't be undone. Other disks won't be touched."
- Inside the callout, a checkbox: "I understand that all data on this drive will be lost." Unchecked every time the screen appears.

### Footer
- Left: "Step 3 of 4 · Review".
- Right: "Back" (secondary style) and a red **"Erase and Create"** button (primary style, `role: .destructive`, red tint).
- "Erase and Create" is disabled until the checkbox is checked. It is **not** the default action: Return must never erase a drive.
- For now both buttons do nothing (navigation is roadmap step 4; erasing, with Touch ID or password, is roadmap step 6).

## Acceptance criteria
- [x] The three figures are computed in a model type (`ReviewSummary`, built from an `InstallerSource` and a `Drive`) and covered by tests: erased = space in use; installed = installer size; free = capacity − installer size; free is clamped to 0; the bar fraction is installer size ÷ capacity, clamped to 0…1; an empty drive erases nothing.
- [x] "Erase and Create" is disabled while the checkbox is unchecked, and isn't triggered by Return. *(Checked with VoiceOver in roadmap step 4, when the screen is reachable in the app.)*
- [ ] VoiceOver: the hero reads the drive name and capacity; each figure reads as "label, value"; the usage bar reads as one sentence; the checkbox and buttons have clear labels.
- [x] New components `HeroArtwork`, `BigStat` and `WarningCallout`, each in its own file with a `#Preview`.
- [x] Previews: drive with data, empty drive, the classic (macOS 14–15) look, light and dark.
- [x] Everything fits the 800×560 window without scrolling, in English and Spanish.
- [x] All text localized in English and Spanish.

## Edge cases
- Empty drive → WILL BE ERASED shows "Nothing" in gray; the warning and checkbox stay (formatting still erases the drive).
- Installer larger than the drive → can't happen (too-small drives aren't selectable in step 2), but the model clamps FREE AFTERWARDS to 0 and the bar to full anyway.
- Very long drive or installer names → truncated in the middle with one line; the full name is still read by VoiceOver.
- The drive is unplugged while on this screen → go back to step 2. *(Needs real detection; roadmap step 5.)*

## Out of scope
- Navigation between screens and the drive/installer flying animation (roadmap step 4).
- Touch ID / password prompt and the actual erase (roadmap step 6).
- Checking the drive's fingerprint again before erasing (roadmap step 6).

## Decisions
1. WILL BE ERASED shows the space in use (matches the "9.8 GB will be erased" chip in step 2), not the whole capacity.
2. The Touch ID glyph on the button waits until the helper exists (roadmap step 6), because Macs without Touch ID ask for a password instead.
