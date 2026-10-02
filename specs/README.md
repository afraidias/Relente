# Specs

Relente is built with spec-driven development: every feature starts as a spec, the spec is
approved, and only then is it planned and implemented. The rules are in
[AGENTS.md](../AGENTS.md#how-features-are-built-spec-driven-development); the agent follows the
`spec-driven-development` and `planning-and-task-breakdown` skills in `.claude/skills/`.

## Layout

Each feature has its own folder, numbered in order:

```text
specs/NNN-short-name/
├── spec.md    # what and why (approved before anything else)
├── plan.md    # how: decisions, phases, risks (approved before implementing)
└── tasks.md   # ordered tasks with acceptance and verification
```

Features 001–003 were built before this layout existed and only have `spec.md`.

Project-wide areas (tech stack, commands, structure, code style, testing, boundaries) are defined
once in [AGENTS.md](../AGENTS.md), and the screen flow and design system in
[docs/product.md](../docs/product.md); a spec only adds what is specific to its feature.

## Index

| Spec | Roadmap step | Status |
| --- | --- | --- |
| [001 · Installer screen](001-installer-screen/spec.md) | 3 | Done |
| [002 · USB drive screen](002-drive-screen/spec.md) | 3 | Done |
| [003 · Review screen](003-review-screen/spec.md) | 3 | Done |
| [004 · Creating screen (+ Error)](004-creating-screen/spec.md) | 3 | Done |
| [005 · Done screen](005-done-screen/spec.md) | 3 | Done |
| [006 · Assistant navigation](006-assistant-navigation/spec.md) | 4 | Done |
| [007 · Real disk and installer detection](007-real-detection/spec.md) | 5 | Done |

## Templates

### spec.md

```markdown
# NNN · Feature name

**Status:** Draft · **Roadmap step:** N · **Branch:** `feature/NNN-short-name`

## Objective
What we're building, for whom and why, in two or three sentences.

## Behavior
What the user sees and can do, state by state.

## Changes to earlier features
For each screen or behavior built by an earlier spec that this feature changes: the spec that
built it (e.g. "spec 003"), what changes and why. Earlier specs aren't edited; `docs/product.md`
is updated. Omit if nothing.

## Acceptance criteria
- [ ] Specific, testable condition. The ones about logic become tests.

## Boundaries
Only what this feature adds to AGENTS.md (Always / Ask first / Never). Omit if nothing.

## Edge cases
What happens in unusual situations.

## Decisions
Choices made while writing or approving the spec, with the reason.

## Open questions
Unresolved points that need the owner's input before approval. Empty when Approved.

## Open items
What this feature doesn't do that someone could expect from it (e.g. a button that's shown but
does nothing yet), and work it defers, each with the roadmap step that will do it. Name roadmap
steps, not specs.
```

### plan.md

The plan document template of the `planning-and-task-breakdown` skill: Overview, Architecture
Decisions, Task List by phases with checkpoints, Risks and Mitigations, Open Questions. Add a
**Rules check** section confirming the plan follows AGENTS.md (helper security, architecture,
platforms), or explaining any exception.

### tasks.md

```markdown
- [ ] Task: [Description]
  - Acceptance: [What must be true when done]
  - Verify: [Test, build or manual check]
  - Files: [Files touched, ~5 at most]
```
