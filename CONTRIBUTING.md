# Contributing to GMSetzer

Start with [Docs/Development.md](Docs/Development.md): it explains requirements,
architecture, roadmap, checks and release procedure. The current package contracts
are in [Docs/README.md](Docs/README.md).

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
   prepare the benchmark build/list and follow the measurement instructions
   in [performance measurements](Docs/Development.md#performance-measurements),
   including the direct driver for native Linux. Obtain the owner's confirmation before full benchmark runs
   or long test runs.
4. Follow [feature-docs](.claude/skills/feature-docs/SKILL.md) to update the
   affected documentation with the implementation, including milestone,
   contract and validation changes.
   Build all six DocC catalogs with `python3 -I Scripts/build_documentation.py`.
   Check the frozen 1.0 source API with `python3 -I Scripts/check_public_api.py
   --graph-dir .build/documentation/symbolgraph`. Review behavioural/default/identifier
   changes separately; never regenerate the compatibility baseline to hide a break.
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
- Study other implementations for ideas and lessons only. Never copy, adapt,
  translate or port their implementation code, regardless of licence. Develop
  independently from specifications and our own requirements; preserve existing
  notices and the separate provenance of specification fixtures/generated data.
- Every bug fix comes with a regression test.
- The owner authorised macOS/Linux CI and source-only release preparation on
  20 November 2026. See [Releasing](Docs/Development.md#release-checklist) for checks and the draft
  release process. Releases, tags and making the repository public still
  require the owner's explicit confirmation before the step.
