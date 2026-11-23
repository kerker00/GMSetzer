# GMSetzer development and releases

[Package guide and source contracts](README.md) · [Contributing](../CONTRIBUTING.md)

- [Current state](#current-state)
- [Requirements](#requirements)
- [Architecture](#architecture)
- [Validation](#validation)
- [Performance measurements](#performance-measurements)
- [Release checklist](#release-checklist)
- [Roadmap](#roadmap)
- [Licences and origins](#licences-and-origins)
- [Historical records](#historical-records)

## Current state

23 November 2026: M8 merged through PR #30 at `5f81308`. Release preparation
PR #31 merged at `418882f`, setting identity `1.0.0`, finalising the notes and
freezing the reviewed source API. The latest published source-only preview remains 0.6.0.
No 1.0 tag, stable release or Swift Package Index submission has been created.
The 1.0 syntax scope is implemented; later syntax is roadmap work.

The prepared implementation at `4c21547` passes 263 Swift tests / 31 suites on
minimum Swift 6.2 macOS/Linux CI, optimized builds, 61 Python checks, six DocC
archives and the 610-declaration source API check. A fresh public-HTTPS consumer
resolves that revision without credentials and passes the retained probe.
The evidence-only follow-up at `8c42dae` also passes all three CI jobs in
[run 45134446590](https://github.com/kerker00/GMSetzer/actions/runs/45134446590).
The [1.0 preparation record](Validation/Release/1.0.0.md) retains exact receipts,
commands, hashes and limits. Documentation consolidation changes no runtime
source, API baseline, package manifest, fixture, dependency or workflow.

Merged-main [CI run 45135414454](https://github.com/kerker00/GMSetzer/actions/runs/45135414454)
also passes at `418882f`. Next: review this documentation cleanup, confirm the
exact merged tag commit and follow the release checklist. Owner confirmation
of publication and any remaining acceptance of the recorded evidence stays
explicit. Warning-free DocC does not claim every member has a source summary;
minimum Apple OS runtime and consumer UI/device acceptance are not established
by CI.

## Requirements

- Preserve CommonMark 0.31.2 and the pinned GFM corpus with explicit profiles.
  Protect all recorded 652 CommonMark and 672 GFM example IDs; one new pass
  never compensates for a regression. Fixture/pin updates need separate review.
- Keep six pure Swift products, Swift 6.2, macOS 15 / iOS 18 / visionOS 2
  deployment declarations and Linux support. Library targets use only this
  package and the Swift standard library, with no Foundation or runtime dependency.
- Retain original source bytes, immutable validated trees, exact source/token
  coordinates, portable diagnostics and advisory edits. Validation stays active
  in Release. New syntax is opt-in through the existing extension boundary.
- Keep safe-default HTML, explicit raw-HTML/hook trust and original-byte fix
  preconditions. Protect legal literal fallbacks rather than treating unfinished
  Markdown as syntax errors.
- Use iterative built-in traversal, checked limits, hostile-input tests and
  measured performance. Arbitrary callbacks remain trusted compiled code.
  Depth limits do not promise bounded time/output or total peak memory.
- Keep application sessions/revisions, scheduling, themes, localization choice,
  file/network loading and UI/device tests with consumers. No sibling checkout
  may be required to build, test or release this package.
- Follow the [1.x source-compatibility policy](README.md#source-compatibility).
  Binary ABI, persistent trees/IDs, fixed timings and cross-edit identity are
  outside that contract.

## Architecture

| Product | Responsibility | Library dependencies |
| --- | --- | --- |
| `SetzerSyntax` | Validated tree, original ranges/tokens, source/index queries, portable diagnostics and fixes | Swift standard library |
| `SetzerParser` | Block/inline parser, profiles, checked custom rules and transforms | `SetzerSyntax` |
| `SetzerExtensions` | Optional front matter, footnotes, math, alerts and callouts | `SetzerParser`, `SetzerSyntax` |
| `SetzerHTML` | Full/prepared HTML, safe defaults, anchors and hooks | `SetzerSyntax` |
| `SetzerAnalysis` | Three opt-in native rules over an existing document; optional English/German messages | `SetzerSyntax` |
| `GMSetzer` | Re-exports, validated `MarkdownHTML`, footnote/admonition HTML composition | All five products |

Parsing works over contiguous UTF-8 bytes and a flat value tree. The pipeline
is block parsing, pre-inline transforms, inline resolution, post-inline
transforms. Block continuation uses projected physical lines over the original
source; inline delimiter/bracket state stays internal to one parse. References
resolve over the complete block tree. GFM syntax is core built-in selection;
optional syntax exercises the custom-node boundary.

`Document`, `SourceIndex`, `DocumentIndex`, findings and fixes are snapshot-bound.
Optional indexes/analysis are built only when needed; reparsing and rebuilding
services for a new snapshot remain linear work. There is no incremental parser
or input-streaming API. Progressive HTML starts after a complete parse and
retains its document; a soft group budget is not a memory cap.

Runtime table generation is reproducible from pinned source data under
`Scripts/Data`; Unicode/HTML tables carry versions, hashes and notices.
`Tools/` alone contains development/reference/benchmark package dependencies.
DocC builds use the installed toolchain; the library gains no plugin dependency.
Keep the portable byte-buffer path: adopting `Span`/`UTF8Span` requires an
availability check against deployment targets, not merely a current host build.

## Validation

Run from the repository root:

```sh
swift test
swift test -c release
python3 -I -m unittest discover -s Scripts
python3 -O -I -m unittest discover -s Scripts
python3 -I Scripts/build_documentation.py
python3 -I Scripts/check_public_api.py --graph-dir .build/documentation/symbolgraph
python3 -I Scripts/check_release_version.py v1.0.0
```

The last command is a version/notes preflight; it creates no tag. Use isolated
writable scratch/cache/config/security/module paths in restricted environments.
Do not replace public tree validation with an unchecked benchmark-only path.
Full benchmarks and long test campaigns follow existing owner authorisation.

`.github/workflows/ci.yml` runs minimum Swift 6.2 library/specification tests,
optimized builds and Python checks on macOS and Linux, plus warning-as-error
DocC/API checks. Local Debug/Release validation and independent consumers have
separate receipts. Current M8 cross-builds cover arm64 iOS 18 and visionOS 2;
these and host tests do not establish minimum-OS execution or consumer UI behavior.

Test source/token positions across LF/CRLF/CR, BOM, tabs, escapes/entities,
Unicode, invalid UTF-8/NUL, empty ranges and nested projections. Exercise
extension switches independently and in combinations, transform ownership,
strict/tolerant configuration, raw HTML/URL/hook policies, grouped/full equality,
cancellation, stale fixes and snapshot independence. Distinguish random/mutated
ASan runs from coverage-guided fuzzing, and retain exact source identities.

Reference tests live in `Tools/`, for example:

```sh
swift test --package-path Tools --filter 'ContainerReferenceTests|InlineReferenceTests'
```

Use the authoritative CommonMark/GFM fixtures for their different specification
versions; explain oracle differences instead of changing fixtures to match a
reference parser. The optional normalizer only removes generated void-tag closing
slashes, never text whitespace, attributes, code or original raw HTML.


Documentation consolidation validation (23 November 2026): 747 local Markdown
links and fragments pass; all 36 archived texts retain their original prose
apart from the archive notice and relocated link targets. All 61 Python checks,
six warning-as-error DocC archives, 610-declaration API comparison and `v1.0.0`
version/notes preflight pass. Non-Markdown source and evidence bytes remain
unchanged; no fresh Swift runtime test, benchmark or stress campaign is claimed
for this documentation-only change.

## API compatibility checks

Build DocC and check the inventory with:

```sh
python3 -I Scripts/build_documentation.py
python3 -I Scripts/check_public_api.py --graph-dir .build/documentation/symbolgraph
```

The checker rejects removed/changed declarations, lost conformances and cases
added to existing enums, while allowing additive methods/types. Regression
tests exercise these boundaries. Further checks cover extraction-format
normalisation without accepting removal of the defining type or its extension
members. A new baseline is created only with
`--write-baseline`, which refuses to overwrite an existing file. Do not reset
the baseline to hide a breaking change.

Swift 6.2 omits `@Sendable` in some callback display signatures. Only this
display omission is accepted, and only when the complete actual source header
matches the baseline's lexical tokens, including each annotation's position.
A missing annotation, an annotation on another parameter or one found only
inside a function body still fails. The reviewed baseline is not rewritten
to accommodate the older compiler.

Symbol graphs do not establish behavioural compatibility, default-argument
values, raw string identifiers, binary ABI or specification correctness. Those
remain source review, protected tests and release-review responsibilities.

## Performance measurements

The [package README](../README.md#performance) gives a bounded M7 snapshot.
Its rows retain their measured source/runtime identity and are not timings for
the published 0.6.0 tag or fresh 1.0 results. Read the
[inline-input report](Validation/M7/inline-input-2026-11-22.md#completion),
[README control check](Archive/Benchmarks.md#readme-control-check-23-november-2026)
and [historical measurement ledger](Archive/Benchmarks.md) for exact scopes.

Compare matching CommonMark/GFM profiles over identical actual bytes with source
positions on for GMSetzer and C, including equivalent parse/tree teardown.
`swift-markdown` is context: its default features/tree differ. Keep parse,
pre-parsed render, optional annotations/indexes/analysis and composed pipelines
separate. Allocation request count, gross bytes, retained heap and peak RSS
are different measurements; do not infer one from another.

Commit the harness before a measured run. Record clean/dirty state, source and
executable hashes, Swift/OS/CPU/RAM, `Tools/Package.resolved`, options, actual byte
counts, sampling/warmup settings, units and raw output. Keep setup outside the
clock, avoid competing workloads and retain failed attempts. Build/list first:

```sh
swift package --package-path Tools benchmark list --target ParserBenchmarks
```

On native Linux, invoke the built `BenchmarkTool` directly after build/list,
following the [direct-driver report](Validation/M7/linux-x64-2026-11-21.md).
The SwiftPM parent caused measurable CPU competition in earlier runs. Run full
series only under the owner's applicable authorization; this documentation
cleanup runs no new benchmark or stress campaign.

The ratio goal remains at most 2× matching C time, aiming for parity. Original
Mac pure-parse absolute limits are 4 / 60 / 300 ms at nominal 100 KB / 1 MB /
5 MB; with all optional services they are 10 / 200 / 1000 ms. These are acceptance
goals on the declared measurement scope, not portable device guarantees. The
frozen M2 extra-total-parse allowance is 0.5 / 8 / 40 ms against its hashed M1
baseline. Selected callbacks and validation count inside it; an optimization
creates headroom rather than enlarging the allowance. New workloads require
explicit scoped acceptance rather than silently widening existing budgets.

Existing gates and inputs remain in place:

```sh
python3 -I Scripts/check_benchmark_budget.py /path/to/raw-results.md
python3 -I Scripts/check_m2_budget.py /path/to/raw-results.md
```

Use each script's `--help` and the archived receipt for baseline/variant options.
Progressive resource checking requires matching runtime/tool inventories and
raw records; never relabel old hashes as a measurement of newer code. The
[HTML-copy report](Validation/M7/html-copies-2026-11-22.md) and
[inline-input report](Validation/M7/inline-input-2026-11-22.md) link their actual
42-case / 126-check progressive resource results. No general C parity,
constant-memory or minimum-device latency claim follows from them.

## Release checklist

The owner merges. Existing source-preparation and push/PR authorization does
not create authorization for tags, release publication or Index submission.
Follow each explicit confirmation at its corresponding step.

1. Prepare `Docs/Releases/<version>.md` and the matching
   `GMSetzerVersion.current`. Review the source-compatibility policy and baseline,
   limitations, platform evidence, examples and notices. Merge the preparation
   PR and require successful merged-main checks.
2. After owner confirmation of the exact merged commit/version, fetch `main`,
   check a clean checkout and create/push an annotated immutable `vMAJOR.MINOR.PATCH`
   tag at that commit. Never move or overwrite a published tag.
3. `.github/workflows/release.yml` verifies tag shape, main ancestry, runtime
   identity and final nonempty notes; it reruns CI and creates a draft. Versions
   below 1.0 are prereleases. A rerun leaves an existing release untouched.
4. Verify the draft's exact notes, tag target, flags and zero uploaded assets,
   successful tagged checks, a fresh unauthenticated public-HTTPS exact-version
   SwiftPM consumer and both automatic GitHub source ZIP/tar.gz URLs. A revision
   consumer before tagging does not replace this exact-version check.
5. Publish after owner confirmation and record the URL, checks and immutable
   target under `Docs/Validation/Release/<version>.md`. Releases are source only;
   SwiftPM resolves Git tags, not release assets or a package registry. A tag
   is already publicly resolvable while a GitHub release remains a draft.
6. Prepare Swift Package Index inclusion with canonical URL
   `https://github.com/kerker00/GMSetzer.git`, checking an existing listing first.
   Review the exact externally visible request and obtain confirmation before
   submitting. After real builds exist, verify the six documentation targets
   and add only verified package/documentation/badge URLs to the README.
7. After a confirmed merge, follow the repository's
   [branch cleanup](../.claude/skills/branch-cleanup/SKILL.md): prove tip containment,
   protect open PRs and dirty worktrees, remove only verified merged branches
   and reconcile current documentation. The owner retains merge/publication control.

The [1.0 preparation record](Validation/Release/1.0.0.md) links local and minimum-
compiler checks, the retained independent consumer probe and prepared Index data.
Published [0.4.0](Validation/Release/0.4.0.md), [0.5.0](Validation/Release/0.5.0.md)
and [0.6.0](Validation/Release/0.6.0.md) records describe their own tags.

The Index's [inclusion requirements](https://swiftpackageindex.com/add-a-package)
are a public root Swift package, a SemVer tag, valid latest-toolchain
`swift package dump-package` JSON and a compiling package. Version 1.0 is not
required merely for inclusion. Root `.spi.yml` lists all six documentation
products with `GMSetzer` as the landing target. SPI injects its documentation
plugin; no runtime/plugin dependency is added to this library. Local catalogs
and CI establish package readiness, not an accepted SPI listing/build.

## Roadmap

Later stages are proposed work packages, not published capabilities or dates.
Minor-version labels express sequence and can be split by acceptance needs.
Finish the existing stable release before introducing more syntax. Preserve
CommonMark/GFM and 1.x source compatibility: new syntax is independently opt-in
with exact original-byte provenance and a defined safe HTML policy. Use custom
nodes; adding cases to existing public enums is outside the minor-release policy.

### 1.0 — publish the existing scope

CommonMark/GFM, optional front matter/footnotes/math/alerts/callouts, original-byte
trees/tokens, position/query/analysis services and full/progressive HTML are
implemented. M8's validated HTML facade, six DocC catalogs and API guard are
merged. Complete owner review of the declared API/documentation and M7 robustness/
performance scope, verify the exact merged release source and follow the release
checklist. No intermediate 0.7 tag is required; new syntax stays outside 1.0.

### 1.1 — document links and attributes

**Goal:** support predictable navigation and semantic markup in Markdown
documents, without embedding application-specific file resolution.

- Opt-in `[[target]]` and `[[target|label]]` wikilinks, with a precise escaping,
  nesting, unresolved-target and source-token contract.
- Explicit heading IDs and classes, such as `# Heading {#overview .wide}`.
  Define duplicate IDs, malformed attributes and safe HTML attribute handling.
- Define a caller-controlled link-resolution/rendering boundary. Recognising
  a target does not open files, fetch URLs or assign project identity.
- Consider generated heading slugs separately from existing source anchors:
  content-derived link IDs and snapshot-local editor anchors serve different purposes.

**Done when:** selections remain independent; off-mode outputs stay unchanged;
Unicode/escaping, nested containers, source projections and HTML trust boundaries
have regression coverage. Full and grouped HTML agree, with exact ranges/tokens
and measured selected-feature costs before speed claims.

### 1.2 — additional writing syntax

**Goal:** add a focused set of opt-in authoring constructs.

Candidate order: definition lists; highlighted text (`==text==`);
superscript/subscript; spoiler or inserted-text spans. Emoji shortcodes and
smart punctuation are separate options, since they transform literal text
rather than merely introducing containers.

**Done when:** each syntax has a written delimiter/precedence/escaping contract,
independent switches, original-byte provenance and a safe HTML recipe. Syntax
inside code, links, math and custom rules remains protected. Typography defines
language policy and does not silently alter strict CommonMark/GFM literals.
Select a bounded subset for each actual release rather than coupling all candidates.

### 1.3 — tree processing and Markdown output

**Goal:** make structured document inspection and transformation convenient,
and allow callers to generate normalised Markdown from a validated tree.

- Public traversal/visitor conveniences with clear subtree skipping and
  source-order semantics, where the 1.0 API review identifies a need.
- Explicit transformation helpers that preserve tree validity and make source/
  token ownership after edits unambiguous.
- A Markdown writer with configurable markers, fences and wrapping, plus an
  explicit policy for custom nodes and selected extensions.

**Done when:** parse/write/parse tests preserve the declared semantic subset;
unsupported custom content has a defined fallback; edits cannot silently reuse
stale positions. A normalising writer is not advertised as lossless preservation
of original spelling, whitespace or comments.

### 1.4 and later — reusable document extensions

**Goal:** add further document structures only for demonstrated use cases.

Candidates include attributed/fenced containers, block directives with named
arguments, additional annotation/query conveniences and coherent optional
profiles assembled from individually tested extensions. Wikilink embeds need
a separate syntax/content-resolution design; they do not follow automatically
from link support.

**Done when:** nested/projected source ownership, interaction with existing
extensions, caller-controlled resource handling and rendering fallbacks are
specified and tested. Profile names do not imply compatibility with every
external dialect feature.

### Separate architectural investigations

| Investigation | Required decision before implementation |
| --- | --- |
| Event-oriented parsing/output without a retained full AST | Define which source, validation, editor and reference services remain available; measure whether the alternative reduces actual workload cost |
| Incremental reparsing after edits | Define revision ownership, invalidation of references/list context/footnotes and exact result equivalence against a full parse |
| Input streaming | Specify late definitions, ownership, finalisation and explicit restrictions/fallbacks; progressive HTML alone does not provide this |
| Additional renderers | Choose a concrete need for structured tree export, LaTeX or another format and a policy for every extension/custom node |
| Further throughput, memory and fuzzing work | Use current profiles and representative workloads to choose the next change; preserve controls and separate gross allocation traffic from retained/peak memory |

No architecture rewrite or new major version is scheduled by this table.
Additive APIs can fit 1.x; a change that breaks the accepted contract requires
a separate major-version proposal. Built-in TeX/code-highlighting engines,
diagram execution, document styling and application-level linking are outside
the current runtime dependency boundary.

## Licences and origins

The package is MIT. Take over or port code/tests only from MIT, BSD or
Apache-2.0 sources with a recognizable licence. Record origin in file headers
and the licence in [NOTICE](../NOTICE); exclude GPL/LGPL and unlicensed code.
Generated Unicode/HTML data keep their pinned source/version/licence metadata.
Specification texts remain separate CC-BY-SA 4.0 test data, outside the library.
Ideas do not remove the attribution obligations for copied code or fixtures.

## Historical records

The current documentation is deliberately limited to [the package guide](README.md)
and this document. [Archive](Archive/README.md) holds prior plans, individual
feature narratives, milestone acceptances, reviews, status logs and the full
measurement ledger. Their dates, test counts and pending-status statements
refer to the recorded checkpoint, not today's release state.

`API/` contains machine-readable compatibility inventories; `BenchmarkData/`
and `Validation/` retain raw measurements, logs, hashes and executed receipts.
`Releases/` holds version-specific release notes read by automation. Those
separate artifacts are evidence and inputs, rather than additional current
handbooks; their machine-consumed paths and bytes are preserved.
