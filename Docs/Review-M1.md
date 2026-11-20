# M1 review — 19 November 2026

Scope: architecture, code, quality assurance and extensibility of the merged M1
state (`main` at `7d4c8a5`, library code identical to `2132a15`), measured
against [Plan.md](Plan.md), [EditorAnalysis.md](EditorAnalysis.md) and
Setzkit's parser, pipeline and extension requirements. This review records
findings and recommendations only; no library code was changed.

**Portability follow-up, 20 November 2026:** [Portability.md](Portability.md)
records a Swift 6.2 build, all 57 macOS tests, and actual static Linux ARM64
execution retaining every protected spec ID. Full Linux Swift Testing/glibc/
x86-64 coverage remains open. Compile probes distinguish the back-deployable
Span type/buffer bridge from macOS-26-only Array.span and UTF8Span. These
results supplement the original findings below; no library source changed.

## Summary

The foundation is sound: a dependency-free module split, typed payloads from
which node kinds derive, a flat `Sendable` value tree, byte ranges into the
original snapshot with source segments, iterative traversal, and a regression
baseline per specification example. Three areas need decisions **before M2**,
because the inline phase would otherwise be built on structures that later
have to change:

1. **Performance:** informal block-only timings warn of insufficient headroom;
   the comparable performance baseline is still missing.
2. **Extension architecture:** only custom leaf blocks are possible, and
   built-in syntax uses a separate path from extensions.
3. **Block parser structure:** the main loop needs to be decomposed before
   inline parsing and more extension hooks are added.

## Evidence

- `swift build` succeeds with Swift 6.4.2 on Apple Silicon (macOS 27).
- The test suite was **not** run for the original review. The subsequent
  repository assessment and its test evidence are recorded below.
- A throw-away probe executable in a scratch package (release build, local path
  dependency) reproduced the findings marked *confirmed* below and produced the
  informal timings in the next table. These are not package-benchmark results
  and do not replace [Benchmarks.md](Benchmarks.md).

| Informal measurement, 1 MB, release, best of 5 | Result |
| --- | --- |
| Parse, block phase only, mixed document (headings, paragraphs, lists, quotes, fenced code) | 66 ms |
| `Document(source:nodes:)` validation of the same tree alone | 25 ms |
| Parse, plain paragraphs only | 20 ms |
| Render the mixed document | 31 ms |
| Historical 2 × cmark-gfm estimate (19 ms without source positions; not a current acceptance limit) | 38 ms |
| Plan absolute target, Mac | < 60 ms |

The 66 ms probe is a warning against the absolute target, not a reproducible
benchmark failure. The 38 ms estimate cannot establish a ratio failure: the C
configuration lacks source positions, the documents and measurement methods
are not established as identical, and best-of-five timings are not benchmark
medians. The corrected harness must measure the corresponding configurations
on the same corpus before a speed claim or a numeric phase budget is accepted.

## Architecture findings

