# AGENTS.md — Relente

Rules for AI coding agents (and people) working on Relente, a native macOS app that turns a macOS
installer into a bootable USB drive or SD card through a guided, visual flow. It erases disks
through a privileged helper, so safety and predictability come before everything else.

**This file is the project's source of truth for rules.** It overrides the defaults of the agent
skills in `.claude/skills/` wherever they differ. Features and their state live in
[`specs/`](specs); the roadmap is in the [README](README.md#project-status); folders are described
in [BUILDING.md](BUILDING.md#project-layout). Changes to this file go through a `docs:` pull request
approved by the project owner.

## How features are built (spec-driven development)

Every feature follows the gated workflow of the `spec-driven-development` skill:
**specify → plan → tasks → implement**, and the project owner reviews and approves each phase
before the next one starts. No feature code is written before the spec is approved.

These project conventions replace the skills' defaults:

- **One folder per feature:** `specs/NNN-short-name/`, numbered in order (`004-creating-screen`).
  It holds `spec.md`, then `plan.md` and `tasks.md`. Never create `SPEC.md` at the repo root or a
  `tasks/` folder. The spec template and the index of specs are in
  [`specs/README.md`](specs/README.md).
- **Project-wide areas are defined once, here:** tech stack, commands, project structure, code
  style, testing strategy and boundaries. A feature's `spec.md` only adds what is specific to it.
- **Status:** each `spec.md` starts with `Status: Draft | Approved | Done`. It becomes **Done in
  the last commit of its own pull request**, before merging, and the index is updated with it.
- **Open items:** work deferred to a later feature goes in the spec's "Open Items", naming where it
  will be done. Before specifying a feature, search earlier specs' Open Items for work deferred to
  it. Nothing deferred lives only in local notes.
- **Changing behavior:** update the spec first, then the code.
- **Requirements interviews** (`interview-me`) end up in the spec's Objective, not in
  `docs/intent/`. **Architecture decisions** (`documentation-and-adrs`) go in
  `docs/decisions/NNNN-short-title.md` when they outlive a single feature; otherwise in the spec's
  Decisions section.
- **One feature per working session:** spec → approval → plan → tasks → code → PR → merge.
- The spec, plan, tasks and code of a feature live in the same branch and pull request.

## Commands

```bash
# Build and test (xcode-select may point to the Command Line Tools)
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -scheme Relente -destination 'platform=macOS' -only-testing:RelenteTests
# Universal Release build, warnings as errors (as CI does)
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build -scheme Relente -configuration Release -destination 'generic/platform=macOS' CODE_SIGNING_ALLOWED=NO
# Format and lint
xcrun swift-format format -i -r Relente RelenteTests RelenteUITests
xcrun swift-format lint -r --strict Relente RelenteTests RelenteUITests
```

## Boundaries

**Always:**
- Follow the helper security rules below; each one is covered by tests.
- Build, run the tests and lint before saying something works.
- Keep `main` buildable; work on a branch.

**Ask first:**
- Before every commit, push, pull request or merge. Skills that say "commit after each task" or
  "commit early, commit often" don't apply here: the agent never commits, pushes, opens pull
  requests or merges unless the project owner asks for it in the conversation.
- Adding any third-party dependency to the app (development tools such as swift-format or agent
  skills are not app dependencies).
- Raising the minimum macOS version, or changing CI, signing or release settings.
- Changing this file.

**Never:**
- Commit secrets (certificates, passwords, notarization keys) or the local `CLAUDE.md`.
- Add a "run this command" function or a shell to the helper.
- Put the developer's real name in the repo (the copyright holder is **Afraidias**).
- Weaken a test or a rule to make a change pass.

## Helper security (non-negotiable)

The helper runs as root and can erase disks. These rules, described for users in
[SECURITY.md](SECURITY.md), hold in every change:

1. The helper exposes a minimal, typed API: format a drive, run `createinstallmedia`, report
   progress. No "run this command" function and no shell; `Process` with fixed executable paths
   and arguments passed as arrays.
2. Mutual code-signing validation over XPC: `NSXPCListener.setConnectionCodeSigningRequirement`
   in the helper (app identifier and Team ID) and `NSXPCConnection.setCodeSigningRequirement` in
   the app. Hardened Runtime and library validation are enabled.
3. The helper re-validates every request on its own: the identifier matches `^disk[0-9]+$` and is
   a whole disk that is external, removable, USB or SD, not the boot disk, and of a reasonable
   size. Right before erasing, it compares the disk fingerprint (media UUID, serial number, size)
   with the one the user confirmed, to prevent TOCTOU attacks.
4. Installers must be signed by Apple: `SecStaticCodeCheckValidity` with `anchor apple` on the
   installer app and on `createinstallmedia`, right before running it. Symbolic links are
   rejected; disk images are mounted read-only (`hdiutil attach -readonly -nobrowse`).
5. Every erase requires administrator authorization (Touch ID or password) through a custom
   Authorization Services right that the helper verifies.
6. No networking in the helper. Logging through `os_log`. The helper can be uninstalled from the
   app (`SMAppService.unregister()`).

The app cannot use App Sandbox (it erases disks through the helper); it ships signed with
Developer ID and notarized.

## Architecture

- **App (SwiftUI, unprivileged):** UI, disk detection (DiskArbitration), installer detection.
- **Helper (root daemon):** registered with `SMAppService.daemon(plistName:)`, plist in
  `Contents/Library/LaunchDaemons/`, talks to the app over `NSXPCConnection`. It only formats
  (`diskutil eraseDisk JHFS+ … GPT diskN`), runs `createinstallmedia --volume … --nointeraction`,
  and reports progress, read by running `createinstallmedia` attached to a pseudo-terminal
  (`openpty`) and parsing lines such as "Erasing disk: X%" and "Copying to disk: X%".
- **Shared module:** the XPC protocol.

Inside the app:

- **Views** present data only, take only the data they read, and each section is its own `View`
  type with a `#Preview`.
- **Models** are `nonisolated` value types that are `Sendable` and `Equatable`, with a stable,
  natural `id` (e.g. a file URL or media UUID). Shared state uses `@Observable`, never
  `ObservableObject`.
- **Services** are protocols with a live and a sample implementation; dependencies are injected
  through `init`, so logic is testable without SwiftUI. Tests and previews never touch real
  disks.
- Concurrency: `MainActor` by default; heavy work in `@concurrent` functions inside services. No
  `DispatchQueue`, no `Task.detached`.
- Errors: one error type per service, with a user-facing `LocalizedStringResource` message.
- Logging: `Logger(subsystem: "com.afraidias.Relente", category:)` with categories `disk`,
  `installer`, `helper`, `ui`.

## Code style

- Swift 6 language mode in all targets. Warnings are errors in Release; Debug stays
  warning-free.
- Swift API Design Guidelines naming. One type per file, named after the type. `// MARK:`
  sections and `///` doc comments for anything non-obvious. `private` by default; `@State` always
  `private`.
- `swift-format` with the repo's `.swift-format` (4 spaces, 120 columns). No SwiftLint.
- Everything in the repo is in English: names, comments, docs and commit messages.

## Testing strategy

- Swift Testing (`@Test`, `#expect`) for unit tests; XCTest only for UI tests.
- Tests are mandatory for model and service logic (sizes, disk fingerprint, drive filtering,
  `createinstallmedia` progress parsing) and for every helper security rule.
- A spec's acceptance criteria about logic become tests.
- One UI test walks the whole flow with sample data.

## Platforms

- Minimum deployment target: **macOS 14 Sonoma**, set at project level. Don't raise it or drop a
  supported version without the owner's approval; the support policy is in
  [docs/product.md](docs/product.md#supported-macs).
- Release builds are universal (arm64 + x86_64).
- APIs newer than macOS 14 need `if #available` with a fallback. Liquid Glass (macOS 26+) is only
  used through the app's `.buttonStyle(.primary)` / `.buttonStyle(.secondary)`
  (`Components/ButtonStyles.swift`), never `.glass` / `.glassProminent` directly. The
  `usesClassicControls` environment value (previews, and `-classicControls YES` in Debug) forces
  the macOS 14–15 look; screens also get a "Classic (macOS 14–15)" preview.

## Accessibility and localization

- Every screen works in light and dark mode, with VoiceOver and with Reduce Motion (animations
  fall back to a crossfade).
- UI text is written in English and translated to Spanish in `Resources/Localizable.xcstrings`.
  Types that carry user-facing text use `LocalizedStringResource`, not `String`; strings with
  interpolated values get a translator `comment:`.
- Destructive actions are never the default action: Return must never erase a drive.

## Product scope

macOS installers only, from Big Sur (11) onwards; destinations are USB drives and SD cards only
(external SSDs and hard drives hidden by default). The screen flow and the design system are in
[docs/product.md](docs/product.md); read it before specifying or building a screen.

## Workflow and quality gates

- **Branches:** GitHub Flow on a single long-lived `main` (no `develop`), which always builds. The
  "Protect main" ruleset forbids direct pushes, force pushes and deletion, and requires linear
  history, squash-only PRs (0 approvals) and the three CI checks. One short-lived branch per task:
  `feature/NNN-short-name` for a feature (same number and name as its `specs/` folder), `fix/…`,
  `chore/…`, `docs/…` otherwise.
- **Commits:** Conventional Commits. The squash commit uses the PR title and an empty body; the PR
  title is what release-please writes in the changelog (`feat:`/`fix:` are shown; `chore:`,
  `ci:`, `test:`, `refactor:`, `build:` are hidden).
- **Versions:** semver tags, managed by release-please. The version lives only in
  `Config/Version.xcconfig`. The build number (`CURRENT_PROJECT_VERSION`) stays at `1` until signed
  builds are distributed; automating it is part of roadmap step 8. Pre-1.0, `feat` bumps minor and
  `fix` bumps patch.
- **CI:** PR title, swift-format lint, and Build & test (Debug with unit tests, universal Release
  with warnings as errors, architecture check) must pass before merging.

**Definition of Done** for every pull request:

1. Builds with no errors or warnings.
2. All tests pass; new logic has tests.
3. `xcrun swift-format lint -r --strict Relente RelenteTests RelenteUITests` passes.
4. New views have a `#Preview`.
5. New strings are in the String Catalog with Spanish.
6. Works in light and dark mode, with VoiceOver and with Reduce Motion (or the spec's Open Items
   record where that check is deferred to).
7. Follows the helper security rules and `SECURITY.md`.
8. The spec (status Done), `specs/README.md`, README and BUILDING are updated if needed.
