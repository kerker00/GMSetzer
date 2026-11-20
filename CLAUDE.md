# GMSetzer – rules for Claude

Read [Docs/Plan.md](Docs/Plan.md) first; it is the reference for requirements,
decisions, architecture and milestones. [CONTRIBUTING.md](CONTRIBUTING.md)
describes the workflow.

## Always

- Keep public APIs and current documentation consumer-neutral. Application
  adapters, session/revision types, UI and device acceptance belong in the
  consuming repository. No consumer checkout may be needed to build, test or
  release this package.

- Keep the library targets free of runtime dependencies and of Foundation in
  the core; everything must build on Linux.
- Keep every specification example ID recorded in
  `Tests/SetzerSpecTests/Resources/baseline.json` passing; add IDs when more
  pass. A new pass must never compensate for a regression elsewhere.
- Follow the licence rules in Plan section 7 when taking over code or tests:
  MIT, BSD or Apache-2.0 only, origin in the file header, licence in `NOTICE`;
  never GPL or LGPL.
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
  20 November 2026; follow [Docs/Releasing.md](Docs/Releasing.md).
