---
name: feature-docs
description: Update GMSetzer's English project documentation after a feature, fix or review correction, together with the implementation and before its PR.
---

# Keep documentation with the change

Documentation is part of the work, on the same branch and normally in the same
commit or the commit immediately after the implementation. Follow
[CLAUDE.md](../../../CLAUDE.md) and
[CONTRIBUTING.md](../../../CONTRIBUTING.md); write project documentation in
English and report to the owner in German.

## Find the affected contracts and evidence

Read the branch diff against `origin/main` and the relevant plan section. For
stacked PRs, also inspect the diff against the prerequisite branch so that the
new change and inherited work are described accurately.

Record the validation actually performed: commands, test counts, protected spec
IDs, reference comparisons and any benchmark configuration. State missing
evidence, such as Linux, the minimum supported Swift version, fresh timings or
consumer editor/device checks. Do not run full benchmarks or long tests solely to
fill a documentation entry; follow the owner's existing authorization.

## Update only the affected documents

- [Docs/Plan.md](../../../Docs/Plan.md): update the current status, affected
  requirements, decisions, milestone status and next work. Distinguish planned,
  implemented, reviewed and merged work. A merged PR alone does not complete a
  milestone; check its acceptance criteria and keep remaining work explicit.
- `Docs/SyntaxTree.md`, `Docs/HTMLReferences.md` and `Docs/EditorAnalysis.md`,
  when present: maintain the affected tree, parsing, source-range or analysis
  contracts and their validation evidence. Keep planned APIs labelled planned.
  For consumer analysis integration, distinguish parser syntax details from diagnostics,
  linting and UTF-16 editor ranges; library tests do not prove editor underlines
  or device behavior. Coordinate any required consumer documentation change in
  its repository rather than claiming integration is finished here.
- [README.md](../../../README.md): update public examples, supported behavior
  and limitations when the user-facing API or project status changes.
- [Docs/Benchmarks.md](../../../Docs/Benchmarks.md): for speed-relevant work,
  record measured results with configuration and comparison scope, or state
  that fresh measurements are pending. Preserve historical results as history.
- `Tests/SetzerSpecTests/Resources/baseline.json` and its `README.md`: add newly
  passing IDs with the implementation and keep corpus descriptions current.
  Never remove protected IDs to hide regressions or trade failures for passes.
- [NOTICE](../../../NOTICE): record origins and licenses when code or tests
  are copied or ported, following Plan section 7.

## Before committing or updating the PR

Use `rg` to find stale status or branch references in the affected documents.
Check links and heading anchors. Preserve historical review records instead of
rewriting them as current results. Stage the affected documentation explicitly
with the change, and include relevant evidence and limits in the PR description.
