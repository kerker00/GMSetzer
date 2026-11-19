# GMSetzer – rules for Claude

Read [Docs/Plan.md](Docs/Plan.md) first; it is the reference for requirements,
decisions, architecture and milestones. [CONTRIBUTING.md](CONTRIBUTING.md)
describes the workflow.

## Always

- Keep the library targets free of runtime dependencies and of Foundation in
  the core; everything must build on Linux.
- Never let the number of passing specification examples drop; raise
  `Tests/SetzerSpecTests/Resources/baseline.json` when more pass.
- Follow the licence rules in Plan section 7 when taking over code or tests:
  MIT, BSD or Apache-2.0 only, origin in the file header, licence in `NOTICE`;
  never GPL or LGPL.
- After finishing a milestone or a change of scope, update Docs/Plan.md
  (status column of the milestones) and, for speed-relevant work,
  Docs/Benchmarks.md.
- Ask before running the full benchmarks or long test runs, before pushing,
  before opening pull requests, and always before publishing anything:
  making the repository public, tags, releases. The owner merges.
- No CI workflows unless the owner asks for them.
