# Implementation Plan: 009 · App icon

**Status:** Approved by the owner on 2026-10-26.

## Overview

Replace the existing arrow-and-slot artwork with the selected B dew/drop and lowercase letter.
Keep the existing Icon Composer integration, derive the README image from the final icon, and
verify the compiled bundle and Permissions hero. This plan implements the approved spec without
changing app behavior. Detailed tasks are in `tasks.md` and await owner approval.

## Architecture Decisions

1. **One outlined foreground.** Extract the ivory path from `design-reference.svg` into
   `Relente/Resources/AppIcon.icon/Assets/RelenteMark.svg`. Preserve the open-bottom letter as
   actual transparency, rather than painting a blue letter on an ivory drop. Do not import the
   reference's rounded background tile.
2. **Composer owns presentation.** Use a full-bleed sRGB ink-blue fill in `icon.json`, with the
   SVG foreground interpreted in sRGB. Use meaningful English layer/group names. Inspect the
   installed Icon Composer format and tools before choosing fill/effect serialization; validate
   by opening the asset and compiling it. Keep effects restrained, with no baked shadows or
   bevels in the SVG. Remove the five obsolete SVGs after their replacement is validated.
3. **Existing consumers stay shared.** Keep `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` and
   `PermissionsHero` reading `NSApplication.shared.applicationIconImage`. No new image-loading
   code, dependencies, views, localization or runtime settings are expected.
4. **Export rather than redraw.** Export `.github/assets/icon.png` at 512 × 512 from the finished
   Composer asset using the installed supported export tools. A hand-rendered mockup is not a
   substitute. Record the actual repeatable export procedure in BUILDING.
5. **Independent checkout.** Work only in `feature/009-app-icon`. The checkout is based on the
   committed helper branch snapshot; the original checkout's uncommitted helper edits are not
   copied or modified. Refresh the branch's base against the final helper/main state before PR
   integration if those changes land in the meantime; any commit/push/PR/merge needs owner request.

## Dependency order

Approved reference → outlined foreground + Composer background → compiled bundle and visual
review → README export → documentation and final quality gates.

## Task List

### Phase 1: Production icon

1. Inspect Icon Composer's available editing, preview and export capabilities; prepare the
   outlined foreground and configure the existing `.icon` asset with the approved palette.
2. Compile and review the icon at 16, 32, 64, 128 px and normal Dock size. Refine only optical
   details within the approved design; remove obsolete layers and source artwork.

### Checkpoint: Icon fidelity

- The compiled icon has the selected B letter, open counter, correct default colors and no old
  artwork. The owner can review a render against the approved reference before presentation export.
- Check supported Default, Dark, Clear and Tinted previews. Record actual available appearances.

### Phase 2: App and repository presentation

3. Inspect a newly built bundle in Finder and Dock. Check Permissions in
   current and classic-control appearances, light/dark backgrounds, Reduce Motion and VoiceOver.
   Use sample data; do not authorize an erase or install/uninstall the helper for icon checks.
   If a system dialog can be safely displayed without those actions, check its icon too.
   The owner deferred application-switcher inspection and audible VoiceOver announcement checks
   to roadmap step 8; retain them in the spec's Open items rather than marking them as verified.
4. Export the 512 px README image from the final Composer asset. Update `docs/product.md` and
   `BUILDING.md`, and verify README's existing image path and accessible description still work.

### Checkpoint: Consistency

- Bundle icon, Permissions hero and README represent the same final design.
- Inventory tracked images and references for any remaining active use of the old artwork;
  preserve historical specifications. Inspect previews rather than assuming caches have updated.
- Inspect the compiled compatibility icon and multi-size asset catalog. Record the OS actually
  used; classic-control previews and compiled resources do not prove runtime behavior on 14–15.

### Phase 3: Quality gates and review

5. Run the required commands from AGENTS.md:

   ```bash
   DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -scheme Relente -destination 'platform=macOS' -only-testing:RelenteTests
   DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build -scheme Relente -configuration Release -destination 'generic/platform=macOS' CODE_SIGNING_ALLOWED=NO
   xcrun swift-format lint -r --strict Relente RelenteHelper Shared RelenteTests RelenteUITests
   ```

   Confirm the Release binary contains arm64 and x86_64 with `lipo -archs` on its built executable.
   Use a task-specific DerivedData location if needed to avoid inspecting another build's outputs.
   No new tests that merely duplicate artwork are planned.
6. Review the diff and acceptance criteria, record evidence and unavailable manual checks, and
   present the final icon and outstanding verification to the owner. Keep the spec Approved
   until all required work is satisfied and the owner authorizes the final commit of its PR.
   Then mark the spec and index Done in that commit, before merging.

### Checkpoint: Complete

- Required build/test/lint checks pass with no warnings; architecture check passes.
- Every visual criterion has evidence or remains explicitly outstanding. An unavailable OS or
  accessibility check must not be silently treated as completed or moved outside approved scope.
- The diff contains only this feature's resources and documentation. No helper or project
  signing/release/CI settings changed. Owner authorization remains required for Git publication.

## Risks and Mitigations

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Composer effects obscure the letter cutout | Medium | Use transparent negative space, restrained effects and small-size appearance previews. |
| Color-space mismatch shifts the approved blue | Medium | Use explicit sRGB interpretation and compare the actual rendered Default icon. |
| Cached icon masks the resource update | Medium | Inspect the new built bundle first, then relaunch normally; do not change bundle identity. |
| Installed Composer tool/export syntax differs | Medium | Inspect supported local capabilities and validate the asset through Composer and Xcode. |
| Legacy OS runtime is unavailable | Medium | Inspect generated compatibility resources, record unverified OS versions and carry the icon-rendering risk to roadmap step 8. |
| Parallel helper work changes shared docs | Medium | Keep checkout isolated; reconcile against the final integration base without overwriting that work. |

## Rules check

- Matches the approved spec and repository layout. No implementation starts before plan and
  task-list approval. No earlier Done spec is edited.
- The helper API, authentication, disk validation and every security rule stay unchanged.
- macOS 14 minimum, universal Release, Swift architecture, signing and CI stay unchanged.
- Uses existing native vector assets and Icon Composer; adds no app dependencies.
- Applies the spec's recorded Apple HIG review: outlined foreground, unmasked full-bleed
  background, system effects, centered simple mark and consistent appearance variants.
- No new UI text, motion or controls. Existing accessibility behavior is checked in context.
- The only files written during this phase are this plan, spec approval and the spec index.

## Open Questions

None blocking plan approval. Installed export capabilities and available runtime OS versions are
verification work in Phase 1 and Phase 2, not assumptions that those checks have already passed.

## Coordination with spec 008

The owner is continuing spec 008 in another chat. Implement and verify this icon independently
in this checkout; final integration waits for 008 to reach main. Reconcile shared documentation
against its final state and rerun checks before publishing 009. Do not modify the other checkout.

## Approved Liquid Glass preview

The owner approved the real Icon Composer macOS 26 preview on 2026-10-26. The temporary preview
uses a solid `extended-srgb:0.14118,0.21176,0.30196,1.00000` fill, a glass foreground, a neutral
shadow at 0.3 opacity and translucency at 0.15. Preserve this direction and verify production
exports independently. The installed `ictool` supports `--export-image --platform macOS
--rendition Default --width 512 --height 512 --scale 1 --design-generation 26`.