| Priority | Finding | Recommendation |
| --- | --- | --- |
| High | **Performance risk before inline parsing.** The validation-only probe is about a third of the parse probe's time, suggesting a substantial cost; this is not an instrumented attribution. Per-text `String` values and per-node segment arrays are further candidates, with actual allocation costs still to measure. | Establish comparable measurements and a phase/annotation budget before optimising. Retain release validation of public tree construction. Measure dense visited storage instead of `Set<Int>` first; a parser-only trusted construction path needs equivalent invariant checks and tests. Evaluate shared segments and lazy literals before changing payload storage. |
| High | **No parent links and no position query.** Setzkit's breadcrumb and folding need "node at offset X and its ancestors". There is no query API today. A caller can prune ordered child ranges during a search, but finding parents after locating a node can still require a scan. | Decide parent and position-index storage before M2. Parent links accelerate ancestor traversal but alone do not provide fast offset lookup. Implement the query API with M3 outline work, including boundary and zero-length policies. |
| Medium | **Syntax spans grow per payload.** `ReferenceSyntax` is a dedicated structure for one node kind. Repeating that pattern for every inline payload makes the model sprawl, while callers such as Quick Look should not pay for spans at all. | Introduce one optional, generic token table in `Document` (role, range, owning node) before M2. It also serves EditorAnalysis syntax roles and extension syntax. |
| Medium | **Configuration problems are reported as document diagnostics.** Missing or duplicate extensions appear in every parsed `Document` at range `0..<0`. EditorAnalysis requires configuration failures to stay separate from document findings. | Resolve the registry once in `MarkdownParser.init` and report configuration problems there, for example through a throwing or validating initializer. |
| Medium | **`try!` in the parser.** Append, container finishing and final build trap on builder errors. These represent internal invariants today, but a future validation gap could crash the host, including a Quick Look extension. | Audit each invariant before changing construction. If recovery is introduced, retain original bytes, return a valid tree and report an infrastructure failure separately from document findings; a fallback must not silently hide a parser bug. Trusted callback traps cannot be recovered by catching Swift errors. |
| Medium | **UTF-8 byte order mark not handled (confirmed).** `"\u{FEFF}# Title"` renders as `<p>﻿# Title</p>`. Setzkit preserves existing BOMs, so such files occur in practice. | Skip a leading BOM in block parsing while keeping source offsets unchanged; add a regression test. |

## Extensibility findings

The only extension point today is a custom leaf-block rule. It covers display
math and front matter, but not the rest of the 1.0 scope.

| Required feature | Needs | Possible today |
| --- | --- | --- |
| `$$` math blocks, front matter | Leaf block rule | yes |
| Footnote definitions | Container block with parsed children | no |
| Alerts, Obsidian callouts | Post-processing, splitting the first text node | no |
| Inline math, strikethrough, `==highlight==`, wikilinks | Inline triggers with delimiter-stack access | no |
| GFM tables | Access to the running paragraph's lines | no |
| GFM task lists | List item attributes | no |
| Syntax roles for extension syntax | Spans emitted by the extension | no |

| Priority | Finding | Recommendation |
| --- | --- | --- |
| High | **Two classes of syntax.** Built-in constructs are hard-wired in the main loop; extension rules run on a side path before them. Custom leaf rules can already shadow some starts, such as ATX headings. Profiles still cannot explicitly disable or order built-in rules, and the API cannot replace their container/paragraph continuation behavior. | Define shared rule identities, configuration and phase ordering for built-ins and extensions before M2. Keep optimised built-in dispatch where useful; a shared registry need not turn every core operation into a public closure. Measure dispatch costs and preserve CommonMark precedence. |
| High | **Inline extension API undefined.** M2 will implement the delimiter stack; extensions for `$`, `~~`, `==` and `[[` need access to it. | Design the inline rule API before implementing the inline parser and implement core inlines through it. Sketch alerts, footnotes and inline math against the draft API as acceptance checks. |
| Medium | **An extension is not one unit.** Parser rules and renderer hooks are registered separately and linked only by strings. | Declare an extension's identifier, version, node kinds and option schema in one descriptor in `SetzerSyntax`; parser and renderer parts stay in their modules, preserving the dependency rules. |
| Medium | **No namespace ownership.** Two extensions can emit the same custom kind; rule identifiers are unique only within one extension. | Require custom kinds and rule identifiers to start with the extension identifier; report violations as configuration errors. |
| Medium | **Options are not validated.** A misspelled option has no effect and no diagnostic. Setzkit requires unknown rules and options to be reported. | Validate options against the declared schema when the parser is configured. |
| Medium | **Extensions cannot report diagnostics or produce children.** `BlockMatch` yields exactly one childless node; parsed Markdown content can only be carried as attribute strings. | Extend the match result with child content ranges parsed by the core, and a diagnostic channel for extensions. |
| Medium | **Renderer hooks lose context (confirmed).** A `.list` hook returning `wrapChildren` turns a tight list into a loose one with `<p>` tags, because tightness is passed only through internal render events. | Preserve each built-in container's child-scheduling semantics when wrapping, and test hooks on each container, including tight/loose and nested lists. Evaluate an explicit hook context with node identity and tightness alongside the extension API; ancestor exposure is a separate design choice. |
| Low | **Unknown custom leaves inside containers render prefixes (confirmed).** A two-line custom leaf in a block quote renders `:::\n&gt; body`, because the renderer escapes the whole node range instead of its source segments. | Define a projected fallback literal that preserves line boundaries and partial-tab semantics while removing container prefixes. Simply concatenating content segments loses line endings when they are excluded from those segments. Retain exact original-byte provenance independently. |
| Note | **Trust model fits Setzkit.** Setzkit plans compiled-in, typed catalogs and no third-party runtime plugins. GMSetzer needs a good compiled Swift API, not sandboxing or runtime budgets. | Keep callbacks documented as trusted code. |

