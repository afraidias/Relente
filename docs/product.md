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
buttons on the right.

0. **Permissions** (first launch only): app icon; three permissions as Settings-style icons with a
   status badge (System helper, Signature verified, Full Disk Access + "Open Settings…"); a
   reassurance line about Touch ID.
1. **Installer:** Finder-style options with the real file icon
   (`NSWorkspace.shared.icon(forFile:)`); the selected one has a gray plate behind it and its name
   in a blue capsule. "Download from Apple…".
   1b. **Download:** grid of 4 versions, with a progress ring on the one downloading.
2. **USB drive:** drives as large Finder-style illustrations with status labels.
   2b. **No drive:** empty state that waits for one to be plugged in.
3. **Review:** the drive as the hero; WILL BE ERASED / WILL BE INSTALLED / FREE AFTERWARDS; usage
   bar; orange warning with a required checkbox; red "Erase and Create" with Touch ID.
4. **Creating:** progress ring around the drive; COPIED / SPEED / REMAINING; a 4-phase bar
   (Format, Copy, Make bootable, Verify). "Cancel" asks for confirmation ("Keep Going" is the
   default; "Stop" leaves the drive unusable until it's erased again).
   4b. **Error:** same layout, nothing moves, in red: a red badge, the reason and what to do as
   the subtitle, "STOPPED AT X %", and the current step's pill in red. "Try Again" (default) returns to Review; "Start Over"
   returns to the Installer screen.
5. **Done:** green badge, "Verified" and "Took X min", how to boot (Apple silicon / Intel).
   "Eject" returns to the Installer screen, never to Permissions.

The chosen drive's illustration travels between screens with `matchedGeometryEffect` (one
`@Namespace` in the assistant container); the installer tile from step 1 flies to the Review
badge. With Reduce Motion, a crossfade is used instead.

## Design system

- System colors so dark mode just works: accent (blue), success (green), warning (orange), danger
  (red), secondary.
- System text styles only, never fixed sizes (`Theme.Fonts`): title `.title.bold()` (22 pt), gray
  subtitle `.body` (13 pt), section labels `.subheadline.weight(.semibold)` (11 pt), small text
  `.callout` (12 pt).
- Reusable components, one `View` each (e.g. `StatusChip`, `HeroArtwork`, `PickItem`, `BigStat`,
  `PhaseBar`, `StepIndicator`, `WarningCallout`).
- Buttons: `.buttonStyle(.primary)` for the main action, `.buttonStyle(.secondary)` for others,
  `role: .destructive` for erasing. On macOS 26+ they are Liquid Glass capsules at the regular
  control size; on macOS 14–15, the classic bordered styles.
- Window: fixed 800×560 content under a hidden title bar. Every screen's header sits
  `Theme.Sizes.headerTopPadding` (28 pt) below it, clear of the window buttons.
- Cards only for grouping (Download, error details, "How to boot"); never for picking options or
  showing progress.
