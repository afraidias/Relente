# Building Relente

## Requirements

- Xcode 27, which runs on macOS 26.6 or later.

The app itself runs on **macOS 14 Sonoma and later**, on Apple silicon and Intel Macs (Release builds are universal).

## Build and run in Xcode

1. Clone the repository:

   ```bash
   git clone https://github.com/afraidias/Relente.git
   ```

2. Open `Relente.xcodeproj`.
3. In **Signing & Capabilities**, choose your own team for the `Relente` target.
4. Press **⌘R**.

The app is not sandboxed (it needs a privileged helper to erase disks), so it can't be distributed through the Mac App Store.

## Checking older macOS versions

On macOS 26 and later the app uses Liquid Glass; on macOS 14 and 15 it falls back to the classic control styles. To see the classic look on a newer Mac:

- In Xcode's canvas, pick the **Classic (macOS 14–15)** preview.
- Or run a Debug build with the `-classicControls YES` launch argument (**Product → Scheme → Edit Scheme… → Run → Arguments**).

For real testing, use a macOS 14 or 15 virtual machine, and Rosetta or an Intel Mac for the Intel build.

## Simulated creation (Debug builds)

Until `createinstallmedia` is wired up (roadmap step 7), Debug builds simulate creating the installer so the whole assistant can be walked: nothing is erased, and Creating, Error and Done show a "SIMULATION · Nothing is erased" label. Release builds have no simulation and keep "Erase and Create" disabled. Two Debug-only launch arguments (**Product → Scheme → Edit Scheme… → Run → Arguments**):

- `-simulationSpeed fast`: the simulation lasts about 2 seconds instead of 15 (the UI tests use it).
- `-simulateFailure driveDisconnected`: the simulation fails partway through Copy, to see the Error screen.

## Git hooks

The repository has two git hooks in `.githooks/`: one checks formatting with swift-format before each commit, and the other checks that the commit message follows [Conventional Commits](https://www.conventionalcommits.org/). Turn them on once after cloning:

```bash
git config core.hooksPath .githooks
```

To format all the code:

```bash
xcrun swift-format format -i -r Relente RelenteTests RelenteUITests
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

Run the tests:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme Relente test
```

## Project layout

| Folder | Contents |
| --- | --- |
| `Relente/App` | App entry point, the assistant's shared state (`Assistant`) and its menu commands. |
| `Relente/Views` | Assistant screens. |
| `Relente/Components` | Reusable views and the design system (`Theme.swift`). |
| `Relente/Models` | Data types (installers, drives…). |
| `Relente/Services` | Disk and installer detection, helper connection. |
| `Relente/Resources` | App icon (`AppIcon.icon`, made with Icon Composer), asset catalog and String Catalog. |
| `specs` | One folder per feature (`NNN-short-name/`) with its `spec.md`, and `plan.md` and `tasks.md` from feature 004 on. See [`specs/README.md`](specs/README.md). |
| `docs` | Product and design overview ([`docs/product.md`](docs/product.md)): scope, supported Macs, screen flow and design system. |

## App icon

The icon is `Relente/Resources/AppIcon.icon`, made with Icon Composer; Xcode compiles it directly (there is no `AppIcon.appiconset`). Open it in Icon Composer to edit it. It's always dark: the Default appearance uses the *System Dark* fill, so only the Clear and Tinted appearances chosen in System Settings change it. The 512 px PNG in `.github/assets/icon.png`, used by the README, is an export of it; regenerate it when the icon changes.

## Localization

UI strings are written in English and translated in `Relente/Resources/Localizable.xcstrings`. Currently supported: English and Spanish. Xcode adds new strings to the catalog when you build.

## Agent skills (optional)

The repository includes skills for AI coding agents in `.claude/skills/`, each with its own `LICENSE` (MIT). The project's rules for agents are in [AGENTS.md](AGENTS.md).

- [`write-swift`](.claude/skills/write-swift), by Emil Kowalski.
- Twelve skills from [Addy Osmani's agent-skills](https://github.com/addyosmani/agent-skills), copied as plain Markdown (no scripts): `spec-driven-development`, `planning-and-task-breakdown`, `incremental-implementation`, `interview-me`, `test-driven-development`, `code-review-and-quality`, `debugging-and-error-recovery`, `source-driven-development`, `api-and-interface-design`, `security-and-hardening`, `doubt-driven-development` and `documentation-and-adrs`. Where they differ from AGENTS.md (for example, committing after every task, or saving specs as `SPEC.md`), AGENTS.md wins.

Apple's skills that ship with Xcode 27 are not included (they can't be redistributed). To add them locally:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun agent skills export .claude/skills
```
