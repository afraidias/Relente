# 002 · USB drive screen

**Status:** Done · **Roadmap step:** 3 · **Branch:** `feat/drive-screen` (PR #8)

## Objective
Let the user pick the USB drive or SD card that will become the bootable installer, and make it
obvious which drives can be used and what will be lost. Second step of the assistant.

## Behavior

### 2 · Drives connected
- Centered title "Choose a USB Drive" and subtitle "Everything on the drive you choose will be
  erased."
- Each connected USB drive or SD card appears side by side as a Finder-style item: a large
  illustration (USB drive or SD card), the drive's name, its capacity, and a status chip:

| Status | When | Chip | Can be picked |
| --- | --- | --- | --- |
| Will erase | It has data | "9.8 GB will be erased" (warning, orange) | Yes |
| Empty | Nothing on it | "Empty" (ok, green) | Yes |
| Too small | Capacity below the required size | "Too small" (error, red) | No |

- Being too small wins over having data.
- **Ejected drives aren't shown.** Once ejected, a drive disappears from the system.
- **Required size** = the installer's size + 1 GB of headroom. Apple doesn't give a figure per
  macOS version; its guide only says that *"a 32GB flash drive has more than enough storage space
  for any macOS installer, and 16GB is enough for most earlier versions of macOS"*
  ([Create a bootable installer for macOS](https://support.apple.com/en-us/101578)). A recent
  installer (~17 GB) needs a 32 GB drive; an older one (~12.5 GB) fits on a drive sold as 16 GB
  (~15.5 GB real).
- Too-small drives are dimmed and don't respond to clicks. Below the chip they show the size
  needed ("Needs 17.8 GB"), always visible: macOS doesn't show tooltips on disabled controls.
- Selection works like the Installer screen: gray plate and blue capsule, one at a time.
- Footer: "Step 2 of 4 · USB Drive", "Continue" enabled only when a pickable drive is selected.

### 2b · No drive connected
- Native empty state: a drive icon, "Connect a USB Drive", and "Use a USB drive or SD card with at
  least *N*. 32 GB or more works for any version of macOS." where *N* is the required size.
- A small "Waiting for a drive…" indicator. When a drive is plugged in (roadmap step 5), the
  screen switches to state 2 by itself.

## Acceptance criteria
- [x] Status rules are implemented in the model and covered by tests (including a drive exactly
  the required size being accepted, and too small winning over having data).
- [x] Required size = installer size + 1 GB. Tested against Apple's guidance: a drive sold as
  16 GB fits an older installer, and 32 GB fits a recent one.
- [x] A drive's identity is its media UUID, not its BSD name (`disk4` can change when it's
  plugged in again).
- [x] Too-small drives can't be selected, by mouse or keyboard, and VoiceOver reads them as
  dimmed.
- [x] Previews: drives with every status, the classic (macOS 14–15) look, and the empty state.
- [x] All text localized in English and Spanish.

## Edge cases
- Two drives with the same name → both shown; the capacity tells them apart.
- More drives than fit in one row → they wrap into a grid (handled with real data).

## Out of scope
- Real drive detection with DiskArbitration (roadmap step 5).
- Showing external SSDs/HDDs behind an option (later).
- Navigation and the drive illustration flying to the next screen (roadmap step 4).

## Decisions
1. Required size: installer + 1 GB, based on Apple's guide; recommend 32 GB in the empty state.
2. Too-small drives: shown dimmed.
3. Ejected drives: not shown.

## Open items
- **Roadmap step 5:** only USB drives and SD cards are ever shown (never internal disks or
  external SSDs/HDDs); the selected drive being unplugged clears the selection and disables
  "Continue".
- **Roadmap step 7:** measure the space `createinstallmedia` really needs and adjust the
  installer + 1 GB rule if it's larger.
