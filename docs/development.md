# AI-native software development lifecycle

Relente follows the [AI-native SDLC playbook](https://academy.claude.com/courses/ai-native-sdlc-playbook/introduction).
[AGENTS.md](../AGENTS.md) is the rules authority. The owner is the product and engineering decision
maker. Agents research, draft, implement and verify within the owner's authorization.

## Plan and Design

Read current product behavior, relevant issues and code. Capture the problem,
audience, desired outcome, constraints, non-goals and evidence in `intent.md`. Resolve material
unknowns with the owner, then record acceptance. Produce `spec.md` in a working design session:
behavior, acceptance criteria, edge cases, UX/security concerns, decisions and affected existing
behavior. Apply relevant skills and Apple HIG; record deliberate exceptions and their reasons.
The owner accepts the design before implementation planning begins.

Use one `intent/<short-name>/` folder for the change. See the [artifact templates](../intent/README.md).
Record approvals as owner, date, artifact revision and conversation reference or a short accurate
quotation. Use a revision number until a commit permalink exists. Changed scope, behavior or risk
invalidates the affected acceptance; obtain explicit acceptance of the revision. Do not treat a
previous plan's approval as approval of a new design. Small changes can have short documents.
The three reviews may happen in one conversation, provided each accepted stage is clear. Do not
require an extra turn simply to repeat an approval already given. Silence is not acceptance.
Never invent approval records, issue references or verification results.

## Goal-based execution and session continuity

Use bounded goal-based execution within the accepted lifecycle, following the principles of
[Anthropic's loop engineering guide](https://claude.com/resources/articles/getting-started-with-loops).
Agree on the outcome, scope, evidence of success and relevant execution limits before running
implementation work. The agent selects the next authorized action, performs it, verifies the
result, corrects failures and continues until the outcome is established or a stop condition is met.
Do not ask for repeated confirmation of routine steps already covered by the accepted scope.

Stop when the goal is verified, a material scope/behavior/risk decision needs owner input, required
access or evidence is unavailable, or an agreed time/attempt/usage limit is reached. Do not repeat
an unsuccessful approach without new evidence or expand scope to force completion. If no numerical
budget was agreed, do not invent one or claim an enforced runtime limit exists. Merge and release
publication retain their separate authorization rules.

Persist decisions in the appropriate change artifacts, not only in the chat. Keep plan.md current
with implementation status, actual verification, limitations, open questions and the next action.
When a session transition is useful, record branch/worktree, relevant uncommitted work and a concise
handoff in that plan; the continuing session reads it and checks repository state before acting.
Do not require the owner to reconstruct or paste the conversation. Group routine authorized
corrections and reserve questions for real decisions or missing information.

This is an execution practice, not an installed persistent runner. Do not claim automatic context
resets, chat creation, background continuation or cross-agent orchestration unless those capabilities
are actually available and authorized. Independent agents retain their authorization requirement.
Scheduled/proactive loops, autonomous monitoring and paid services remain disabled; adopting this
practice does not enable them or modify third-party skills.

## Documentation ownership

AGENTS.md holds project-specific rules. Current app behavior belongs in docs/product.md;
durable decisions belong in docs/decisions/ and pending work in issues or the release-readiness checklist. Link
accepted change documents to these sources instead of duplicating them. Keep intent, design,
plan, implementation and evidence connected to the issue and PR. Record the merged outcome
with a PR or commit permalink once available. Update affected artifacts before implementing an
accepted behavior change, and update product documentation with the resulting behavior.

## Build and Test

Write `plan.md` with ordered tasks, dependencies, files or
subsystems, acceptance, risks and proof. Ask the owner to resolve concerns and accept the plan
before implementation. Keep the plan current and record approved deviations.

During implementation, run focused tests and lint changed Swift files.
Before integrating code, complete required unit tests, Release build and full strict lint; do not
repeat them after each edit when a narrower check provides the relevant evidence. For changes
limited to documentation, verify content, links and consistency without rebuilding unchanged app
code. Existing required CI gates still run. Full recursive formatting is a maintenance operation
documented in BUILDING.md, not a default verification step; keep formatting scoped to the change.
For local tests, use the existing Xcode project and Relente scheme with configured automatic
signing. The equivalent xcodebuild command must preserve those signing settings. Diagnose a
signing or registration failure before proposing any workaround; do not create app copies,
temporary project variants or signature overrides to make the check pass. Temporary test fixtures
or logs are not alternate app builds, and isolated worktrees remain appropriate for independent
work. Unsigned CI/compile checks are separate evidence and do not verify real signing or helper
registration. See BUILDING.md for the local workflow.

Record commands, outcomes, warnings and unverified manual checks. Never run real disk operations
as a process test. Product UI tests use sample data. Accessibility, appearance and supported-OS
checks need real evidence; a run on a newer OS does not prove behavior on the minimum supported macOS version.

Codex reads `AGENTS.md`. Claude Code reads `CLAUDE.md`, which imports it. The skill source is
`.claude/skills/`; `.agents/skills/` exposes the same folders for Codex. If automatic discovery is
unavailable, read the relevant `SKILL.md` directly. Do not install project rules globally.
Keep third-party skills and their bundled references unmodified. Record source revisions and
licenses in .claude/UPSTREAM.md; keep Relente decisions in project-owned documents. If upstream
recommendations conflict with AGENTS.md or require unavailable tools, flag the conflict and apply
the project rules rather than editing the third-party skill. Optional integrations and scripts
are not activated by installation.
Use separate worktrees for independent sessions. Review shared-file changes before integration.
Independent review is useful when available, but subagents require explicit owner authorization.
Do not duplicate project rules in CLAUDE.md. Personal preferences belong in ignored
.claude/settings.local.json or CLAUDE.local.md; never store secrets in instruction files.

## Apple guidance and Xcode tools

Use [Apple Developer Documentation](https://developer.apple.com/documentation/) for API contracts,
availability, requirements and limitations, and the
[Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/getting-started)
for native macOS interaction and design. Consult the topics relevant to the change rather than
assuming every recommendation applies. Check the installed SDK and supported deployment targets;
validate runtime behavior that documentation alone cannot establish. Relevant Apple/Xcode skills
and Swift skills guide implementation; they do not replace official sources or project constraints.
Verify skill availability in the active agent rather than assuming Xcode skills are installed or
loaded in both agents.

Proactively select tools that answer concrete quality questions:

| Change or question | Useful tools and evidence |
| --- | --- |
| Compilation and behavior | Build and Test in the existing project/scheme; inspect test results and use coverage to find relevant untested paths. Coverage percentages alone do not establish correctness. |
| Interface states and interactions | SwiftUI previews and UI tests, supplemented by manual checks of affected flows. |
| Crashes, memory or concurrency defects | Xcode debugger, Memory Graph and applicable runtime diagnostics or sanitizers supported by the target and toolchain. |
| Responsiveness, CPU, memory or resource usage | Product → Profile with Instruments; choose the relevant instrument and compare reproducible scenarios before and after a performance change. |
| Accessibility | Accessibility Inspector and manual VoiceOver and Reduce Motion checks of affected interfaces. |
| Distribution readiness | Archive and the applicable distribution validation, plus the checks in the [release runbook](release.md). Publication remains separately authorized. |

Not every change needs every tool. Record the question, relevant environment, results and
limitations in the change's verification evidence; do not claim a check ran because a tool is
available. Follow the existing signing workflow and use safe sample scenarios for tooling that
executes the app; profiling or diagnostics never authorize erasing a real disk. These practices
add no new CI jobs, services or required paid AI tools.

## Deploy

Review the diff against accepted intent, design and plan. Record findings, resolutions and actual
verification in the PR. Interactive agent review assists the owner; helper, authorization,
erasure and signing changes always require human review. Do not claim independent review when
only the implementation session reviewed its own output.

Within approved work, the agent may commit, push to the work branch and open a PR without
asking at each step. Respect narrower owner instructions and preserve unrelated work. Merging
requires owner review and approval; passing checks alone is insufficient. Signing and release
configuration changes follow the accepted design and implementation plan, including their security
impact; do not request additional approval for changes already covered. Unplanned changes return
to review. App-dependency changes retain their approval rule. Existing required CI checks and
branch protections still apply.
Link the issue, change directory and eventual PR; use `N/A` with a reason if there is no issue.
Release publication is separately authorized; Git preparation is not release approval. Follow the [release runbook](release.md).

## Maintain

Triage reports with macOS version, app version, installer source/version and relevant sanitized
logs. Security reports follow [SECURITY.md](../SECURITY.md), not public issues. Record accepted
improvements as issues, then start a new intent. Update current product docs,
ADRs and relevant skills when behavior or durable knowledge changes.

Use PR history to inspect time to review, first-pass CI success and rework during the pilot.
This is an owner-assisted feedback loop, not background monitoring. Automated agent evals, paid
AI review in CI and autonomous production monitoring are **not enabled**. They need a separately
approved design, permissions and cost decision, with explicit owner authorization.

## Controls and their limits

| Layer | Applies to | What it enforces |
| --- | --- | --- |
| AGENTS.md / CLAUDE.md / skills | Both agents | Advisory rules and procedures; not an execution sandbox. |
| Native tool permissions | The active agent runtime | Actual allowed actions and escalations; inspect configuration per session. |
| `.githooks/pre-commit` | Git clients using `core.hooksPath=.githooks` | Formatting of staged Swift files; not owner approval. |
| `.githooks/commit-msg` | Git clients using that hooks path | Conventional Commit syntax; not authority to commit. |
| Existing CI and main protection | GitHub PR integration | Required build, tests, lint and title checks; not semantic security review. |
| Owner review | Both agents | Acceptance and publication authorization, including critical security changes. |

No Claude-specific action hooks are installed by this migration. Such hooks would not constrain
Codex. Git hooks are bypassable and local; branch protection remains the shared integration gate.
Never claim a deterministic approval gate exists where approval is enforced only by instructions.

## Process acceptance and pilot

Static checks establish shared entrypoints and artifact consistency. Verify runtime loading in
both tools when available: ask each to identify its rules, current stage and authorization limits.
Use hypothetical requests (no execution) to confirm that an unapproved design stays in planning,
a changed erase requirement returns to review, and Git autonomy within an accepted plan does not
authorize merging without owner review or publishing a release.
These are advisory behavior checks, not proof of a sandbox.

Exercise existing Git hooks in a temporary repository: allow formatted staged Swift and a
Conventional Commit message; reject malformed Swift and an invalid message. Do not commit or
publish to perform this check. Inspect CI without changing it.

The first change after installer acquisition is the pilot: review intent, design and plan, verify
both tools' loading, implement within authorization, record test/review evidence and inspect
rework. Correct contradictions before the next change. The migration is not fully exercised
until this pilot is recorded; do not mark future or unavailable checks as passed.
