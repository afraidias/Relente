# Implementation Plan: 005 · Done screen

Spec: [spec.md](spec.md) · Tasks: [tasks.md](tasks.md)

## Overview
Build the Done screen (5) as a static screen with sample data, and make three app-wide changes the
spec asks for so every screen looks alike: one 640 pt content width in `Theme`, no ring on the
Error screen, and SF Symbols on the buttons listed in the spec. The logic (total time text, volume
name, which Mac this is) lives in `nonisolated` value-type models tested with Swift Testing; two new
components (`KeyCap`, `StartUpCard`) and one screen file draw them. Nothing touches real disks or processes.

## Architecture Decisions

- **Models (in `Relente/Models/`, one type per file):**
  - `CreationResult`: `installer: InstallerSource`, `drive: Drive`, `duration: Duration`.
    Computed:
    - `volumeName: String` — `"Install \(installer.name)"`, e.g. “Install macOS Tahoe”: the name
      `createinstallmedia` gives the volume (read for real in roadmap step 7).
    - `durationText: LocalizedStringResource` — "less than a minute" under 60 s; otherwise the
      minutes rounded to the nearest one, formatted with
      `.units(allowed: [.hours, .minutes], width: .wide)` ("12 minutes", "1 hour, 5 minutes"),
      the same rounding as `RemainingTime`.
    - `static let sample` (Tahoe on the SanDisk Ultra, 12 minutes) for the previews.
  - `MacArchitecture`: `enum { case appleSilicon, intel }` with its display name, its capsule
    ("HOLD" / "AT START-UP") and its start-up text (with the volume name interpolated), all
    `LocalizedStringResource`; and `static let current`, read once
    with `sysctlbyname("hw.optional.arm64")`. That key is 1 on Apple silicon even when the app runs
    under Rosetta, so an Apple silicon Mac is never reported as Intel. Detection is two lines of
    system calls, so it stays a static value on the model rather than a service protocol; screens
    take the architecture as a parameter, so previews and tests inject either value.
