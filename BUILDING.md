# Building Relente

## Requirements

- macOS 27 or later (to build; the app runs on macOS 26 and later).
- Xcode 27.

## Build and run in Xcode

1. Clone the repository:

   ```bash
   git clone https://github.com/afraidias/Relente.git
   ```

2. Open `Relente.xcodeproj`.
3. In **Signing & Capabilities**, choose your own team for the `Relente` target.
4. Press **⌘R**.

The app is not sandboxed (it needs a privileged helper to erase disks), so it can't be distributed through the Mac App Store.

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
| `Relente/App` | App entry point. |
| `Relente/Views` | Assistant screens. |
| `Relente/Components` | Reusable views and the design system (`Theme.swift`). |
| `Relente/Models` | Data types (installers, drives…). |
| `Relente/Services` | Disk and installer detection, helper connection. |
| `Relente/Resources` | App icon (`AppIcon.icon`, made with Icon Composer), asset catalog and String Catalog. |

## Localization

UI strings are written in English and translated in `Relente/Resources/Localizable.xcstrings`. Currently supported: English and Spanish. Xcode adds new strings to the catalog when you build.

## Agent skills (optional)

The repository includes the [`write-swift`](.claude/skills/write-swift) skill for AI coding agents. Apple's skills that ship with Xcode 27 are not included (they can't be redistributed). To add them locally:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun agent skills export .claude/skills
```
