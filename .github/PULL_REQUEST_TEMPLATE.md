## What

<!-- What does this change do, and why? The PR title becomes the commit message: use Conventional Commits (e.g. "feat(installer): add installer picker"). -->

## Definition of Done

<!-- Mirrors the Definition of Done in AGENTS.md; keep them in sync. Mark items that don't apply as such. -->

- [ ] Builds with no errors or warnings (Swift 6 strict concurrency).
- [ ] All tests pass, and new logic has tests.
- [ ] `xcrun swift-format lint -r --strict Relente RelenteTests RelenteUITests` passes.
- [ ] New views have a `#Preview`.
- [ ] New UI strings are in the String Catalog, with Spanish translations.
- [ ] Checked in light and dark mode, with VoiceOver and with Reduce Motion (or the spec's Open items record where that check is deferred to).
- [ ] Follows Apple's Human Interface Guidelines for macOS, or the spec's Decisions record the exception and why.
- [ ] Follows the helper security rules in [AGENTS.md](../AGENTS.md) and doesn't weaken any rule in [SECURITY.md](../SECURITY.md).
- [ ] The spec (status Done), `specs/README.md`, `docs/product.md`, README and BUILDING are updated if needed.