- **One screen file, `Views/DoneView.swift`,** taking `result: CreationResult` and
  `thisMac: MacArchitecture`, with sections as separate `View` types in the same file, like
  `CreatingView`:
  - `DoneHero`: `HeroArtwork` at 104 pt (as on Review) with the success halo; the badge is the
    installer's `FileIcon` with a small green `checkmark.circle.fill` on its corner; below it the
    volume name. One accessibility element: "Install macOS Tahoe, on SanDisk Ultra".
  - `DoneStartUp`: the section label and the two `StartUpCard`s side by side in the content
    column; the card whose architecture equals `thisMac` shows THIS MAC.
  - `DoneFooter`: `AssistantFooter(step: 4, …, stepName: "Done", stepTint: success)` with only
    "Eject". The help button (`HelpLink`) and its popover belong to `DoneStartUp`, at the end of
    the section label's line (changed in Task 9b; it was first in the footer). Help is SwiftUI's `HelpLink` (the standard round "?" button, macOS 14+)
    opening a `.popover` owned by the footer (`@State private var isShowingHelp`); the popover is a
    small `DoneHelp` view with the title and four tips. `.popover` already closes on Esc and on a
    click outside, and follows Reduce Motion.
  - The header is `ScreenHeader` with an interpolated subtitle ("Eject it and plug it into the
    Mac you want to install. It took %@."), with a translator comment.
- **New components:**
  - `Components/KeyCap.swift`: one key, a rounded rectangle with a label (`"F10"`, `"fn"`) or an
    SF Symbol (`power`), and for modifiers the glyph over its name (`⌥` / "option"). `isHighlighted`
    draws the accent border, light accent fill and accent glyph, a bit larger than the other keys.
    Sizes are small fixed frames (it's a drawing), text uses `Theme` styles scaled with
    `.font(.caption2)` / `.font(.caption)`.
  - `Components/StartUpCard.swift`: the card for one `MacArchitecture`: a gray band with the
    `KeyCap`s for that architecture (and, for Apple silicon, a short accent arc after the keys),
    the heading with its accent capsule ("HOLD" / "AT START-UP") and the green THIS MAC capsule when
    `isThisMac`, and the text. The band is hidden from VoiceOver; the card reads as one element.
    The keys and texts per architecture come from `MacArchitecture` (name, capsule, text), so the
    card itself has no `if` per architecture beyond the key list.
  - Cards use a rounded rectangle with a thin separator-colored border, like the design, and system
    colors so dark mode works.
- **Content width:** `Theme.Sizes.contentWidth: CGFloat = 640`. `ReviewView` and `CreatingView`
  drop their `private let contentWidth = 560`; the `WarningCallout` and `PhaseBar` previews use the
  constant too.
- **Error without the ring:** in `CreatingHero`, when `isFailed`, the `HeroArtwork` sits in a
  frame the size of the ring (same diameter) instead of inside `ProgressRing`, so nothing moves.
  `ProgressRing` itself doesn't change. The ring's "Stopped" VoiceOver label goes away; STOPPED AT
  already reads where it stopped.
- **Icons on buttons:** each listed button becomes
  `Button { … } label: { Label("Eject", systemImage: "eject") }`. To make sure both styles show
  symbol and title (a bordered macOS button can drop the icon, and a toolbar-like context can drop
  the title), `PrimaryButtonStyle` and `SecondaryButtonStyle` apply `.labelStyle(.titleAndIcon)`,
  so the rule lives in one place. Buttons with plain text are unaffected. "Erase and Create" keeps
  its red tint and destructive role.
- **Previews** wrap the screen plus its footer at 800×560, as `CreatingScreenPreview` does:
  Apple silicon, Intel, long drive name, under a minute, help popover open (the popover can't be
  forced open from outside, so `DoneView` gets an `isShowingHelp` parameter for the preview), classic
  look, light and dark.
- **No `.xcodeproj` edits:** the project uses synchronized folders, so new files are picked up
  automatically.

## Task List

### Phase 1: Models (logic first, test-driven)
- [x] Task 1: `CreationResult` — time text and volume name, with tests.
- [x] Task 2: `MacArchitecture` — detection and the card texts for each value, with tests.

### Checkpoint A: Models
- [x] All unit tests pass; lint clean; Debug build with no warnings.

### Phase 2: App-wide changes on the existing screens
- [x] Task 3: `Theme.Sizes.contentWidth` = 640, used by Review, Creating/Error and previews.
- [x] Task 4: Error screen without the ring.
- [x] Task 5: Icons on buttons (button styles + Installer, Review, Error).

### Checkpoint B: Existing screens
- [x] Tests, lint and build pass. Owner checks Review, Creating and Error in the Xcode canvas
  (light, dark, classic, Liquid Glass): 640 pt, no ring on Error, icons on the buttons.

### Phase 3: Done screen
- [x] Task 6: `KeyCap` and `StartUpCard` components with `#Preview`s.
- [x] Task 7: `DoneView` (header, hero, start-up cards) with previews.
- [x] Task 8: `DoneFooter` with help popover and "Eject".
- [x] Task 9: Spanish translations; check that every changed screen fits 800×560 in both
  languages.
- [x] Task 9b: Help moved next to the section and ordered by cause; step names as nouns; Spanish
  wording review (added after the owner's review of Done).

### Checkpoint C: Done screen
- [x] Tests, lint, Debug and universal Release builds pass. Owner reviews Done in the canvas.

### Phase 4: Docs
- [x] Task 10: `docs/product.md` (Done, Error, content width, button icons, new components), spec
  status Done,
  `specs/README.md`, README roadmap line.

### Checkpoint D: Complete
- [x] Every acceptance criterion checked or recorded in Open items; Definition of Done in
  AGENTS.md met; ready for the owner to ask for a commit and PR.

## Risks and Mitigations
| Risk | Impact | Mitigation |
| --- | --- | --- |
| A button style drops the icon or the title on one macOS version | Med | `.labelStyle(.titleAndIcon)` in both styles; check both looks in the canvas (Liquid Glass needs the owner's eye: offscreen renders of glass buttons come out blank). |
| Spanish card texts or capsules don't fit in a 640/2 card | Med | Check in the Spanish preview; shorten the copy if a text needs more than three lines. |
| The keycap drawing looks crude next to real Mac keys | Med | Keep it simple and consistent (same radius, border and font for every key); tune sizes with the owner in the canvas. |
| The check on the installer badge looks cramped at badge size | Low | Keep it small and on the badge's corner; adjust size in the canvas with the owner. |
| `HelpLink` looks different from the mockup's "?" | Low | It's the system control, so it matches macOS; accept its look. |
| Removing the ring on Error changes the hero's height | Low | Frame the artwork at the ring's diameter; the "moves nothing" criterion is checked by switching previews. |

## Rules check
- **Helper security:** not touched; no disks, processes or helper code.
- **Architecture:** models are `nonisolated`, `Sendable`, `Equatable` value types; views take only
  the data they read; each section is its own `View` with a `#Preview`; no `ObservableObject`,
  no `DispatchQueue`. `MacArchitecture.current` is a static value, not a service (see above).
- **Platforms:** macOS 14 minimum kept; `HelpLink` and `.labelStyle(.titleAndIcon)` exist on
  macOS 14; Liquid Glass only through the app's button styles.
- **Accessibility and localization:** every string in the String Catalog with Spanish; "Eject" is
  the default action and erases nothing; VoiceOver labels as the spec lists.

## Open Questions
None.
