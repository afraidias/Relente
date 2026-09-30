# 001 · Installer screen

**Status:** Done (written after the fact) · **Roadmap step:** 3 · **Branch:** none (built on
`main` before pull requests were required)

## Objective
Let the user pick which macOS installer to copy to the USB drive. First step of the assistant:
nothing else can happen without an installer.

## Behavior
- Centered title "Choose an Installer" and subtitle.
- The installers found appear side by side as Finder-style items: the file's real icon (or a
  generic one for its type if the file is missing), the macOS name, and "version · size" below.
- Clicking an item selects it: gray plate behind the icon, name in a blue capsule. Only one can be
  selected.
- Hovering an item shows its path.
- "Download from Apple…" secondary button below (does nothing yet).
- Footer: "Step 1 of 4 · Installer" on the left, "Continue" on the right, enabled when an
  installer is selected.

## Acceptance criteria
- [x] An installer's identity is its file URL, so re-detecting the same file keeps the selection.
- [x] Icons are read from disk once per item, not on every redraw.
- [x] All text is localized (English and Spanish).
- [x] Works on macOS 14 and later (classic buttons before macOS 26).

## Edge cases
- The installer file no longer exists → a generic icon for its type is shown.

## Out of scope
- Real installer detection (roadmap step 5).
- Download screen 1b (roadmap step 9).
- Navigation to the next step (roadmap step 4).
