# Change artifacts

Use one descriptive folder per change under `intent/<short-name>/`, with `intent.md`, `spec.md` and `plan.md`. These artifacts
follow the [AI-native SDLC playbook](https://claude.com/es/resources/articles/the-ai-native-sdlc-playbook):
Plan captures intent, Design records requirements and design, and Build starts from an accepted
implementation plan. They feed verification, review/deployment and maintenance in the six-stage
[lifecycle](../docs/development.md); they are not a separate numbered-spec workflow. No numeric feature registry or separate task
file is required. Keep tasks and execution evidence in the plan; issues track backlog, not a
second copy of every task. Keep completed artifacts as the audit trail of new changes.

Each document starts with its revision, state (`Draft`, `Accepted`, or `Superseded`), related issue
(or `N/A` with reason), and approval record. Record approver, date, approved revision and actual
conversation evidence; use `Pending` until explicitly accepted. Link the eventual PR in the plan.
The plan additionally records implementation state (`Not started`, `In progress`, `Verified`,
or `Integrated`). Acceptance is not implementation completion or merge/release approval. Git preparation follows
the autonomy and any narrower owner instructions in AGENTS.md.

## intent.md

- Problem and supporting evidence
- Audience and desired outcome
- Constraints and non-goals
- Success measures and open questions
- Approval record

## spec.md

- Link to accepted intent
- Requirements and user-visible behavior
- Changes to existing behavior
- Testable acceptance criteria and edge cases
- Security/UX concerns and decisions, including HIG exceptions
- Deferred work linked to issues or release-readiness follow-up
- Approval record

## plan.md

- Links to intent, design, issue and PR
- Approach, affected subsystems and ordered implementation checklist
- Per-task acceptance and verification; dependencies where needed
- Risks, failure handling and release/recovery considerations
- Approval record and approved deviations
- Execution evidence, review findings, limitations and follow-up links

A revision affecting accepted scope, behavior or risk needs new acceptance before implementation.
Durable architectural decisions belong in `docs/decisions/`; current app behavior belongs in
`docs/product.md`. Documents and implementation travel together in the change branch and PR.


## Location and upstream guidance

The [playbook intent guidance](https://academy.claude.com/courses/ai-native-sdlc-playbook/capture-intent)
recommends `intent/` in a single-product repository. Its
[CLAUDE.md example](https://academy.claude.com/courses/ai-native-sdlc-playbook/claude-md)
keeps intent.md, spec.md and plan.md there for each change. Relente uses a descriptive subfolder
per change to keep concurrent work distinct; that subfolder naming is a local organization
choice, not a mandatory upstream path. The owner accepted replacing docs/changes/ with this
convention on 2026-11-03. Third-party skills remain unchanged; their default tasks/ output paths
yield to this documented artifact home.
