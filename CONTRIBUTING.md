# Contributing to GMSetzer

Start with [Docs/Plan.md](Docs/Plan.md): it explains what the library must do,
the decisions behind it and the order of work.

## Library boundary

Keep public types and current documentation independent of any consumer.
Application-specific adapters, session/revision models, UI and device test
reports belong in the consuming repository. Runtime library targets depend
only on this package's own modules and the Swift standard library; no sibling
checkout may be required. Preserve historical validation records as history.

## Workflow

1. Create a feature branch from `main` (`feature/m1-blocks`, `fix/…`).
2. Make the change with tests. Add newly passing specification example IDs to
   `Tests/SetzerSpecTests/Resources/baseline.json` in the same commit. Never
   remove a protected example to hide a regression.
3. Run `swift test`; after changes to spec tools, also run
   `python3 -I -m unittest discover -s Scripts`. For speed-relevant changes,
   prepare the benchmarks (`cd Tools && swift package benchmark`) and record
   measurements in [Docs/Benchmarks.md](Docs/Benchmarks.md); obtain the owner's
   confirmation before full benchmark runs or long test runs.
4. Follow [feature-docs](.claude/skills/feature-docs/SKILL.md) to update the
   affected documentation with the implementation, including milestone,
   contract and validation changes.
5. Open a pull request against `main`. The owner merges.
6. After a confirmed merge, follow
   [branch-cleanup](.claude/skills/branch-cleanup/SKILL.md) to verify and remove
   merged branches and clean worktrees. At every branch completion, reconcile
   README and affected documentation with current main. The owner authorised
   committing and pushing these descriptive documentation/skill corrections
   directly on main without another approval or docs PR (20 November 2026).
   This exception does not include code or executable workflows.

## Rules

- English for code, comments, commits, pull requests and documentation.
- No runtime dependencies in the library targets. Development dependencies go
  into `Tools/` or test targets.
- Code taken over or ported from other projects: MIT, BSD or Apache-2.0 only,
  origin in the file header and licence in `NOTICE`. Never GPL or LGPL code.
- Every bug fix comes with a regression test.
- The owner authorised macOS/Linux CI and source-only release preparation on
  20 November 2026. See [Releasing](Docs/Releasing.md) for checks and the draft
  release process. Releases, tags and making the repository public still
  require the owner's explicit confirmation before the step.
