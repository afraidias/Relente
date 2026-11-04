# AGENTS.md — Relente

Rules for AI coding agents (and people) working on Relente, a native macOS app for downloading a
macOS installer from Apple or selecting a local installer, then creating a bootable USB drive or
SD card through a guided, visual flow. It erases disks through a privileged helper, so safety and
predictability come before everything else.

**This file records Relente's project-specific decisions and constraints.** Skills complement
these rules with specialized knowledge and procedures. If a skill conflicts with this file,
this file takes precedence; the agent must flag the conflict and propose a review when appropriate.
Change artifacts live in
[`intent/`](intent/); release follow-up is in [release readiness](docs/release-readiness.md); folders are described
in [BUILDING.md](BUILDING.md#project-layout). The owner may authorize edits to this file in the
conversation. Changes remain reviewable through a `docs:` pull request approved by the owner;
commits, pushes and PR creation follow the approved work scope; merging requires owner review and approval.

## AI-native software development lifecycle

Follow Plan, Design, Build, Test, Deploy and Maintain. Before starting or resuming a change, read
[the lifecycle guide](docs/development.md) and the relevant [change artifacts](intent/README.md).

The owner accepts intent, requirements/design and the implementation plan before implementation.
These reviews may happen in one conversation; keep documents proportionate to the change.
Record explicit acceptance, date and revision. Silence is not approval. Re-review changed scope,
behavior or risk. Within approved work, commits, pushes and PR creation need no separate approval;
merging requires owner review and approval. Release publication remains separately authorized.
Never invent approvals, issue references or verification results.
Within an accepted goal, execute, verify and correct routine work without repeated confirmation.
Keep change artifacts current for session continuity; stop for completion, material new decisions,
missing required access/evidence or agreed execution limits. Follow the
[goal-based execution guide](docs/development.md#goal-based-execution-and-session-continuity).

## Commands

Run local tests from the existing Xcode project and Relente scheme (Product → Test), using the
configured automatic signing. Diagnose signing failures; do not bypass them with copied apps,
temporary project variants or signing overrides. The CLI equivalent uses the same project settings:

```bash
# Debug unit tests with project signing (xcode-select may point to the Command Line Tools)
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -scheme Relente -configuration Debug -destination 'platform=macOS' -only-testing:RelenteTests
# Compile-only arm64 Release check, as in CI; does not validate signing or live helper access
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build -scheme Relente -configuration Release -destination 'generic/platform=macOS' CODE_SIGNING_ALLOWED=NO
# Lint changed Swift files during iteration; full scope below before integrating code
xcrun swift-format lint -r --strict Relente RelenteHelper Shared RelenteTests RelenteUITests
```

## Boundaries

**Always:**
- Preserve the helper's security checks before erasing or preparing a device. Never bypass or
  weaken them to resolve a failure; the detailed requirements are in Helper security below.
- Select verification by change and risk: use focused checks during implementation and complete
  required project checks before integrating code. For documentation-only changes, verify content,
  links and consistency. Record actual checks and limitations; required CI gates still apply.
- Keep `main` buildable; work on a branch.
- Ground macOS design and implementation decisions in relevant official Apple documentation and
  Human Interface Guidelines, checking supported-platform compatibility. Use relevant skills and
  Xcode tools proactively to verify quality according to the change and its risks; record evidence
  and limitations. See the [development guide](docs/development.md#apple-guidance-and-xcode-tools).
  Document deliberate interface-guideline exceptions and their reasons in the change design.

**Ask first:**
- Before merging a pull request: obtain the owner's review and approval. Within approved work,
  the agent may commit, push to the work branch and open a PR without asking at each step;
  narrower instructions from the owner still apply. Passing CI alone does not authorize merge.
- Adding any third-party dependency to the app (development tools such as swift-format or agent
  skills are not app dependencies).
- Changes that drop a supported macOS version or architecture must explain their impact and be
  accepted in the design. If discovered during implementation, revisit that decision before
  proceeding. Do not request the same approval again when the accepted design already covers it.
- Publishing a release to users.

**Never:**
- Include secrets (passwords, private keys, signing or notarization credentials) or personal
  configuration in repository changes.
- Weaken tests or controls to hide a failure or claim success. Tests may be updated to reflect
  an approved behavior change; preserve coverage of supported behavior and security requirements.

## Helper security (non-negotiable)

The helper runs as root and can erase disks. These rules, described for users in
[SECURITY.md](SECURITY.md), hold in every change:

1. The helper must only accept explicitly allowed operations, never arbitrary command execution.
2. The app and helper must mutually verify each other's identity.
3. The helper must independently validate that the destination is an allowed drive, never a
   boot disk, and verify immediately before erasing that it is still the drive the user confirmed.
4. Verify the authenticity of Apple software before executing it with elevated privileges.
5. Every erase requires administrator authorization, which the helper must verify.
6. No networking in the helper. The helper must be uninstallable from the app.

## Repository language

- Everything in the repo is in English: names, comments, docs and commit messages.

## Testing strategy

- Cover behavior changes and affected security guarantees with tests.

## Platforms

Respect the [supported-platform policy](docs/product.md#supported-macs).

## Accessibility and localization

- The interface must work in light and dark mode, be accessible with VoiceOver, and respect Reduce Motion.
- User interface text must be available in English and Spanish.

## Completion criteria

Before requesting integration, verify the acceptance criteria, complete applicable checks, and
update affected documentation. Record results, limitations and any owner-accepted deferrals.
