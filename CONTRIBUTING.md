# Contributing to GMSetzer

Start with [Docs/Plan.md](Docs/Plan.md): it explains what the library must do,
the decisions behind it and the order of work.

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
4. Update [Docs/Plan.md](Docs/Plan.md) when a milestone, a decision or a
   requirement changes.
5. Open a pull request against `main`. The owner merges.

## Rules

- English for code, comments, commits, pull requests and documentation.
- No runtime dependencies in the library targets. Development dependencies go
  into `Tools/` or test targets.
- Code taken over or ported from other projects: MIT, BSD or Apache-2.0 only,
  origin in the file header and licence in `NOTICE`. Never GPL or LGPL code.
- Every bug fix comes with a regression test.
- No CI, releases, tags or making the repository public without the owner's
  explicit confirmation right before the step.
