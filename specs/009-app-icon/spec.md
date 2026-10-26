# 009 · App icon

**Status:** Approved · **Roadmap step:** 8 (visual polish before the first release) · **Branch:** `feature/009-app-icon`

## Objective

Replace Relente's multicolor arrow-and-slot icon with the owner-selected B design: an ivory dew
droplet with a lowercase “r” cut out of it, on an ink-blue background. Give the app and its
repository presentation one consistent identity, connected to the meaning of Relente.

## Behavior

- The app uses the new icon wherever macOS presents its bundle icon, including Finder, Dock,
  application switching and system dialogs that display it.
- The app's alert sheets also read the shared bundle icon.
- The Permissions hero continues to read the app's bundle icon, keeping its existing halo,
  status badge and accessibility behavior.
- The README shows a regenerated 512 × 512 PNG exported from the finished Icon Composer asset.
- Default appearance uses ink blue `#24364D` and ivory `#F4F1E9`, defined in sRGB. The default
  palette stays the same in light and dark mode. System Clear and Tinted appearances retain the
  same recognizable silhouette and negative-space letter.
- The letter has the selected B construction: a flat-topped upright projecting above a curved
  shoulder, a firm terminal and minimal corner softening. Its stem opens through the bottom of
  the droplet. Rounded B1/B2 and the abstract A construction are not the chosen design.

## Design reference

[Selected B, vector reconstruction](design-reference.svg) records the approved visual direction.
It is a design reference, not a production icon: its rounded tile is only a presentation mockup.
The production foreground is the outlined droplet with a transparent, open letter cutout; the
background is a separate full-bleed fill configured in Icon Composer. Optical adjustments may
improve small-size clarity while preserving the selected B design.

## Changes to earlier features

- **spec 008:** replace the artwork displayed by the Permissions hero through the shared app
  icon resource. Its screen layout, helper statuses and behavior stay as specified there.
- Update `docs/product.md` with the new identity and `BUILDING.md` with its asset structure,
  appearance configuration and README export procedure. Do not rewrite earlier specifications.

## Acceptance criteria

- [x] `Relente/Resources/AppIcon.icon` contains the new outlined vector foreground and ink-blue
      background; no arrow, slot or rainbow layers remain in the active icon asset.
- [ ] The compiled app displays the new icon in Finder, Dock, application switching and the
      Permissions hero. Check relevant system dialogs without performing a disk erase.
- [x] The drop and open letter remain distinguishable at 32, 64 and 128 px; at 16 px the drop
      silhouette and open counter remain recognizable rather than merging into a solid blob.
- [ ] The icon is visually checked on light and dark backgrounds and in Default, Dark, Clear
      and Tinted appearances supported by the installed macOS/Icon Composer.
- [ ] On macOS 14–15 the compiled fallback preserves the design. Record the actual OS versions
      tested; an unavailable OS must not be reported as verified.
- [ ] The Permissions hero and badge are visually checked with classic controls and the current
      macOS appearance, including Reduce Motion and VoiceOver; no new announcement is introduced
      for the decorative mark and the existing status information remains accessible.
- [x] `.github/assets/icon.png` is a 512 × 512 export of the final icon, and an inventory confirms
      no other active project presentation uses the old artwork.
- [x] `docs/product.md` and `BUILDING.md` describe the new icon accurately; update README content
      only where needed, keeping the existing image path and alt text.
- [x] Debug tests, universal Release build and strict swift-format lint pass using AGENTS.md's
      commands. No new logic or automated tests are required for this artwork-only change.
- [ ] The spec and index become Done in the final commit of their own PR, before merging.

## Boundaries

- Limit implementation to icon resources, their presentation and associated documentation.
- Preserve app identifiers, signing, release/CI settings, deployment target, system accent color,
  helper security and disk/installer illustrations. Add no app dependency or runtime icon selector.
- Keep the existing `.icon` integration; never ship the flattened comparison mockup as the source.

## Edge cases

- Finder and Dock may cache an older installed build's icon. Verify the newly built bundle first;
  use a normal relaunch or refresh for inspection without changing bundle identity.
- Clear and Tinted modes can change colors. Preserve the silhouette and readable open counter;
  the exact default blue and ivory palette is required only for the default appearance.
- Icon Composer effects must not visually fill the letter cutout or obscure it at small sizes.

## Decisions

1. **Owner-selected B, 2026-10-26.** The owner chose the dew/drop and lowercase letter concept,
   ink blue with ivory, and the original firm letter over the more rounded variants.
