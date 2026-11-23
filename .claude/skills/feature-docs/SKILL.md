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

- [Docs/Development.md](../../../Docs/Development.md): update current state,
  requirements, architecture, roadmap, validation and release steps when affected.
  Distinguish planned, implemented, reviewed and merged work. A merged PR alone
  does not establish milestone acceptance or publication.
- [Docs/README.md](../../../Docs/README.md): maintain current package examples,
  tree/source/token coordinates, extension grammars, HTML trust and progressive
  output contracts, positions, native analysis and advisory fixes. Keep planned
  capabilities labelled planned. Library checks do not establish consumer UI
  behavior, diagnostic underlines or device acceptance.
- [README.md](../../../README.md): update the public summary, installation,
  examples and limitations when behavior or release state changes.
- For speed-relevant work, update Development's measurement summary and retain
  scoped execution reports/raw data under `Docs/Validation/` and
  `Docs/BenchmarkData/`. Record configuration/source identities and pending
  measurements without rewriting older evidence as current results.
- Keep current prose in the two handbooks; fold in useful contracts and remove
  superseded standalone documents rather than adding an archive copy. Historical
  prose remains in Git history; use immutable commit links when old context is
  needed. Preserve machine-readable/raw evidence and versioned release notes
  in their established directories. Do not create new milestone/status files.
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