## Code findings

| Priority | Finding | Recommendation |
| --- | --- | --- |
| Medium | `BlockParser.parse()` in `ContainerParsing.swift` is a 160-line loop with state flags, `continue` jumps and force-unwrapped `leaf!`. | Split it into the cmark phases before M2: match open containers, continue the open leaf, open new containers, start a leaf. |
| Low | ASCII bytes appear as decimal literals (`35`, `60`, `96`, …) throughout. | Use named constants such as `UInt8(ascii: "#")` in one `ASCII` namespace; this also helps extension authors. |
| Low | Punctuation classification and NUL replacement are duplicated between `BlockParser` and `ReferenceScanner`; array literals are used for membership tests in hot paths. | Share small byte-classification helpers. |
| Low | The renderer re-scans HTML block literals to remove comments. | Let the parser record comment ranges once. |
| Low | `SourceRange.init` traps on invalid bounds, so an extension constructing a bad range crashes the host. | Document the precondition for extension authors, or offer a failable initializer. |

## Quality assurance findings

Strengths: the per-ID baseline, revision-pinned and checksum-verified spec
sources, cmark reference comparison over almost 2,000 documents, and tests for
invalid extension results are above the usual standard at this stage.

| Priority | Finding | Recommendation |
| --- | --- | --- |
| High | Short adversarial-input tests exist, but no fuzzing, pathological suite with process timeouts or performance gate is established. The performance risk is not detected automatically. | Add bounded pathological fixtures and an explicit local measurement gate before M2. Establish a reproducible baseline before choosing a regression threshold; keep noisy wall-clock thresholds out of ordinary unit tests. |
| Medium | Neither Linux nor the minimum Swift 6.2 toolchain has been built (open questions in the plan). | Verify both before the inline phase adds more code at risk. |
| Medium | All three confirmed defects sit in feature combinations: hooks with lists, extension nodes in containers, BOM with block starts. | Add combination tests per extension point and container kind. |
| Low | No invariant tests relate decoded literals to their source segments. | Define the per-kind projection/decoding contract and check it over the spec examples. Raw concatenation is insufficient: partial-tab expansion, line-ending normalisation, NUL/invalid-byte replacement and later entity/escape decoding intentionally change literals. |

## Process and documentation

- PRs #2 and #3 are merged, but the local `main` was stale and branch cleanup
  had not run when this review started.
- Setzkit's `Setzkit-Markdown-Parser.md` still lists PR #2 as open, uses the
  old working target names and cites 670 instead of 672 GFM examples.
- Status lines are repeated in README, Plan, SyntaxTree and the Setzkit
  document and are already drifting. The README module table lists outline
  queries and position conversion as module contents although both are planned.

## Follow-up repository assessment

The assessment on `docs/review-m1` (`12a34b3` before these documentation
corrections) checked the findings against the implementation. It changes no
library code and does not start M2. The existing uncommitted workflow-skill
changes remain outside the review commit.

### Verified evidence

- `swift test --disable-sandbox` with scratch/cache/config/security paths
  under `/private/tmp` passes all **49 Swift Testing tests** (44 parser/tree
  tests and five specification-harness tests). The protected exact-HTML
  baselines remain **339/652 CommonMark** and **339/672 GFM**.