2. **Keep one source of truth.** Use the existing app icon resource for the Permissions hero
   and export the README PNG from that same finished icon.
3. **Apple HIG review.** Reviewed [App icons](https://developer.apple.com/design/human-interface-guidelines/app-icons)
   on 2026-10-26: use a centered, simple mark, outlined SVG foreground, full-bleed background,
   system masking and system visual effects. Do not bake rounded tile edges, shadows, bevels or
   highlights into production layers. Very small corner softening can prevent brittle raster
   edges without adopting the rejected rounded letter. No deliberate HIG exception is proposed.
4. **Separate feature.** This is visual polish associated with roadmap step 8, not an expansion
   of helper security work in spec 008. It does not mark roadmap step 8 complete.
5. **Prior work checked.** Earlier specs' Open items contain no deferred icon redesign. Open
   `idea` issues checked on 2026-10-26 (#19, #20, #25, #29) do not request this redesign; their
   independent work stays outside this spec.

6. **Liquid Glass approved, 2026-10-26.** The owner approved the real Icon Composer macOS 26
   preview of B. Preserve this restrained glass direction and verify the production asset.

## Open questions

None. Approved by the owner on 2026-10-26.

## Open items

None deferred by this feature. This icon exploration is not a trademark clearance or a claim
that no other product uses a similar mark.

## Implementation evidence · 2026-10-26

- Installed one outlined `RelenteMark.svg` foreground, a solid sRGB blue background and the
  approved glass settings. Removed all five old foreground SVGs. The production asset exports
  through Icon Composer; README PNG is 512 × 512 and comes from that asset.
- Added explicit Dark background/foreground fills after the automatic variant produced a
  low-contrast blue mark on black. Default and Dark now preserve the approved blue/ivory identity.
- Exported and inspected macOS 26 Default, Dark, ClearLight, ClearDark, TintedLight and TintedDark
  on both light and dark surrounding backgrounds. The system tint preview colors are not the default
  brand palette. Exported and inspected Default at 16, 32, 64 and 128 px; the open counter remains
  visible.
- Unit test result: 266 tests, 325 runs including parameterized cases, zero failures and zero
  skips, on macOS 27.0.1 arm64. Final test run and universal Release build succeeded. Release
  executable contains x86_64 and arm64. Strict swift-format lint and `git diff --check` pass.
  First clean builds emitted Apple's App Intents metadata-extraction notices; final incremental
  validation logs contain no warnings or errors. No settings were changed to suppress them.
- Extracted the Debug bundle's generated `AppIcon.icns` with `iconutil` and inspected its 128 px
  compatibility rendition. This checks the generated asset, not runtime behavior on older OSes.
- Observed the newly built app's Permissions screen on macOS 27.0.1 in its current dark UI:
  the new icon and halo display correctly. Its accessibility tree exposes the existing status
  and action, without exposing the decorative logo as an additional named element. No helper
  approval or disk erase was performed. Checked the newly built Debug app icon in Finder's icon
  view and Get Info. Dock and app switching remain unchecked. This observation used the normal
  app startup, not the planned sample-data inspection; remaining UI checks should use sample data.
- Checked the normal Debug flow through its installer and empty-USB screens on macOS 27.0.1 in
  dark and light appearance. With Reduce Motion on, the flow reached the empty-drive screen. With
  VoiceOver on, its accessibility tree exposed the installer selection, empty-drive status and
  disabled Continue action. Restored the original system settings: dark appearance, Reduce Motion
  off and VoiceOver off. No external drive was connected; no helper action or erase was performed.
- `PermissionsHero` and `AlertSheet` both consume `applicationIconImage`; no Swift code or
  project build settings changed. Product and build/export documentation are updated.

### Outstanding verification and integration

- Complete safe sample-data review of the Permissions hero in light/dark mode and classic controls,
  plus Reduce Motion, ready/error badges, VoiceOver announcements and safely reachable alert sheets.
  Dock and app switching remain unchecked. Keep Task 3 and its acceptance criteria unchecked until
  reviewed.
- Check runtime behavior on macOS 14 and 15, and macOS 26 itself if available; the current host is
  macOS 27.0.1 and the macOS 26 evidence above is Icon Composer rendering only.
- Wait for spec 008 to be integrated, reconcile shared docs/index with its final main state and
  rerun checks on the combined tree. No commits, pushes, PRs or merges have been requested.
- Keep this spec Approved until outstanding criteria are resolved and the owner authorizes its
  final PR commit. Nothing here marks spec 008 or roadmap step 8 complete.
