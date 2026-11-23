# GMSetzer – rules for Claude

Read [Docs/Development.md](Docs/Development.md) first; it is the reference for
requirements, decisions, architecture and roadmap. [CONTRIBUTING.md](CONTRIBUTING.md)
describes the workflow.

## Always

- Credit Codex-assisted work in new commits with `Assisted-by: Codex (OpenAI)`
  and in PR descriptions (owner preference, 21 November 2026).

- Keep public APIs and current documentation consumer-neutral. Application
  adapters, session/revision types, UI and device acceptance belong in the
  consuming repository. No consumer checkout may be needed to build, test or
  release this package.

- Keep the library targets free of runtime dependencies and of Foundation in
  the core; everything must build on Linux.
- Keep every specification example ID recorded in
  `Tests/SetzerSpecTests/Resources/baseline.json` passing; add IDs when more
  pass. A new pass must never compensate for a regression elsewhere.
- Use other Markdown libraries only to learn about algorithms, architecture,
  features and pitfalls. Never copy, adapt, translate or port their implementation
  code into GMSetzer, even when their licence permits it. Implement solutions
  independently from specifications and our own requirements; do not reproduce
  another implementation through line-by-line rewriting or AI paraphrasing.
  Reference checkouts under `Parser/` are study material, not code to import.
- Preserve existing third-party notices and provenance. This rule applies to
  future work; it does not erase historical origins. Specification fixtures and
  generated standards data retain their separate licences and attribution.
- For every feature, fix or review correction, follow
  [feature-docs](.claude/skills/feature-docs/SKILL.md) and include the affected
  documentation with the implementation.
- After a confirmed PR merge, follow
  [branch-cleanup](.claude/skills/branch-cleanup/SKILL.md): verify and remove
  merged branches and clean worktrees. At every branch completion, check README
  and affected documentation against main and update stale descriptions.
- Ask before running the full benchmarks or long test runs, before pushing,
  before opening pull requests, and always before publishing anything:
  making the repository public, tags, releases. The owner merges.
- Existing session authorization remains valid. The standing authorization
  in `branch-cleanup` covers verified branch deletion and descriptive
  documentation/skill corrections committed and pushed directly on main
  without another prompt (owner, 20 November 2026). Source, manifests,
  executable workflows, tags, releases and visibility changes are excluded.
- The owner authorised macOS/Linux CI and source-only release preparation on
  20 November 2026; follow [release checklist](Docs/Development.md#release-checklist).
