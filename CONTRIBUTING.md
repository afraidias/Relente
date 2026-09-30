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

These are the rules the project follows, for reference:

- **Branches:** GitHub Flow. `main` always builds; every change lands through a pull request from a short-lived branch (`feature/…`, `fix/…`, `chore/…`, `docs/…`) with *squash merge*.
- **Commits:** [Conventional Commits](https://www.conventionalcommits.org/), in English. For example: `feat(installer): add installer picker`.
- **Code:** Swift 6 with strict concurrency, SwiftUI, and everything in English (names, comments, docs). UI strings are localized through the String Catalog.
- **Versions:** semantic versioning tags (`v0.1.0`).

## Code of conduct

Everyone taking part in this project is expected to follow the [Code of Conduct](CODE_OF_CONDUCT.md).
