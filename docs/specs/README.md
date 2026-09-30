# Specs

Relente follows a light form of **spec-driven development**: every feature starts as a short spec in this folder, the spec is reviewed and approved, and only then is it implemented.

## Rules

- One spec per feature, named `NNN-short-name.md` (e.g. `002-drive-screen.md`).
- The spec lives in the same branch and pull request as the code that implements it.
- Acceptance criteria are written so they can be checked; the ones about logic become tests.
- If the implementation needs to change the behavior, the spec is updated first.
- Status: **Draft** (under review) → **Approved** (ready to build) → **Done** (merged).

## Template

```markdown
# NNN · Feature name

**Status:** Draft · **Roadmap step:** N

## Goal
What this feature is for, in two or three sentences.

## Behavior
What the user sees and can do. Include each state.

## Acceptance criteria
- [ ] Checkable statement.

## Edge cases
What happens in unusual situations.

## Out of scope
What this spec deliberately doesn't cover, and where it will be covered.

## Open questions
Decisions still to make.
```

## Index

| Spec | Status |
| --- | --- |
| [001 · Installer screen](001-installer-screen.md) | Done |
| [002 · USB drive screen](002-drive-screen.md) | Done |
| [003 · Review screen](003-review-screen.md) | Approved |