- `swift test --package-path Tools --disable-sandbox --filter
  ContainerReferenceTests` with the same redirected compiler/package caches
  passes both reference tests: **1,985 exact-HTML** and **1,924 block-structure/
  literal** comparisons, **3,909** in total, against pinned cmark.
- A separate scratch executable reproduces the leading-BOM heading, the
  tight-list wrapper and the quoted two-line custom-leaf fallback defects. It
  also confirms that a custom leaf rule can shadow an ATX heading start.
  These are reproduction checks of existing behavior, not regression fixes.
- The pinned C source explicitly skips a leading UTF-8 BOM in `blocks.c`;
  GMSetzer's line scanning does not. A correction must preserve the original
  bytes, shift first-line syntax/content offsets by three bytes and leave any
  later U+FEFF intact.
- No release timings were repeated, no full benchmark or fuzzing run was
  performed, and Linux/minimum-Swift builds remain unverified. The informal
  timing table above is the original review evidence only.
- The follow-up also verifies PRs #2/#3 as merged and both local/remote feature
  tips as fully contained in `origin/main`. Those two feature branches were
  removed locally and remotely, with remote deletion protected by tip leases.
  Local `main` was advanced to `7d4c8a5`; the review branch and uncommitted
  workflow changes were retained. No additional worktrees existed.

### Technical disposition

These are implementation recommendations from the assessment, not new owner
decisions or claims that the APIs already exist.

| Area | Disposition before M2 |
| --- | --- |
| Validation and speed | Keep validation in public `Document`/builder construction in release. Measure the corrected C comparison and GMSetzer with annotations off/on. Attribute validation separately; try a dense visited buffer before a trusted fast path. Parent/token storage and lazy literals need allocation evidence, not an assumed saving. |
| Registry and extension unit | Resolve a reusable configuration once, with reserved core IDs, deterministic phase/order rules, namespaced custom kinds/rules, an option schema and configuration issues separate from document findings. Put portable descriptors in `SetzerSyntax`; parser callbacks stay in `SetzerParser`, renderer hooks in `SetzerHTML`. Explicit failure/fallback policy must preserve the editor's ability to parse. |
| Inline API | Draft controlled trigger/delimiter operations, precedence and progress/range validation before implementing core inlines through the same dispatch model. Do not expose mutable stack storage. Check delimiter runs, escapes, code-span exclusion, links, and extension interactions. |
| Container and transform API | Specify enter/continue/finish, projected child input, diagnostics and transforms before/after inlines. Prove with small executable prototypes: footnote definitions contain Markdown children; alerts remove only their marker before inline parsing; math retains raw TeX and exact delimiters without inline reinterpretation. This is API validation, not delivery of all M4/M5 features. |
| Optional syntax table | Use one document-level opt-in token/span model with semantic role, owning node index and original-byte range. Support multiple component segments, overlaps where justified, zero-length locations and extension roles. Disabled collection must avoid per-token storage; migrate `ReferenceSyntax` deliberately rather than retaining duplicate annotation stores. |
| Parent and position access | Decide eager versus optional parent storage with node-count/memory measurements. Keep identities document-local. Specify offset boundaries, nested/empty nodes and ownership separately; full queries and UTF-16 conversion retain their M3 gate. |
| Renderer and parser structure | Fix hook child context and projected leaf fallback first. Then split block processing into container matching, leaf continuation, container opening and leaf starts, preserving lazy continuation, depth limits and extension boundaries. |
| Robustness and portability | Extend combination tests and bounded hostile-input checks now. Preserve the named Linux/Swift 6.2 evidence gaps; if the toolchains are unavailable, record the gap and an explicit gate decision rather than claiming support was tested. |

### Recommended work packages and gates

1. **M1-A: correctness.** Fix the three reproduced defects with failing-then-
   passing regression cases. Cover hooks on built-in containers, custom leaves
   in quotes/lists, BOM with block starts, mixed line endings and exact offsets.
   Retain all protected IDs and the reference comparisons.
