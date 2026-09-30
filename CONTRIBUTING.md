# Contributing

Thanks for your interest in Relente!

## Pull requests

This is a personal project in early development, and **pull requests from outside contributors aren't accepted for now**. Pull requests opened from forks will be closed. This may change once the project is stable.

## Issues

Bug reports and ideas are welcome. Before opening an issue, please search the existing ones.

- **Bugs:** use the *Bug report* template. Include your macOS version, the installer you used (name and version) and the kind of drive (USB drive or SD card, and its size).
- **Ideas:** use the *Feature request* template. Keep in mind the project's scope: macOS installers only (Big Sur and later), and USB drives and SD cards only as destinations.
- **Security issues:** don't open a public issue. Follow [SECURITY.md](SECURITY.md).

## Conventions

These are the rules the project follows, for reference. The full set lives in [AGENTS.md](AGENTS.md).

- **Specs:** spec-driven development. Every feature starts as a spec in [`specs/`](specs) (`spec.md`, then `plan.md` and `tasks.md`), is approved, and only then implemented.
- **Branches:** GitHub Flow. `main` always builds; every change lands through a pull request from a short-lived branch (`feature/…`, `fix/…`, `chore/…`, `docs/…`) with *squash merge*.
- **Commits:** [Conventional Commits](https://www.conventionalcommits.org/), in English. For example: `feat(installer): add installer picker`.
- **Code:** Swift 6 with strict concurrency, SwiftUI, and everything in English (names, comments, docs). UI strings are localized through the String Catalog.
- **Architecture:** views only present data; models are value types; every service sits behind a protocol with a live and a sample implementation, so previews and tests never touch real disks. No third-party dependencies.
- **Formatting:** [swift-format](https://github.com/swiftlang/swift-format), bundled with Xcode, using the repository's `.swift-format` (4 spaces, 120 columns). `xcrun swift-format lint -r --strict Relente RelenteTests RelenteUITests` must pass.
- **Warnings:** none allowed. Release builds treat warnings as errors.
- **Tests:** [Swift Testing](https://developer.apple.com/documentation/testing) for unit tests, XCTest only for UI tests. Logic and every security check must have tests.
- **Versions:** semantic versioning (`v0.1.0`), managed by [release-please](https://github.com/googleapis/release-please) from the Conventional Commits. See [BUILDING.md](BUILDING.md#versions).
- **CI:** every pull request runs the [CI workflow](.github/workflows/ci.yml): PR title (Conventional Commits), swift-format lint, Debug build with unit tests, and a universal Release build. All checks must pass before merging.
- **Git hooks:** run `git config core.hooksPath .githooks` once, so formatting and commit messages are checked before each commit.

## Code of conduct

Everyone taking part in this project is expected to follow the [Code of Conduct](CODE_OF_CONDUCT.md).
