# 009 · App icon

**Status:** Done · **Roadmap step:** 8 (visual polish before the first release) · **Branch:** `feature/009-app-icon`

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
- [x] The compiled app displays the new icon in Finder, Dock and the Permissions hero. Check
      safely reachable dialogs without performing a disk erase; application-switcher inspection
      is deferred in Open items.
- [x] The drop and open letter remain distinguishable at 32, 64 and 128 px; at 16 px the drop
      silhouette and open counter remain recognizable rather than merging into a solid blob.
- [x] The icon is visually checked on light and dark backgrounds and in Default, Dark, Clear
      and Tinted appearances supported by the installed macOS/Icon Composer.
- [x] Inspect the compiled compatibility icon at available sizes on light and dark backgrounds;
      verify that the compiled asset catalog contains the multi-size icon. Record the actual OS
      used for the inspection and do not report an unavailable OS as runtime verified.
- [x] The Permissions hero and badge are visually checked with classic controls and the current
      macOS appearance, including checks with Reduce Motion and VoiceOver enabled. The decorative
      mark is hidden from accessibility and status information is accessible. Audible VoiceOver
      announcement verification is deferred in Open items.
- [x] `.github/assets/icon.png` is a 512 × 512 export of the final icon, and an inventory confirms
      no other active project presentation uses the old artwork.
- [x] `docs/product.md` and `BUILDING.md` describe the new icon accurately; update README content
      only where needed, keeping the existing image path and alt text.
- [x] Debug tests, universal Release build and strict swift-format lint pass using AGENTS.md's
      commands. No new logic or automated tests are required for this artwork-only change.
- [x] The spec and index become Done in the final commit of their own PR, before merging.

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
7. **Compatibility evidence approved, 2026-10-26.** Since macOS 14 and 15 are unavailable, the
   owner accepts inspection of the compiled compatibility icon and asset catalog for this feature.
   This visual evidence does not verify runtime behavior or change the app's supported versions;
   the unverified icon rendering remains an Open item for roadmap step 8.
8. **Manual checks deferred, 2026-10-26.** The owner accepts deferring audible VoiceOver
   announcement verification and visual inspection of the application-switcher icon to roadmap
   step 8. The app's accessibility calls and other icon consumers were checked as recorded below;
   neither deferred check is reported as passed.

## Open questions

None. Approved by the owner on 2026-10-26.

## Open items

- The owner has no macOS 14 or 15 installation available, so the icon's compiled fallback has not
  been visually verified on either OS. Release preparation (roadmap step 8) must account for this
  unverified icon rendering; the app's macOS 14 minimum deployment target is unchanged.
- Roadmap step 8: verify VoiceOver's audible ready and error announcements. The corresponding
  accessibility calls were checked while VoiceOver was enabled, but the speech was not observed.
- Roadmap step 8: visually inspect the new icon in the macOS application switcher. The icon was
  checked in Finder, the Dock, the Permissions hero and the uninstall confirmation sheet.
- This icon exploration is not a trademark clearance or a claim that no other product uses a
  similar mark.

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

### Integration verification · 2026-10-26

- Verified that main's merged spec 008 commit is an ancestor of PR #37's head. The diff against
  main contains only the icon, its presentation and spec 009 documentation; no earlier spec changed.
- On macOS 27.0.1 arm64 with Xcode 27.0, the combined tree passed the Debug unit suite with
  `CODE_SIGNING_ALLOWED=NO` (267 tests, 326 runs, no failures or skips), the unsigned universal
  Release build and strict swift-format lint. Both app and helper contain arm64 and x86_64.
- Re-exported the macOS 26 Default icon at 512 × 512 with the documented Icon Composer command.
  Compared with the repository PNG, nine pixels differed by at most three channel levels.
  This is an export comparison, not runtime verification on macOS 26 or earlier.
- Re-exported and inspected Default at 16, 32, 64 and 128 px and the Dark, Clear Light,
  Clear Dark, Tinted Light and Tinted Dark variants at 128 px against light and dark backgrounds.
  These are Icon Composer's macOS 26 renderings, not runtime checks on that OS.
- Attempted the existing sample-data Permissions UI test without signing. The test runner started
  but did not launch Relente, and the attempt was stopped. Retrying with ad hoc signing passed
  `AssistantFlowUITests.testPermissionsThenTheWholeFlow`, using sample services. This verifies the
  exercised flow; it does not replace the outstanding visual and accessibility checks.
- Inspected the Permissions hero in light appearance with `-classicControls YES` on macOS 27.0.1,
  before and after simulated helper installation. The icon, blue and green halos, and ready badge
  were visible. A temporary sample-data UI test captured both states; it touched no real helper or
  disk. The compiled app's 128 px `.icns` rendition was also inspected. Neither check establishes
  how the app behaves when actually run on macOS 14 or 15.
- For a closer compatibility review, inspected the Release bundle's generated `AppIcon.icns`
  renditions at 16, 32, 128 and 256 px against light and dark backgrounds. `assetutil -Z` also
  validated `Assets.car`, whose `AppIcon` multi-size entries cover 16–1024 points. The bundle names
  `AppIcon` in both icon plist keys and retains minimum macOS 14. Apple's
  [Icon Composer documentation](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer)
  says Xcode generates icon images at build time for earlier releases. This inspects compiled
  resources; it does not establish which resource an older macOS selects or test that OS at runtime.
- A temporary copy forced light and dark SwiftUI appearances and a simulated registration error.
  With VoiceOver and Reduce Motion enabled, sample-data UI checks passed for current and classic
  controls in both appearances, including not-installed and ready states and the cancel path of
  the uninstall confirmation. The error badge was inspected in dark classic appearance. XCTest
  found the status text; spoken VoiceOver announcements and the animation fallback were not
  independently observed. VoiceOver and Reduce Motion were restored to their original off states.
- Inspected the Dock icon while the sample-data Debug app was running on macOS 27.0.1; it shows
  the new droplet mark. This does not establish how it renders on earlier macOS versions.
- With Reduce Motion enabled, a temporary probe in a sample-data build confirmed that the
  Installer-to-Drive transition selected the crossfade branch even though the requested transition
  was a slide. This verifies the selected path, not a frame-by-frame recording of the animation.
- With VoiceOver enabled and its existing caption-panel setting on, captured the sample helper's
  ready state. The captures did not show the VoiceOver caption panel, so they do not verify the
  spoken announcement. Both XCTest screenshots and a direct desktop capture while holding
  Command-Tab failed to show the application-switcher overlay. Both checks remain outstanding.
  VoiceOver and Reduce Motion were restored to their original off states.
- In a subsequent sample-data build instrumented only in a temporary copy, XCTest confirmed that
  the ready and simulated-error paths called `AccessibilityNotification.Announcement.post()` with
  their expected localized messages while `NSWorkspace.isVoiceOverEnabled` was true. The probe
  observes the app's calls, not the speech or braille presented by VoiceOver. VoiceOver was on
  when this check began and was left on.

### Final review

- The owner accepted the deferred checks recorded in Open items. The Reduce Motion crossfade path
  was exercised with a temporary probe, but animation frames were not recorded.
- Runtime icon rendering on macOS 14, 15 and 26 remains unverified; the current host is macOS
  27.0.1, the owner has no macOS 14 or 15 installation, and the macOS 26 evidence above is Icon
  Composer rendering only.
- The owner authorized the final PR commit. This feature is Done; its Open items do not mark
  roadmap step 8 complete.