2. **M1-B: measurements.** Record a comparable release baseline using the
   corrected harness (same actual byte counts, machine, core/GFM mode and
   source-position settings). Separate parse, validation, optional annotations
   and rendering; account for the incomplete GFM implementation. Define phase
   headroom and a local regression gate from those results. Full benchmark
   runs still require owner authorization; this review does not grant it.
3. **M1-C: architecture proof.** Write and test the shared configuration,
   inline/container/transform contracts against alerts, footnotes and math.
   Settle optional token storage and parent-index ownership, retaining exact
   snapshot ranges and module boundaries. Measure overhead before accepting
   a broader registry or tree-storage change.
4. **M1-D: refactor and acceptance.** Decompose the block loop after the
   combination tests are in place. Review `try!` sites and byte helpers,
   enforce bounded pathological cases, and obtain or explicitly resolve the
   missing portability evidence. Re-run the suite and pinned comparisons.

**M2 remains blocked on the acceptance of these work packages.** Implement only
the proven extension/token infrastructure needed by M2; actual GFM, footnotes,
math, editor diagnostics, parent queries and Setzkit underlines keep their
documented delivery milestones. Completion of this assessment alone does not
complete M1 or establish a speed guarantee.

## M1-A implementation follow-up

Implemented in PR #4, merged into `main` at `51efee6`, after the assessment
above. This step does not start M2; the subsequent M1-B result is recorded below.

- **BOM:** skip exactly one UTF-8 BOM at byte zero for first-line recognition,
  retaining the original bytes/root range and physical-line provenance. Reset
  indentation columns after the BOM. Preserve later U+FEFF and partial byte
  sequences; reference component ranges retain the three-byte offset.
- **Wrappers:** use the same list/item child scheduling for built-in rendering
  and `wrapChildren`, preserving tight/loose semantics and nested container
  boundaries. Hooks continue to own wrapper markup and whitespace. No new
  public hook context is introduced in this correction.
- **Custom leaves:** retain a projected plain-text fallback separately in
  `Document.customLeafFallbacks`, keyed by document-local node index. Include
  delimiters and original line boundaries, remove ancestor prefixes, expand
  residual tab spaces, replacement-decode invalid bytes/NUL and normalise CRLF/
  CR to LF. A missing final line ending remains absent. Semantic source
  segments and original bytes stay intact; simply joining them is not used.
  The sparse table leaves `Node`/`NodeData` unchanged and is empty for built-in
  parses. Release validation rejects dangling, built-in or non-leaf owners.
  Builder `finish` replaces/clears fallback metadata. Hand-built custom leaves
  without it retain their prior escaped raw-range fallback.

Validation with Swift 6.4.2:

- Six initial combination test functions reproduced the defects before the
  fixes and passed afterwards. Two more exercise fallback metadata validation,
  builder snapshot independence and the hand-built-tree compatibility path.
- All **57 library tests** pass (52 parser/tree tests plus five spec-harness
  tests); protected baselines remain **339/652** CommonMark and **339/672** GFM.
- Three Tools tests pass: the original **3,909** cmark comparisons plus **ten
  leading-BOM combinations**, **3,919** in total. They cover BOM-only, mixed
  line endings, headings, quotes, lists, tab indentation, code, HTML, references
  and a second BOM retained as text.
- The eight combination test functions also pass in an optimised release
  build (`swift test -c release -debug-info-format none --filter
  M1CombinationTests`, with redirected caches/scratch and `--disable-sandbox`).
  Fallback metadata validation remains active in that configuration. Debug
  symbols were disabled because sandboxed `dsymutil` could not create dSYMs.
- No full benchmark, Linux/minimum-Swift build, fuzzing or Setzkit editor/device
  check ran. No new performance or editor-integration claim follows from this
  correctness result. M1-B remains the next measurement gate.

