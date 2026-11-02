# Third-party engineering skills

Source: https://github.com/addyosmani/agent-skills
Revision: `301b02b12bff98e4688e6984af6556802322bbde` (main retrieved 2026-11-02).
License: MIT; the author's root license is retained as ADDY-LICENSE.

## Included skills

- api-and-interface-design
- ci-cd-and-automation
- code-review-and-quality
- constraint-driven-development
- context-engineering
- debugging-and-error-recovery
- deprecation-and-migration
- documentation-and-adrs
- doubt-driven-development
- git-workflow-and-versioning
- idea-refine
- incremental-implementation
- interview-me
- observability-and-instrumentation
- planning-and-task-breakdown
- security-and-hardening
- shipping-and-launch
- source-driven-development
- test-driven-development

## Installation and integrity

The 19 selected skill directories and the shared references directory are unmodified copies
from the pinned revision, including their bundled scripts and resources. Prior Relente-specific
adaptations have been removed. Codex links to the same skill folders used by Claude Code.
Other third-party skills (write-swift and locally exported Apple skills) are separate and were
not changed by this reset.

No upstream commands, hooks, agents, plugin setup or eval services were installed. Bundled skill
scripts are present as upstream resources, not executed or registered as automation. References
to optional personas or integrations do not establish their availability in this project.

Relente decisions and authorization remain in AGENTS.md and project documentation, outside
third-party skill files. Flag conflicts rather than rewriting the author's skills or treating
examples as authorization to change CI, install services, publish or perform destructive work.

## Updating

Fetch and pin the desired upstream revision. Replace the selected directories and shared
references with exact upstream copies, including resources; do not preserve local adaptations.
Keep the author's license, validate exact file manifests/content and discovery links, and record
the revision and actual checks. Do not add other catalog skills without an identified need.
