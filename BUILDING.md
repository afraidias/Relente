# Building Relente

## Requirements

- Xcode 27, which runs on macOS 26.6 or later.

The supported target is **macOS 26.0 and later on Apple silicon**; see the
[product support policy](docs/product.md#supported-macs). The app and helper build for arm64 with
macOS 26.0 as their minimum deployment target. CI verifies these Release properties.

## Build and run in Xcode

1. Clone the repository:

   ```bash
   git clone https://github.com/afraidias/Relente.git
   ```

2. Open `Relente.xcodeproj`.
3. In **Signing & Capabilities**, choose your own team for the `Relente` target.
4. Press **⌘R**.

The app is not sandboxed (it needs a privileged helper to erase disks), so it can't be distributed through the Mac App Store.

### Testing the live helper

For a real helper run, build the app with your development team selected for both `Relente` and `RelenteHelper`. Launch the app and choose **Install Helper**. When macOS asks for approval, open **System Settings → General → Login Items & Extensions**, enable Relente under **Allow in the Background**, then return to the app and wait for **System helper ready** before continuing. Choose an installer first; the app shows which connected USB drives have enough space. For an `InstallAssistant.pkg`, the helper verifies and expands a root-owned private copy without installing it or running its scripts. The live helper runs Apple's `createinstallmedia`, which erases the selected USB drive. Use only a drive you have chosen to erase.

On the macOS 27 test Mac, live creation requires Relente under **System Settings → Privacy &
Security → Full Disk Access** and the helper under **General → Login Items & Extensions → Allow in
the Background**. Installer and drive selection remain available without Full Disk Access. Before
erasing, the helper runs a harmless write check against the selected USB; if it fails, Review stays
open and directs the user to these settings.

If helper registration or connection fails, diagnose the existing signed Xcode build and its
registration state. Do not copy the app to `/Applications`, create a temporary project variant,
re-sign it or disable signing as a routine workaround. Any necessary experiment must have a
specific purpose and stay within the owner's approved scope. To walk the Permissions screen
without registering a real helper, use `-sampleData YES -sampleHelper notInstalled` as described below.

## Platform verification

Validate the app on supported macOS versions starting at 26.0, on Apple silicon. A successful run
on a newer system does not establish behavior on the minimum supported version.

The existing code still includes classic macOS 14–15 control fallbacks, Classic previews and the
Debug `-classicControls YES` launch argument. These are implementation remnants pending review,
not a requirement to support or validate older macOS versions or Intel hosts. A classic-control preview
is not a substitute for a runtime check on a supported macOS version.

## Simulated creation (Debug builds)

In Debug builds, `-sampleData YES` keeps the whole flow safe to walk: its helper is a sample client, and no drive is erased. Creating, Error and Done show a "SIMULATION · Nothing is erased" label. Normal Debug and Release builds use the live helper for creation. Two Debug-only launch arguments (**Product → Scheme → Edit Scheme… → Run → Arguments**):

- `-simulationSpeed fast`: the simulation lasts about 2 seconds instead of 15 (the UI tests use it).
- `-simulateFailure driveDisconnected`: the simulation fails partway through Copy, to see the Error screen.

## Sample data (Debug builds)

The app shows the installers in `/Applications` and the USB drives and SD cards plugged in. To walk the assistant without them, run a Debug build with these launch arguments:

- `-sampleData YES`: sample installers and drives instead of the Mac's (the UI tests use it), with every state: an unsupported installer (Catalina), and drives with data, empty and too small. Ejecting does nothing.
- `-sampleEmpty installers` or `-sampleEmpty drives`, together with `-sampleData YES`: starts with that list empty, to see its empty state.
- `-sampleHelper notInstalled`, together with `-sampleData YES`: starts on Permissions with a simulated missing helper. Install Helper moves through approval to Ready automatically; it does not register a real system helper.

Unit tests and previews always use the sample data and never read the Mac's disks or `/Applications`.

## Git hooks

The repository has two git hooks in `.githooks/`: one checks formatting with swift-format before each commit, and the other checks that the commit message follows [Conventional Commits](https://www.conventionalcommits.org/). Turn them on once after cloning:

```bash
git config core.hooksPath .githooks
```

To format all the code:

```bash
xcrun swift-format format -i -r Relente RelenteHelper Shared RelenteTests RelenteUITests
```

## Versions

The app version lives in `Config/Version.xcconfig` (`MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`), shared by every target. Don't set it in Xcode's target settings.

Releases are managed by [release-please](https://github.com/googleapis/release-please): on every push to `main` it opens or updates a release pull request with the next version (based on the Conventional Commits since the last release) and the `CHANGELOG.md`. Merging that pull request creates the `vX.Y.Z` tag and the GitHub release.

release-please only updates `MARKETING_VERSION`. The build number (`CURRENT_PROJECT_VERSION`) stays at `1` and isn't bumped by hand; it will be automated before the first signed build is distributed (roadmap step 8).

## Build from the command line

If `xcode-select` points to the Command Line Tools instead of Xcode, set `DEVELOPER_DIR`:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme Relente -configuration Debug build
```

For local tests, prefer the existing project in Xcode: select the **Relente** scheme and
**My Mac**, then choose **Product → Test** (⌘U). Use the Test navigator for focused tests.
Keep the project's automatic signing for the app, helper and test targets; diagnose failures
without changing their identities or bypassing signing. UI tests continue to use sample services.

The equivalent command-line unit-test invocation preserves those project settings:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -scheme Relente -configuration Debug -destination 'platform=macOS' -only-testing:RelenteTests
```

Unsigned CI builds check compilation and test logic; they do not establish that development or
release signatures, privileged-helper registration or genuine XPC connections work.

## Project layout

| Folder | Contents |
| --- | --- |
| `Relente/App` | App entry point, the assistant's shared state (`Assistant`) and its menu commands. |
| `Relente/Views` | Assistant screens. |
| `Relente/Components` | Reusable views and the design system (`Theme.swift`). |
| `Relente/Models` | Data types (installers, drives…). |
| `Relente/Services` | Disk and installer detection, helper connection. |
| `Relente/Resources` | App icon (`AppIcon.icon`, made with Icon Composer), asset catalog and String Catalog. |
| `RelenteHelper` | The system helper: a command-line tool that runs as root, embedded in the app (`Contents/MacOS/RelenteHelper`) and registered with `SMAppService`. |
| `Shared` | Code compiled into both the app and the helper: the XPC protocol and the security checks. |
| `Config` | Build settings (`Version.xcconfig`) and the helper's launchd plist, copied to `Contents/Library/LaunchDaemons/`. |
| `intent` | Intent, requirements/design and implementation plans for each change. See [`docs/development.md`](docs/development.md). |
| `docs` | Product and design overview ([`docs/product.md`](docs/product.md)): scope, supported Macs, screen flow and design system. |

## App icon

The icon is `Relente/Resources/AppIcon.icon`, made with Icon Composer; Xcode compiles it directly
(there is no `AppIcon.appiconset`). `Assets/RelenteMark.svg` contains the outlined ivory dew/drop
and lowercase “r” as one shape with an open, transparent counter. The solid ink-blue background
is configured separately in `icon.json`; the system supplies masking and Liquid Glass effects.
The default palette is sRGB ink blue `#24364D` and ivory `#F4F1E9`. Clear and Tinted appearances
can change the colors while preserving the mark. Explicit Dark fills preserve the default
blue/ivory contrast instead of relying on automatic recoloring. The Permissions hero and app alert sheets read the app's bundle icon.

Open the `.icon` document in Icon Composer to preview appearance variants and adjust effects.
Do not bake a rounded tile, highlights or shadows into the foreground SVG. The README uses
`.github/assets/icon.png`, exported from this same asset at 512 px. To regenerate the macOS 26
Default export with the installed Xcode's Icon Composer:

```bash
"/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool" \
  Relente/Resources/AppIcon.icon --export-image --output-file .github/assets/icon.png \
  --platform macOS --rendition Default --width 512 --height 512 --scale 1 --design-generation 26
```

Check the exported PNG and the compiled bundle icon after changing the artwork. Verify actual
icon rendering on supported macOS versions; Icon Composer and SwiftUI previews alone do not
establish runtime appearance.

## Localization

UI strings are written in English and translated in `Relente/Resources/Localizable.xcstrings`. Currently supported: English and Spanish. Xcode adds new strings to the catalog when you build.

## Agent skills (optional)

Pinned upstream revision, licenses and local adaptations are recorded in [`.claude/UPSTREAM.md`](.claude/UPSTREAM.md).

The repository includes third-party skills for AI coding agents in `.claude/skills/`. Addy’s MIT license is retained in [`.claude/ADDY-LICENSE`](.claude/ADDY-LICENSE); `write-swift` retains its own license. The project’s rules for agents are in [AGENTS.md](AGENTS.md).

- [`write-swift`](.claude/skills/write-swift), by Emil Kowalski.
- Nineteen skills from [Addy Osmani's agent-skills](https://github.com/addyosmani/agent-skills), copied without modification from the pinned upstream revision: `planning-and-task-breakdown`, `incremental-implementation`, `interview-me`, `test-driven-development`, `code-review-and-quality`, `debugging-and-error-recovery`, `source-driven-development`, `api-and-interface-design`, `security-and-hardening`, `doubt-driven-development`, `documentation-and-adrs`, `context-engineering`, `deprecation-and-migration`, `observability-and-instrumentation`, `shipping-and-launch`, `ci-cd-and-automation`, `git-workflow-and-versioning`, `constraint-driven-development` and `idea-refine`. The selected skills and shared references are unmodified upstream copies. Relente-specific decisions remain in AGENTS.md and project documentation; flag conflicts instead of adapting third-party files. AGENTS.md takes precedence over skill defaults.

Codex discovers the same project skills through `.agents/skills/` symlinks; Claude Code uses `.claude/skills/`. Both read AGENTS.md (Claude through the versioned CLAUDE.md import). No global skill installation is needed. Personal instructions belong in ignored CLAUDE.local.md.

### Selected Apple skill (local)

`swiftui-specialist`, exported from Xcode, complements `write-swift` with SwiftUI guidance.
Its Apple content and the local discovery symlink are ignored by Git; they are not part of the
MIT-licensed vendored skills above. No redistribution license was identified in the export.
To recreate this local setup, run Xcode and export to a temporary directory, then copy only the
selected skill (do not overwrite an existing installation without reviewing the update):

```bash
relente_apple_export=$(mktemp -d /tmp/relente-apple-skills.XXXXXX)
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun agent skills export "$relente_apple_export"
cp -R "$relente_apple_export/swiftui-specialist" .claude/skills/swiftui-specialist
ln -s ../../.claude/skills/swiftui-specialist .agents/skills/swiftui-specialist
```

Claude Code and Codex access the same local content. New sessions may be needed for skill
discovery; verify loading in each agent, or read its SKILL.md directly if discovery is unavailable.
The export includes SDK 27 references: check API availability against Relente's macOS 26.0 minimum
and the installed SDK before applying recommendations. Skills do not override AGENTS.md or
approve broad refactors. `audit-xcode-security-settings` is also selected for local installation. It audits compiler
warnings, static analysis and Enhanced Security settings; it does not audit signing, notarization,
privacy or network security. To recreate it, use the same export directory and copy/link pattern:

```bash
cp -R "$relente_apple_export/audit-xcode-security-settings" .claude/skills/audit-xcode-security-settings
ln -s ../../.claude/skills/audit-xcode-security-settings .agents/skills/audit-xcode-security-settings
```

Installing the skill does not authorize an audit execution or configuration changes. Its workflow
expects Xcode integration tools: inspect available tools before use and report missing capabilities
rather than inventing tool calls or claiming a completed audit. Any proposed hardening must fit the
accepted design, helper requirements and supported platforms, with appropriate verification.
Other Apple skills are not installed by this setup.