After the merge, PR #5 was retargeted to `main`. The verified merged correction
branch was removed locally/remotely and its clean worktree removed. The primary
review worktree remains intact with its uncommitted workflow-skill changes.

## M1-B instrumentation follow-up

Prepared separately on `perf/m1-measurement-gate`. The original mixed corpus is
unchanged; a second reference-heavy corpus exercises actual optional reference
spans. Tests check collection off/on and unchanged rendering at all three sizes.
The 30 benchmark cases cover corresponding C core/GFM parses, the contextual
swift-markdown parse, isolated validation/rendering and reference annotation
costs, with actual byte counts/corpus tags and allocation counts/bytes.

The corpus test passes all three size cases, and `swift package benchmark list`
builds the release executable and lists all 30 tagged cases. These checks do
not execute the measured iterations or supply timing evidence.

[M1Measurements.md](M1Measurements.md) defines the receipt, comparison caveats
and local acceptance gate. No full measurement run or numeric phase/regression
budget was claimed by preparing this harness. The measured follow-up below
records the subsequent authorised result.

### Checked validation optimisation

The first authorised full run at `a345fea` finds about 42 ms for the 1 MB mixed
block parse against 19 ms for the corresponding C core parse. Isolated public
tree validation takes about 18 ms and 133 K allocations (rounded tool output).
The per-node temporary optional-index/`compactMap` arrays are avoidable.

Replace those arrays with direct optional-index bounds checks, and the hashed
visited set with a dense Boolean buffer over the already bounds-checked node
indices. Preserve traversal/error order, repeated-node, unreachable-node and
all payload/segment/fallback checks in release. All 57 library tests pass in
both debug and release after this change. The matching full countermeasurement
completed at clean commit `fbc2081`, using the unchanged benchmark operations
with microsecond display units. All 30 cases complete. The 1 MB core parse
falls to **26.755 ms** against **18.989 ms** for C; validation falls to
**3.025 ms and 3 allocations**. The C controls remain stable.

All six current size/profile budgets pass. Core total ceilings are
3.450 / 37.978 / 189.530 ms, leaving 0.724 / 11.223 / 48.628 ms from the block
baseline. This headroom is required for future inline work; it is not a claim
of completed inline/GFM performance. Reference syntax collection adds about
25.5% on the focused 1 MB corpus; general inline annotations remain unmeasured.
See [Benchmarks.md](Benchmarks.md#m1-b-measured-baseline-and-checked-validation)
for raw exports, receipts, allocation metrics and phase timings.

M1-B now supplies a measured baseline and a local executable gate with an
explicit provisional 10% same-workload regression alert. It detects the three
pre-change core violations, checks matching input sizes/corpus identities and
rejects missing/invalid measurements. Eight offline Python tests pass; all 57
library tests pass in debug/release, and all four Tools tests pass (including
3,919 C comparisons). M1-C extension/storage proof and M1-D final acceptance
remain open. Linux, the minimum toolchain, completed inline/GFM and iPhone
performance are not established here.

## Post-merge sequence and cleanup

M1-B is merged as PR #5 (`7c0f4ea`). Setzkit's documentation correction is
merged as its PR #22 (`39e5fd0`). After verifying both local and remote tips
against current `main` and excluding open dependent PRs, remove the completed
`perf/m1-measurement-gate`, `docs/review-m1` and Setzkit's
`docs/gmsetzer-merge-status` branches. The clean benchmark worktree is removed.
The previously uncommitted workflow files are preserved together in commit
`0abbe1b` on `chore/project-skills`; no work is discarded.

The owner revised the remaining sequence: portability checks first; decompose
the block loop at the beginning of M1-C so registry work does not require a
second refactor; then prove the APIs/storage choices with a numeric inline
budget, followed by the remaining M1-D acceptance. Current total headroom is
0.724 ms at 100 KB and 11.223 ms at 1 MB. It covers all future parse costs;
measure text-string/segment overhead before assigning an inline allowance.
Linux/Swift 6.2 evidence, API proofs and M1 acceptance remain open.
