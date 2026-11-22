# GMSetzer – Plan and Requirements

**Status: 22 November 2026, M1–M6 merged and accepted under their declared
library gates. PR #24 (`a8a0351`) adds progressive HTML on `main`; the latest
published source-only preview is v0.6.0. PR #26 (`a273810`) merges the M7
performance/hardening candidate; explicit milestone acceptance and a 0.7
release remain separate. API/DocC/1.0 completion stays M8.** This document is the
reference for everyone working on GMSetzer. It records what the library must
do, why it exists, how it is built and in which order. It is self-contained:
no knowledge of earlier discussions is needed.

**Version boundary, 21 November 2026:** [PR #25](https://github.com/kerker00/GMSetzer/pull/25)
merged at `8ff206178bb07664e89fdc6a119da039fadcd581`, published as the
source-only [v0.6.0](https://github.com/kerker00/GMSetzer/releases/tag/v0.6.0)
preview. Tagged macOS/Linux Swift 6.2 CI, both source archives and an independent
public-HTTPS exact-version consumer pass; see [release validation](Validation/Release/0.6.0.md).
The release excludes all M7 commits. This `feature/m7-hardening` branch uses
`0.7.0-dev.1` and retains its mutation tests, benchmark evidence and parser
optimization. Main is integrated without rewriting that recorded commit
history. Existing measurements keep their original identities/hashes; this
integration changes no M7 parser/rendering code, tests, scripts or workflow.
M8 remains the API/DocC/1.0 stage.

**M7 local scaling baseline, 22 November 2026:** the separate
[69-case real-M5/hostile-input matrix](M7HardeningWorkloads.md) completes on
macOS/Swift 6.4.2 at clean `2f5f1bd`, in 326 seconds. The
[full report](Validation/M7/hardening-scaling-2026-11-22.md) records approximately
proportional timing over 16/64/256 KiB and concrete token/buffer/malformed-byte
profiling priorities. All source/executable/allocator hashes are unchanged;
the preparation's 10 Release tool tests / 5 suites and 36 Python tests per
mode remain the unchanged harness's functional evidence. Existing library
sources, fixtures, pins and 72-case budgets are unchanged. New-harness Linux/
minimum-compiler, fresh resource and broader fuzz validation remain pending;
this local checkpoint is not merged or accepted M7.

**M7 token allocation optimization, 22 November 2026:** the subsequent
[three-file candidate](Validation/M7/token-arena-2026-11-22.md) reduces the
focused deep-emphasis syntax-on time by 75–77% and requests per parse from
262,219 to 94. All 247 library tests pass in Debug/Release on macOS and native
Linux ARM64; 10 Mac Release tool tests, 36 Python tests per mode and exact
old/new token-table equality across all 1,324 specification examples pass.
Thirty-case before/after subsets retain six C/absolute and nine frozen-M2
passes unchanged. Gross traffic falls about 5.7% in the profiled case, with
no peak-memory claim. Full refresh, minimum Swift 6.2/current x64 and fresh
progressive resource evidence remain open. Large bracket buffers and the
malformed-byte path are next; the earlier full 69-case baseline keeps its
pre-optimization identity.

**M7 inline buffers, 22 November 2026:** the subsequent
[three-file candidate](Validation/M7/inline-capacity-2026-11-22.md) compacts
internal links/brackets and reserves known inline-emission batches with
geometric growth. The 256 KiB bracket case requests **174.19 M → 119.82 M
bytes (31.21% less)**, with timing broadly maintained and no peak-RSS claim.
Current **249 library tests** pass in Debug/Release on macOS/Linux ARM64,
10 Mac tool tests and all six C/absolute plus nine M2 checks pass. Independent
snapshots match all 1,324 examples, including 7,994 public nodes and 4,422
tokens. Next is malformed-byte processing with an explicit validation-enabled
C control. Minimum compiler/current x64, fresh full-resource/benchmark and
broader fuzz evidence remain pending; M7 is not accepted or merged.

**M7 UTF-8 follow-up, 22 November 2026:** the
[one-runtime-file candidate](Validation/M7/utf8-2026-11-22.md) reuses an already
validated canonical plain paragraph. Separate 36-case UTF-8 controls select
C validation explicitly and retain the legacy replacement-policy difference.
At compatible malformed 256 KiB, Mac time is **12.812 → 10.297 ms (−19.63%)**,
gross requested bytes fall **53.05%**, and validating C takes 5.251 ms (1.96×).
All 252 Mac Debug/Release/AddressSanitizer tests, 12 Release tool tests and
8,192 bounded ASan stress parses pass; all 1,324 public spec snapshots match.
This ASan mutation run is not coverage-guided fuzzing. The later
[current x64/resource/minimum-compiler checks](Validation/M7/final-x64-2026-11-22.md)
pass, and a separate [coverage-guided campaign](Validation/M7/fuzz-2026-11-22.md)
completes 3,510 units without failure. The [candidate](M7Readiness.md) merged
in [PR #26](https://github.com/kerker00/GMSetzer/pull/26) at `a273810` on
22 November 2026. Explicit milestone acceptance and source-only 0.7 release
preparation/publication remain separate.

**Owner-approved follow-up, 22 November 2026:** the documentation/scanning
experiment merged in [PR #27](https://github.com/kerker00/GMSetzer/pull/27) at
`6372cfc`, keeping the reviewed M7 runtime intact. The README now leads with a small
GFM example, published-release links and an explicitly unreleased-candidate
benchmark table; historical checkpoints move to [Status](Status.md) and the
reference index to [Documentation](README.md). A separate
[scan probe](../Tools/ScanProbe/README.md) compares scalar buffer/Span, current
word8, the same algorithm with RawSpan, and SIMD16/32. The
[results](Validation/M7/scan-evaluation-2026-11-22.md) identify mixed gains and
regressions; no experimental strategy is promoted into production.
Next, measure remaining intermediate copies and HTML byte-buffer output.
Token interning/struct-of-arrays remains profile-driven. M8's API review now
explicitly includes a small safe-HTML facade and shared parser/renderer
configuration for selected extensions. Input streaming requires a separate
design: later definitions, list finalisation, full-document ownership and
fallback/restriction semantics must be specified before implementation.

**HTML-copy candidate, 22 November 2026:** allocation profiling leads to one
runtime-file change, reusing local child-index storage and preserving existing
plain Strings when escaping is unnecessary. The
[report](Validation/M7/html-copies-2026-11-22.md) records **79.26% fewer requests /
54.15% less gross byte traffic** for 1 MB rendering, with isolated pre-parsed
render time about halved on M2 and 34–37% lower on x64. Composed M5 pipeline
results remain mixed/small; no parser or general peak-memory improvement is
claimed. All 253 Mac/x64 Debug/Release tests, 12 tool tests per host and 253 Mac
ASan tests pass, plus 1,024 bounded ASan mutation inputs / 8,192 parses. Fresh
source-matched progressive resources pass all 42 cases / 126 checks, verifying
43 runtime / 5 measurement-tool hashes. Minimum Swift 6.2 candidate CI remains
pending; the candidate is not merged or released.

The M4 follow-ups are merged in PR #15 (`1473d49`). The source-only v0.4.0
release preparation and macOS/Linux CI are merged in PR #16 (`6a0eb8e`);
their merged branches are cleaned up.
[v0.4.0](https://github.com/kerker00/GMSetzer/releases/tag/v0.4.0) is published
on 20 November 2026 at `50991b3`, with only GitHub's source archives. Release
CI passes on macOS/Swift 6.2.3 and Linux/Swift 6.2, and a separate SwiftPM
consumer resolves and uses the remote version successfully.
The owner has made the repository public; anonymous HTTPS access to the
v0.4.0 tag was verified on 20 November 2026.
See [Releasing](Releasing.md) for the process and the
[preparation checks](Validation/Release/0.4.0.md) for executed evidence.

**Merged after v0.4.0:** PR #17 (`0434ff5`) adds an optional English/German
native finding/fix text catalogue, structured heading-level arguments and
explicit fallback behavior. Its merged branch is removed locally and remotely.
Local validation is complete (123 tests on macOS/Swift 6.4.2, macOS/Swift 6.2
and Linux/Swift 6.4.2; both host release builds pass). The subsequent merged-main
CI passes on macOS/Swift 6.2.3 and Linux/Swift 6.2. Consumer
presentation adoption and a versioned release remain separate. See
[NativeAnalysisMessages](NativeAnalysisMessages.md).

**Merged toward 0.5:** PR #18 (`4397819`) adds opt-in
original quote/list marker ranges, including explicit continuation prefixes,
item ownership and accepted multi-line extension boundaries. The semantic
parse and HTML remain unchanged. See [ContainerMarkers](ContainerMarkers.md).
M5's additional syntax remains separate and unimplemented by this step.
Local validation passes all 135 tests on macOS/Swift 6.4.2, macOS/Swift 6.2 and
Linux/Swift 6.4.2, plus both host release builds. Annotation on/off preserves
all 1,324 specification trees and exact HTML. PR CI and merged-main CI pass
on macOS and Linux, including the minimum Linux Swift 6.2 compiler. The merged branch is removed locally and remotely; no new release or benchmark series
was run.

**M5 in progress:** merged PR #19 (`4b0f105`) adds opt-in raw YAML/TOML
metadata through the existing extension API and an explicit original-document
start signal for block rules. Strict CommonMark/GFM selections are unchanged.
This first step does not implement footnotes, math, alerts or callouts. See
[FrontMatter](FrontMatter.md) for the grammar, source and rendering contracts.
All 153 tests pass locally on macOS/Swift 6.4.2, macOS/Swift 6.2 and
Linux/Swift 6.4.2; both host release builds pass. Development identity is
`0.5.0-dev.1` at that step. PR and merged-main CI pass on macOS and Linux.
The merged branch is removed locally and remotely; no new release.

**Merged M5 step:** PR #20 (`a6a2da6`) implements opt-in named definitions
and references, exact tokens, reference-order numbering and composed HTML with
backlinks. Explicit continuation and protected bracket policies are documented
in [Footnotes](Footnotes.md). All 178 tests pass on macOS/Swift 6.4.2,
macOS/Swift 6.2 and Linux/Swift 6.4.2; both host release builds pass.
Development identity was `0.5.0-dev.2` at that step; PR CI passes on macOS and
Linux, including Linux/Swift 6.2. Merged-main CI also passes on both hosts. The merged branch
is removed locally and remotely; there are no additional worktrees to remove.
That step leaves math, alerts and callouts open; no new release is published.

**Merged M5 step:** PR #21 (`6f166b7`) recognises opaque inline `$…$`, display
`$$…$$` and `math` code fences through the existing extension API. Raw bytes,
projected TeX and exact syntax tokens remain available; the caller supplies
formula rendering. All 202 tests pass on macOS/Swift 6.4.2, macOS/Swift 6.2
and Linux/Swift 6.4.2; both host release builds pass. Development identity is
`0.5.0-dev.3` at that step; PR and merged-main CI pass on macOS and Linux. The
merged branch is removed locally and remotely; no additional worktrees existed.
See [Math](Math.md) for that step's declared grammar and validation limits.

**Merged M5 step:** PR #22 (`c9543fe`) adds optional
GitHub-style alerts and Obsidian-style callouts that retain parsed body/title
Markdown, folding metadata, exact header tokens and composed HTML. A new
quote-start context prevents header/setext/table ambiguity; rebuilding remaps
validated token owners without allowing foreign-token forgery/duplication.
All 227 tests pass on macOS/Swift 6.4.2, macOS/Swift 6.2 and Linux/Swift 6.4.2;
both host release builds pass. Development identity was `0.5.0-dev.4` at that step. PR and
merged-main CI pass on macOS and Linux, including 17 script tests per host.
The merged branch is removed locally and remotely; no additional worktrees
existed. [M5 functional acceptance](M5Acceptance.md) is complete against the
declared fixtures/profile/combination criteria. Release preparation and M6
remain separate; no tag or release is created. See [Admonitions](Admonitions.md).

**0.5.0 published:** [v0.5.0](https://github.com/kerker00/GMSetzer/releases/tag/v0.5.0)
is published on 20 November 2026 at `2d8ecef`, after owner confirmation,
successful tag validation, 227 Swift tests, 17 script tests and optimized
builds on both release CI hosts. All protected CommonMark/GFM examples pass.
An isolated public-HTTPS SwiftPM consumer resolves exact version 0.5.0 to the
same commit and exercises all M5 APIs. GitHub supplies ZIP/tar.gz archives;
there are zero uploaded build assets. The annotated tag remains unchanged.
See [release notes](Releases/0.5.0.md) and
[release validation](Validation/Release/0.5.0.md). Progressive HTML is now
merged and accepted under [M6](M6Acceptance.md); general measurements/
hardening remain M7, and consumer UI/device acceptance stays separate.

GMSetzer is an independent, general-purpose Markdown library intended for
open-source use under the MIT licence. Editors, command-line tools, servers
and extensions use the same public APIs. No particular application, checkout
or UI framework is required to build, test or release it.

## Contents

1. [Why GMSetzer exists](#why)
2. [Decisions](#decisions)
3. [Requirements](#requirements)
4. [Portable services for consumers](#consumer-services)
5. [Architecture](#architecture)
6. [Extensions and profiles](#extensions)
7. [Learning from other parsers](#learning)
8. [Building blocks from the Swift package ecosystem](#building-blocks)
9. [Testing](#testing)
10. [Milestones](#milestones)
11. [Repository rules](#repository)
12. [Risks](#risks)
13. [Open questions](#open)

<a id="why"></a>

## 1. Why GMSetzer exists

GMSetzer provides a parser designed to handle CommonMark, the complete GFM, footnotes,
front matter, inline and block math, and alerts and callouts. It must offer
switchable dialect profiles and exact source positions, run fast on an
iPhone and inside a Quick Look extension, and come under a permissive
licence. These candidates were considered; the limits of the available
evidence were checked in the M0 review on 19 November 2026:

| Candidate | Result |
| --- | --- |
| [swift-markdown](https://github.com/swiftlang/swift-markdown) (wraps cmark-gfm in C) | The locally pinned 0.9.0 parser attaches tables, strikethrough and task lists, but not extended autolinks. Its parse options do not expose independent GFM switches or custom inline syntax. Post-processing alone cannot recover math already parsed as emphasis; preprocessing would also need source mapping. |
| [micromark](https://github.com/micromark/micromark) / unified (JavaScript) | Extension ecosystem and positions are relevant. JavaScriptCore adds an engine and a bridge; no local iPhone measurement exists. Historical JIT slowdown reports are not a project benchmark. |
| [comrak](https://github.com/kivikakk/comrak) (Rust, BSD-2) | A relevant reference for the required extensions. Integration needs a Rust build and a Swift/C boundary; coverage counts have not been independently reproduced here. |
| [MarkdownKit by objecthub](https://github.com/objecthub/swift-markdownkit) (pure Swift, Apache-2.0) | Closest pure Swift parser: passes all 652 CommonMark examples according to its README and is extensible. Apple platforms only, no footnotes, no extended autolinks, no documented source positions. |
| Other Swift packages for GFM on Linux (swift-cmark, Swift-GFM, cmark-gfm wrappers) | All wrap cmark-gfm in C. |

**The gap in the evaluated candidates:** none has been demonstrated here to
meet all these requirements together. This supports the GMSetzer decision;
it is not an exhaustive claim about every available Swift package.

<a id="decisions"></a>

## 2. Decisions

All taken by the project owner on 19 November 2026.

| Decision | Reason / consequence |
| --- | --- |
| Write an own parser in pure Swift instead of using comrak, micromark or swift-markdown | Full control over extensions, positions and speed; no extra toolchain; reusable across independent applications |
| Learn from existing parsers as much as possible and do it better, faster and more complete | Algorithms and tests are taken over deliberately, under the licence rules in [section 7](#learning) |
| Own repository from the first line of code | The parser is independently buildable and testable from day one |
| Name **GMSetzer** | Family name with GMSnagNav; a *Setzer* is a typesetter. No collision found in a search |
| Repository initially private, public since 20 November 2026 | The owner made it public; future visibility changes remain owner-confirmed |
| MIT licence | Permissive, usable in commercial and open source apps |
| Linux supported | The core uses only the Swift standard library |
| No runtime dependencies in the library | Tool and test dependencies live in the separate package `Tools/` |
| Math is recognised, not rendered | The library stays free of JavaScript; the caller converts TeX through a renderer hook |

<a id="requirements"></a>

## 3. Requirements

### Functional

| Area | Version 1.0 | Later |
| --- | --- | --- |
| Core | CommonMark 0.31.2, all 652 examples | Later spec versions |
| GFM | Tables, task lists, strikethrough, extended autolinks and disallowed raw HTML (tag filtering); all 672 examples in the pinned GFM 0.29-derived cmark corpus, including the two task list examples marked `disabled` upstream | – |
| Further syntax | Footnotes; front matter (YAML/TOML at the start, delivered as raw text); math inline `$…$`, display `$$…$$` and ` ```math ` blocks; GitHub alerts `> [!NOTE]` (NOTE, TIP, IMPORTANT, WARNING, CAUTION); Obsidian callouts `> [!type]` with optional `+`/`-` folding marker and title | – |
| Profiles | Every extension switchable on its own; shipped profiles "CommonMark strict" and "GFM" | Obsidian (wikilinks, embeds `![[…]]`, `==highlight==`, tags), Pandoc (definition lists, attributes `{.class}`, fenced divs, sub-/superscript, citations `[@key]`), MultiMarkdown, kramdown, user-defined profiles |
| Output | Syntax tree with source ranges; HTML renderer with block anchors; opt-in progressive HTML from a complete document (M6) | Markdown serialiser (for converting between profiles), other output formats |
| Outline | Query for headings and block structure with their ranges | – |
| Editor syntax | Optional source-spelled syntax/delimiter spans and precisely located document diagnostics; UTF-16 mapping in the caller's snapshot | – |
| Native analysis | Optional `SetzerAnalysis` module over the same tree/source; configurable named rule subset, portable findings and explicit suggested fixes | Further rules and separately verified markdownlint compatibility |

### Non-functional

- **Pure Swift, no runtime dependencies.** The core uses the standard library
  only (Foundation at most in the HTML renderer, if at all). It runs in apps,
  app extensions such as Quick Look, command-line tools and on Linux.
- **Swift 6, strict concurrency.** Syntax tree and results are `Sendable`
  values; parsing works on any thread, there is no global mutable state.
- **Positions.** Every node carries its source range as UTF-8 byte offsets.
  A conversion helper gives lines, columns and UTF-16 offsets (what TextKit
  and `NSRange` use). Positions must be exact for every node kind, including
  extensions. Ranges are half-open `[lowerBound, upperBound)` in the original
  snapshot, including syntax delimiters for syntax nodes. A container range
  can include quote/list prefixes and line endings; it is not necessarily the
  decoded text rendered for that node. Non-contiguous content needs source
  segments. The conventions for tabs, CRLF, empty nodes and offsets inside
  scalars are defined in [SyntaxTree.md](SyntaxTree.md); conversion is implemented in M3 (see [M3EditorServices](M3EditorServices.md)).
- **Speed.** Measured with the benchmarks in `Tools/` (see
  [Benchmarks.md](Benchmarks.md)):

  | Size | Mac (Apple Silicon) | Oldest test iPhone |
  | --- | --- | --- |
  | 100 KB | < 10 ms | < 30 ms |
  | 1 MB | < 60 ms | < 200 ms |
  | 5 MB | < 300 ms | < 1 s |

  The stricter rule: **at most twice the time of cmark-gfm in C** on the same
  machine, document and corresponding core/GFM configuration, aiming for
  parity. Source positions must be enabled for both. The historical M0 C
  numbers (1.7 / 19 / 96 ms) used the core without source-position options;
  they do not establish the corrected comparison.
- **Robust.** Linear time even on hostile input (deep nesting, many open
  brackets, long runs of emphasis characters); limits for nesting depth; no
  crash on invalid UTF-8. The `String` input is already valid Unicode;
  `parse(bytes:)` now preserves original bytes while replacement-decoding
  literals, with tests for invalid sequences and NUL. Depth limits need a documented fallback
  and must bound rendering and traversal as well as parsing.
- **Safe by default.** The HTML renderer writes raw HTML from the source as
  escaped text unless the caller allows it; HTML comments are left out;
  dangerous URL schemes (`javascript:`, `vbscript:`, `data:`) are neutralised.
  Any image data URL exception needs an explicit raster MIME allowlist and
  applies only to image sources. Check schemes after escape/entity decoding,
  including ASCII controls and mixed case. Allowing raw HTML is explicit
  and does not by itself disable URL checks.

  Conformance tests need a separate explicit configuration: preserve raw HTML
  and comments, permit spec URL examples and disable block anchors. GFM tag
  filtering still applies with the GFM profile. These settings are for trusted
  fixtures; safe-default rendering has separate tests. Escaping source HTML
  does not sanitise HTML returned by a caller's renderer hook.

<a id="consumer-services"></a>

## 4. Portable services for consumers

The library exposes platform-neutral values and operations. Consumers choose
their own application architecture, revision model and presentation adapter.

| Need | Why |
| --- | --- |
| Exact UTF-16 ranges for every node | The editor (TextKit 2) highlights, folds and links syntax in `NSRange` terms |
| Block anchors in the HTML (source line or byte offset on block elements) | Scroll synchronisation between editor and preview |
| Planned block-oriented HTML output with source ranges and complete-document context | Consumers can show an initial section before all HTML is generated; scheduling, viewport choice and revision ownership stay outside the library (M6, section 10.1) |
| An outline query (headings and blocks with ranges and levels) | Folding, a breadcrumb of the current section and an outline overview all read the same model |
| Switchable extensions and named profiles | Consumers choose the effective dialect; changing the profile never changes the file |
| A renderer hook per node kind | Math becomes MathML through Temml, code blocks get syntax highlighting, Mermaid diagrams are rendered elsewhere |
| Speed on the iPhone and in a Quick Look extension | Large documents (up to 5 MB) must stay usable; Quick Look runs with tight limits and without JavaScript |
| `Sendable` results | Consumers associate background parse results with their own revision, dialect and configuration; GMSetzer does not import app-specific revision types |
| Safe HTML by default | Previews and exports never run active content from documents |
| Syntax roles and document findings | Theme-based highlighting and precise underline/caret/gutter locations in TextKit; preserve delimiters and original trivia |
| Native lint rules over the same parse | Optional checks reuse GMSetzer's dialect semantics and source, with provider/rule IDs, severity, related ranges and advisory fixes |

### Editor analysis is an explicit deliverable

The original position requirements were necessary but did not define complete
syntax-checking and lint services. The owner confirmed these uses on
19 November 2026. [EditorAnalysis.md](EditorAnalysis.md) now specifies them,
including source-spelled syntax spans, the optional analysis module,
revision-bound UTF-16 underlines, diagnostics versus parser/provider failures,
rule profiles and strict suggested-fix transactions.

The M3 native subset and portable position APIs are implemented. Application-specific UI and device acceptance belong to consumer repositories. `ParseDiagnostic` covers infrastructure
conditions, not a finished linter. CommonMark literal fallbacks are not syntax
errors by default. Markdownlint remains an optional compatibility/provider
path; equivalence is not assumed for native rules.

<a id="architecture"></a>

## 5. Architecture

### Independence boundary

Public APIs must remain consumer-neutral. The package has no reverse dependency
on an application, sibling checkout, editor implementation or UI framework.
Library targets use only the Swift standard library and other targets in this
package. Tests and tools may use their separately declared dependencies.

The API boundary consists of source bytes, immutable trees, portable positions,
syntax roles, diagnostics and advisory edits. Consumer session IDs, revision
counters, scheduling, localization, color/theme resolution, undo transactions
and platform rendering remain in adapters owned by the consuming repository.
Application-specific test reports and device acceptance belong there as well.
Library milestones and public API stability are evaluated independently of any
single consumer. Publication remains a separate owner-confirmed action.

### Modules

| Module | Contents | Depends on |
| --- | --- | --- |
| `SetzerSyntax` | Syntax tree (node kinds, source ranges), position conversion, outline query, visitors | – |
| `SetzerParser` | Block and inline parser, extension API, profiles | `SetzerSyntax` |
| `SetzerExtensions` | GFM, footnotes, front matter, math, alerts and callouts | `SetzerParser`, `SetzerSyntax` |
| `SetzerHTML` | HTML renderer, block anchors, escaping and URL checks, renderer hooks | `SetzerSyntax` |
| `SetzerAnalysis` | Optional native rules over existing tree/source; portable findings and suggested edits | `SetzerSyntax` |
| `GMSetzer` | Re-exports all of the above | all |

Portable syntax-span/diagnostic/fix values belong in `SetzerSyntax`.
`SetzerAnalysis` implements the three opt-in native rules in [M3EditorServices](M3EditorServices.md). The parser remains independent of analysis and HTML.

### Approach

- **Input as UTF-8 bytes**, not as `String` characters. Parsing works on one
  contiguous byte buffer with integer indices, as cmark does. This is what
  supports efficient parsing and exact positions. Start with `[UInt8]` and
  bounded buffer access. `Span`/`UTF8Span` are candidates, not prerequisites;
  availability must be checked against the chosen deployment targets.
- **Two phases as in the CommonMark spec** (appendix "A parsing strategy"):
  first the block structure line by line, with open containers and lazy
  continuation; then the inlines of each leaf block with the delimiter stack
  for emphasis, links and images.
- **Link reference definitions** are collected in the block phase and resolved
  in the inline phase. Label matching needs Unicode case folding (see
  [section 8](#building-blocks)).
- **Flat value tree.** All nodes live in one array; children and siblings are
  indices (`Document.nodes`, see `Sources/SetzerSyntax/Document.swift`). Fast,
  little memory, `Sendable`. A convenient tree API sits on top.
- **Node kinds** derive from typed built-in payloads. Extensions register their
  own namespaced kinds and portable attributes without a fork. Add built-in
  payload cases with their parser implementation.
- **M1 model contract:** the initial payloads, source segments, cross-module
  builder and iterative range/tree validation are implemented in
  [SyntaxTree.md](SyntaxTree.md). List start/delimiter/tightness, built-in
  container continuation and depth limits are now included. Custom containers and CommonMark inline payloads are implemented; see
  [M2Inlines.md](M2Inlines.md) for the current inline and annotation contract.
- **Incremental parsing** (re-parsing only changed top-level blocks) comes
  later and only if measurements show the need.

<a id="extensions"></a>

## 6. Extensions and profiles

An extension can register:

- **block starts** (for example `$$`, front matter at the start, footnote
  definitions `[^1]:`),
- **inline triggers** for a character (`$`, `~`, `[^`, `==`, `[[`), with access
  to the delimiter stack where needed,
- **post-processing** of the tree (alerts and callouts from block quotes,
  footnote numbering),
- **renderer hooks** for its node kinds.

A **profile** is a named list of active extensions with their options.
comrak's per-extension options are a good model for the switches.

`Profile` now stores ordered extension selections and portable options;
implementations are supplied separately to the parser. The initial registry
supports custom leaf-block rules, deterministic priority and checked progress
and ranges. Unavailable extensions and invalid matches produce diagnostics.
Leaf rules receive projected lines and cannot consume past a container boundary.
Custom containers, inline triggers and pre/post-inline transforms are implemented.
Built-in escape/code/ordinary link entry points remain protected from custom
triggers. The footnote step adds explicit opt-in complete bracket matches and
once-per-snapshot inline-rule preparation; see [Footnotes](Footnotes.md).
The detailed contract
and callback trust boundary are in [SyntaxTree.md](SyntaxTree.md). Renderer
hooks stay in `SetzerHTML`, without a parser-to-renderer dependency.

Math: the library produces nodes with the TeX source and nothing else. The
[math step](Math.md), merged in PR #21 and shipped in 0.5.0, implements three independently switchable
forms, exact provenance and caller-renderer hooks; no TeX engine is bundled.

<a id="learning"></a>

## 7. Learning from other parsers

GMSetzer reinvents nothing that others have solved. It takes over proven
algorithms, tests and API ideas deliberately and improves where Swift or the
requirements allow.

| Source | Licence | What we take |
| --- | --- | --- |
| [cmark](https://github.com/commonmark/cmark) / [cmark-gfm](https://github.com/github/cmark-gfm) | BSD-2 | Reference algorithms for blocks, the delimiter stack and link references; the pathological test cases; GFM extensions |
| [commonmark.js](https://github.com/commonmark/commonmark.js) | BSD-2 | A readable reference implementation of the same algorithms |
| [comrak](https://github.com/kivikakk/comrak) | BSD-2 | Behaviour and tests of extensions (footnotes, front matter, math, alerts, Obsidian callouts, wikilinks, definition lists); the per-extension option model |
| [micromark](https://github.com/micromark/micromark) | MIT | Tokeniser as a state machine with positions for every byte; design and tests of extensions (math, front matter, directives) |
| [md4c](https://github.com/mity/md4c) | MIT | A very fast C parser with callbacks: ideas for speed and memory |
| [pulldown-cmark](https://github.com/pulldown-cmark/pulldown-cmark) | MIT | Pull-parser design, byte ranges per event, performance work |
| [markdown-it](https://github.com/markdown-it/markdown-it) | MIT | Ergonomic plugin API, rule chains for blocks and inlines |
| [MarkdownKit (objecthub)](https://github.com/objecthub/swift-markdownkit) | Apache-2.0 | A pure Swift parser with full CommonMark coverage: Swift-specific solutions, protocols for custom blocks and inline fragments |

**Licence rules:**

- Ideas and algorithms may be taken freely.
- Code may only be taken over or ported from MIT, BSD or Apache-2.0 sources.
  The origin goes into the file header, the licence text into `NOTICE`.
- No code from GPL or LGPL sources, and no code without a recognisable
  licence.
- Test cases from other projects are taken over with attribution. The
  specification texts (CC-BY-SA 4.0) stay separate test data and never become
  part of the library.

**"Better" means concretely:** pure Swift without C or Rust; positions directly
in UTF-8 and UTF-16; extensions and profiles as a first-class Swift API instead
of fixed switches; `Sendable` results; outline and block anchors built in;
measured speed at most twice cmark-gfm, aiming for parity.

<a id="building-blocks"></a>

## 8. Building blocks from the Swift package ecosystem

The core has **no runtime dependency** and runs wherever Swift runs, including
Linux. Dependencies exist only for development, tests, benchmarks and
documentation, and they live in `Tools/` or in test targets.

| Task | Solution | Linux | Use |
| --- | --- | --- | --- |
| Unicode categories (punctuation and whitespace for the emphasis rules) | Standard library, `Unicode.Scalar.Properties` | yes | core |
| Fast byte access | Standard library, `[UInt8]`/buffer access initially; evaluate `Span`/`UTF8Span` availability before adoption | yes | core |
| HTML5 named character references (2,231) | Own table generated from the WHATWG list; [Kitura swift-html-entities](https://github.com/Kitura/swift-html-entities) (Apache-2.0) as test reference | yes | core (table), tests (package) |
| Unicode case folding for link labels | Missing in the standard library; own table generated from Unicode `CaseFolding.txt` (Unicode licence), as cmark does | yes | core (table) |
| Benchmarks | [package-benchmark](https://github.com/ordo-one/package-benchmark) (Apache-2.0): time and allocations | yes | `Tools/` |
| Tests | Swift Testing | yes | tests |
| Reference comparisons | [swift-cmark](https://github.com/swiftlang/swift-cmark) and swift-markdown (Apache-2.0) | yes | `Tools/` and test targets only |
| Documentation | swift-docc-plugin (Apache-2.0) | yes | development |
| Fuzzing | libFuzzer via `-sanitize=fuzzer` | yes; availability with the Xcode toolchain on macOS still to check | development, preferably on Linux |
| Evaluating YAML front matter | Yams (MIT) | yes | not in the core: the core delivers raw text, the caller parses it |
| TeX to MathML | No Swift package known | – | renderer hook at the caller |

Generated tables are produced by a script in `Scripts/` from the official
source files; source, version and licence go into the file header and into
`NOTICE`.

<a id="testing"></a>

## 9. Testing

- **Specification runs** (`Tests/SetzerSpecTests`): every example of CommonMark
  0.31.2 and all 672 examples of the pinned GFM-derived corpus, including task
  lists 279/280 even though upstream marks them `disabled`. `baseline.json`
  records the IDs of passing examples; losing any recorded example fails even
  if another starts passing. Add newly passing IDs in the same commit.
  Downloads are revision-pinned and SHA-256 checked; updating the corpus is
  a separate reviewed change. The protected comparison remains exact. A tested, optional comparison
  normaliser only removes generated void-tag slashes, retaining text, attributes,
  code and original raw HTML byte-for-byte; no whitespace collapse is permitted.
- **Version differences:** CommonMark 0.31.2 and the GFM 0.29-derived corpus
  are distinct targets. Classify conflicting inputs before M4; retain both
  original fixtures and use explicit profile-specific behaviour. Any proposed
  deviation needs a documented decision, never an implicit skipped example.
  M4 resolution: the GFM corpus runs per example with its own extension, as
  upstream does; GitHub's nested-strong output is a GFM rendering policy over
  the unchanged CommonMark tree (owner decision 2A). See [M4GFM](M4GFM.md).
- **Extensions:** test each switch independently, off/on and in combinations;
  own fixtures per extension, with comrak's and micromark's
  tests as references for expected behaviour (with attribution).
- **Positions:** ranges address the exact original snapshot, with tests for
  syntax versus decoded content, container prefixes, CRLF/CR/LF, tabs,
  entities and escapes. UTF-16 conversion is tested with umlauts, emoji,
  combining characters, CJK and right-to-left text.
- **Rendering:** conformance configuration is separate from safe defaults.
  Test escaping, comments, decoded/obfuscated URL schemes, GFM tag filtering,
  anchors and caller hook trust as part of the M3 library gate.
- **Editor analysis:** exact delimiter/finding ranges, native rule selection,
  legal literal fallbacks, source trivia, zero-length/related ranges and fix
  preconditions. Consumers test their own UI range conversion, stale-result
  rejection, IME/undo protection and accessible navigation in their repositories.
  Those application checks do not gate this library; see [EditorAnalysis.md](EditorAnalysis.md).
- **Reference comparisons:** a corpus of real documents is compared with
  cmark-gfm; every difference is explained.
- **Hostile input:** cmark's pathological cases with a time limit.
- **Fuzzing:** random and mutated input must never crash or exceed the time
  limit.
- **Benchmarks:** fixed documents (100 KB, 1 MB, 5 MB), recorded with commit,
  machine and OS in [Benchmarks.md](Benchmarks.md).

<a id="milestones"></a>

## 10. Milestones

Initial estimates in person days for an experienced developer; these are not
delivery commitments. Re-estimate after M1, especially renderer safety,
extension API and hardening work. Every milestone ends with a measurable result.

| Milestone | Contents | Done when | Estimate | Status |
| --- | --- | --- | --- | --- |
| M0 | Repository, package layout, specification run, benchmark setup, name and gap check | Starting point measured; harness reviewed, reference configurations corrected | 2–3 | **reviewed and corrected** (19 Nov 2026); new reference timings pending |
| M1 | Source/payload/builder and extension contracts; block parser: paragraphs, ATX/setext headings, thematic breaks, quotes, lists, indented/fenced code, HTML blocks, references; basic HTML renderer grows alongside blocks | Block AST/range tests cover all block sections; HTML-compatible subset passes. Examples needing inline parsing remain M2 work | 8–12 | **merged in PR #9 (`61fcb95`)**: M1-A merged in PR #4 (`51efee6`); M1-B measurements, checked validation optimisation and local budget gate implemented. At M1 acceptance, 70 library tests, 3,919 reference comparisons and 13 Python tests passed; its protected baselines were 339/652 CommonMark and 339/672 GFM. [M1Acceptance](M1Acceptance.md) records the M1-C contracts, M1-D audit, portability matrix and fixed M2 budget |
| M2 | Inline parser and opt-in delimiter spans; portable document-diagnostic/fix contract; complete CommonMark rendering and tested normalisation | 652/652 CommonMark with explicit conformance settings; editor source-span tests pass; publication only after owner confirmation | re-estimate | **merged in PR #11 (`021f110`)**: 652/652 exact CommonMark, 641/672 GFM; 96 Swift tests across macOS/Swift 6.2/release/Linux, 17 Python checks and 4,786 C comparisons pass. Final core and selected-rule cases pass both unchanged budget gates. See [M2Inlines](M2Inlines.md) |
| M3 | Safe HTML, anchors/hooks, position conversion, outline; optional native analysis with a named rule subset; portable syntax/finding APIs | Security/position/analysis tests and standalone package validation pass; application adapters remain outside this package | re-estimate | **merged in PR #12 (`651af17`)** after review corrections: exact position/outline queries, safe configurable URL scheme allowlist/anchors and three optional native rules. 106 library tests passed across macOS/debug/release/Swift 6.2/Linux; after the [review](Review-M3.md) corrections 108 pass on macOS (Swift 6.2/Linux not re-run) with byte-identical differential results. Index/analysis timings and optimisations: [Benchmarks](Benchmarks.md#m3-editor-services-20-november-2026). See [M3EditorServices](M3EditorServices.md) |
| M4 | GFM extensions including tag filtering; resolve version differences explicitly | 672/672 pinned GFM corpus, including task lists; independent extension switch tests pass | 4–6 | **merged in PR #14 (`e163e6f`)**: tables, task lists, strikethrough, extended autolinks and tag filter as built-in payloads (owner decision 1A); 672/672 GFM and 652/652 CommonMark; generated documents agree with cmark-gfm. Library and reference tests pass on macOS; GFM parses at 0.88× cmark-gfm and both budget checks pass. Swift 6.2/Linux not re-run. See [M4GFM](M4GFM.md) |
| M5 | Footnotes, front matter, math, alerts and callouts; profiles "CommonMark strict" and "GFM" | Declared extension fixtures and profile/combination tests pass | 5–8 | **first step merged in PR #19 (`4b0f105`)**: raw YAML/TOML front matter; 153 tests pass on both hosts and macOS/Swift 6.2. PR/main CI pass on both hosts. Named footnotes merged in PR #20 (`a6a2da6`), with 178 local tests passing on both hosts and macOS/Swift 6.2; PR and merged-main CI pass on macOS/Linux. Opaque inline/display/fenced TeX is merged in PR #21 (`6f166b7`), with 202 local tests passing on both hosts and macOS/Swift 6.2; PR and merged-main CI pass on both hosts. Alerts and callouts merged in PR #22 (`c9543fe`); all 227 local tests pass on both hosts and macOS/Swift 6.2, and PR/main CI pass on both hosts. **Functional M5 accepted** against the declared extension/profile/combination criterion; see [M5Acceptance](M5Acceptance.md). See [FrontMatter](FrontMatter.md), [Footnotes](Footnotes.md), [Math](Math.md) and [Admonitions](Admonitions.md) |
| M6 / 0.6 development | Progressive HTML: prepared complete-document context, structural groups and bounded/on-demand emission | Plan 10.1 gates pass | Accepted; no remaining implementation estimate | **merged in PR #24 (`a8a0351`) and accepted**: exact grouped/full output, explicit fallbacks, source/cancellation/M5 contracts, 42-case measurements with matching runtime hashes and reviewed budgets; merged-main macOS/Swift 6.2.3 and Linux/Swift 6.2 CI pass 242 Swift tests, optimized builds and 31 Python tests. See [M6Acceptance](M6Acceptance.md) |
| M7 | General speed and hardening: selected-extension measurements, optimisation, hostile input, fuzzing | Speed targets of section 3 met; robustness and allocation evidence recorded | previous 5–8; re-estimate after M6 | **candidate merged in [PR #26](https://github.com/kerker00/GMSetzer/pull/26) at `a273810`**; explicit milestone acceptance and the 0.7 release remain separate. [Readiness](M7Readiness.md) records 252-test Mac/x64 Debug/Release and minimum Swift 6.2 CI passes, 12 tool tests per native host, full 69/72-case refreshes with unchanged C/M2 gates, 36 explicit UTF-8 controls, 42 source-matched resource cases, Mac ASan and bounded mutation plus 3,510 coverage-guided x64 units. General C parity and further copying/output work remain aims. See [self-review](Review-M7.md) and [M7Hardening](M7Hardening.md) |
| M8 | Version 1.0: API review, DocC documentation, release | Independently usable versioned package with documented API and owner-confirmed publication | previous 3–5; re-estimate after M7 | **planned; former M7 moved back one milestone** |
| | **Original total before explicit editor-analysis scope** | | **38–59; re-estimate required** | |

After 1.0: further profiles (Obsidian, Pandoc), a Markdown serialiser for
profile conversions, incremental parsing if measurements call for it.

### 10.1 M6 progressive HTML for large documents

**Owner decision, 21 November 2026:** make progressive HTML the next milestone,
referred to as M6 / the 0.6 development stage. PR #24 (`a8a0351`) is now
merged and [accepted](M6Acceptance.md) against the declared gates. The
implementation is published in the source-only v0.6.0 preview. The previous M6 hardening scope becomes
M7; the previous M7 1.0 scope becomes M8. Version-tag publication remains a separate confirmed
step. Historical validation/release documents retain their original M6/M7
references; this section is authoritative for the new work order.

The goal is a shorter wait for the first useful section of a large document,
without changing Markdown meaning or requiring a complete HTML string before
any output can be consumed. First output latency, total completion time and
memory use are separate measurements. A latency improvement does not by itself
claim faster parsing or lower total cost.

#### Processing and library boundary

1. **Measure before selecting the optimisation.** Record parse time, document
   preparation, first HTML-group availability, complete HTML generation and
   allocation/peak-memory cost in an optimised library build. Consumers measure
   their own transfer, layout and first-visible-output stages separately. Start
   with the existing full-document renderer as the comparison baseline.
2. **Keep one complete semantic document.** Initially parse the full source,
   or reuse a matching immutable parse supplied by the caller. Prepare global
   reference/extension context once. Later definitions can affect earlier
   references; independent parses of arbitrary byte/line slices are outside M6.
   Full parsing remains part of first-output latency.
3. **Plan structural groups.** Expose ordered, snapshot-local descriptors for
   complete top-level blocks or groups of blocks, with original source ranges.
   Keep lists, tables, code fences and custom wrappers structurally valid.
   Descriptor identity is not a stable cross-edit identity. Concrete public API
   types are selected during design; existing full-string rendering remains
   supported.
4. **Render groups without materialising the full result first.** Support
   bounded consumption and requested groups against the same prepared document
   and rendering options. A consumer can request the visible group and nearby
   groups first, then assemble them in document order. Shared context must keep
   references, source anchors, list tightness, hooks, footnote numbering/backlinks
   and document-level appendices consistent. Appendices are emitted once in
   their documented position. If a composition cannot support independent group
   requests, expose a documented fallback rather than silently changing output.
5. **Bound obsolete work.** Define stopping between groups, cooperative
   cancellation/progress checkpoints and ownership of prepared results.
   Consumers must be able to avoid an unbounded queue of chunks. A stop during
   emission does not imply that synchronous full parsing was interrupted.

Keep the library independent of Foundation, UI frameworks, JavaScript and
application revision/session types. A caller associates each plan/result with
its own immutable snapshot and configuration. Viewport selection, transfer to a
web view, DOM insertion, scroll anchoring, caches shared by consumer features
and rejection of results from obsolete revisions belong to the consumer.
No particular application or consumer checkout is required for acceptance.

Very large individual blocks need an explicit policy: a single multi-megabyte
table or code block is not made small by top-level grouping. Start with a
correct indivisible-block fallback and report its latency/memory limits.
Subdividing such structures needs a separate validated contract. Full viewport
virtualisation, offscreen DOM eviction and incremental parsing are later
options, selected only after measurements justify their added complexity.

#### Implementation sequence and acceptance

First establish the baseline and the smallest correct prepared/group-output
API; then implement safe bounded emission and requested-group rendering.
Measure again before selecting further optimisation. Targeted correctness and
resource tests are part of M6; broad fuzzing, final speed budgets and general
hardening remain required in M7 before the stable API review in M8.

| Gate | Required evidence |
| --- | --- |
| Semantic equivalence | Assembling every group and any appendix in order is byte-identical to the existing full renderer under the same options, including conformance and safe-default modes. No protected CommonMark/GFM ID regresses. |
| Global context | Cross-group/forward link references, footnotes including repeated/cyclic references, front matter, math hooks and alert/callout combinations retain the existing complete-document behavior. |
| Order and identity | Requested groups can be associated with one prepared snapshot and reassembled deterministically; out-of-order requests do not change numbering or anchors. Document any hook/composition fallback. |
| Structure and positions | Every insertable group is structurally valid, preserves source ranges and document-order placement, and does not invent stable identities across document edits. |
| Safe output | Existing escaping, URL policy and caller-hook trust boundaries are identical for full and grouped output. |
| Resource behavior | First output does not depend on constructing the full HTML string; bounded consumption, stopping and superseded-work scenarios have targeted tests. Largest-block fallbacks are explicit. |
| Measurements | Compare 100 KB, 1 MB and 5 MB prose, many small blocks, GFM tables, long code blocks, multibyte text and selected M5 combinations. Record toolchain/host/options, first-group latency, full time and memory; set improvement targets after the baseline. No universal instant-display promise. |
| Portability and scope | Validate standalone behavior on macOS/Linux and the minimum supported Swift compiler; UI/device results are recorded by consumers, not used as a library API/release gate. |

#### Initial implementation checkpoint

`feature/m6-progressive-html` adds `HTMLRenderer.prepare`, immutable
`HTMLRenderPlan` / `HTMLRenderGroup`, requested-group output, bounded pull
consumption and throwing checkpoints. Built-in footnote/admonition composition
shares complete-document context; raw HTML, document hooks and uncertified
order-dependent hooks have explicit whole-document fallbacks. Existing
full-string output stays supported. At M6 acceptance the development identity
was `0.6.0-dev.1`; the separate M7 branch now uses `0.7.0-dev.1`.

The complete local macOS/Swift 6.4.2 Debug and Release suites and the
Linux ARM64/Swift 6.4.2 suite each pass 239 tests, including safe and
conformance grouped/full comparison over all 1,324 specification examples.
Both hosts pass 17 offline script tests; Linux's optimised build passes.
The [validation record](Validation/M6/initial-html-groups.md) records source
identity, toolchain installation and remaining coverage.
A bounded, three-sample macOS 1 MB Release probe establishes the first baseline.
The owner-authorised [Linux ARM64 follow-up](Validation/M6/linux-arm64-measurements.md)
now records 42 workload/size/annotation configurations, exact HTML equality,
eight-sample timing, fresh-process peak RSS and separate calling-thread gross
allocation requests. Mixed 1 MB/5 MB inputs reach first output in about half the
parse-plus-full-output time. A giant code block has no early-output benefit;
peak RSS is generally dominated by the preceding parse, and annotated M5 parsing
remains expensive. No universal latency or memory improvement is claimed.
[ProgressiveHTML](ProgressiveHTML.md) describes the API; the
[benchmark report](Benchmarks.md#m6-linux-arm64-workload-and-resource-matrix)
links raw data and limitations. The [review follow-up](Validation/M6/review-readiness.md)
adds explicit post-baseline latency/completion/RSS budgets and an offline
evidence checker; all 42 recorded cases pass with unchanged runtime sources.
All 242 tests and an optimised build pass on macOS/Swift 6.2, and all 31
Python tests pass locally in normal and optimised modes. The
[self-review](Review-M6.md) records tool/evidence corrections and expanded
cancellation tests; the 14 progressive tests pass in Swift 6.2 Release. [PR #24 CI](https://github.com/kerker00/GMSetzer/actions/runs/44926163013)
passes all 242 Swift tests, optimized builds and 31 Python tests on macOS and
Linux with Swift 6.2. The owner merged PR #24 at `a8a0351`, and merged-main
CI also passes on both hosts; [M6Acceptance](M6Acceptance.md) maps every declared gate to its evidence.
Consumer WebView proof and publication remain separate. The broader parser/C
and selected-extension hardening matrix stays M7.

Full benchmark/long-test series still require the existing execution approval.
The original total estimate above excludes this added scope and must be
revised before scheduling the remainder.

<a id="repository"></a>

## 11. Repository rules

- **Language:** code, comments, commit messages, pull requests and
  documentation in English.
- **Branches:** `main` is the only long-lived branch. Work happens on feature
  branches from `main`; pull requests target `main`. The owner merges.
- **Branch completion documentation:** always reconcile README, current status
  and affected documentation with `main`. The owner authorised descriptive
  documentation/skill corrections to be committed and pushed directly on
  `main` without another approval or docs PR (20 November 2026). Source,
  manifests, executable workflows, tags and releases are outside this exception.
- **Visibility:** public since the owner's decision on 20 November 2026.
  Future visibility changes, tags and releases require the owner's explicit
  confirmation before the step.
- **CI:** the owner authorised macOS/Linux CI and source-only release
  preparation on 20 November 2026; implementation is in `main` since PR #16
  (`6a0eb8e`). It runs Swift 6.2 tests, optimized builds and offline script
  tests; successful version-tag checks create a source-only
  release draft. See [Releasing](Releasing.md).
- **Versioning:** SemVer. Before 1.0 the API may change; afterwards only with a
  major version.
- **Every fix** comes with a regression test; crashes and hangs on hostile
  input have priority.
- **Licences** as in [section 7](#learning).

<a id="risks"></a>

## 12. Risks

| Risk | Countermeasure |
| --- | --- |
| The spec is hard in its corners (emphasis, lazy continuation, tabs, HTML blocks); effort grows | Spec run from M0 makes progress measurable; cmark, commonmark.js and comrak as references for the algorithms |
| Swift code ends up slower than C | Byte buffer instead of `String`, flat tree, measurements from M1 on; limit "at most twice cmark-gfm" |
| Hostile input blocks an app | Linear algorithms following the spec appendix, pathological tests, fuzzing, depth limits |
| Maintenance load | Clear scope for 1.0; profiles one at a time afterwards |
| Application-specific scope leaks into the library | Keep application adapters, UI, session identity and device acceptance in consumer repositories |
| Licence mistakes when taking over code | MIT/BSD/Apache-2.0 only, origin in file headers, `NOTICE` kept up to date; GPL/LGPL excluded |

<a id="open"></a>

## 13. Open questions

The block-loop decomposition has moved to the beginning of M1-C, before shared
registry dispatch; its implemented boundaries and verification are in
[BlockPhases.md](BlockPhases.md). The M1-D builder invariant/`try!` audit and technical acceptance are now recorded
in [M1Acceptance.md](M1Acceptance.md); no second decomposition is required.

1. **Minimum platform and Swift versions.** The manifest requires Swift tools
   6.2 and provisionally macOS 15, iOS 18 and visionOS 2. Swift 6.2 now builds
   all library modules for macOS and Linux ARM64; all 70 macOS tests pass with
   a compatible SDK/testing runtime. Compile probes confirm that `Span` and
   an unsafe-buffer bridge support macOS 15, while direct `Array.span` and
   `UTF8Span` require macOS 26. Minimum Apple OS runtime checks remain open;
   keep the byte-buffer path. See [Portability.md](Portability.md).
2. **Linux verification coverage.** The initial static ARM64 probe retains all
   protected IDs across 1,324 spec inputs plus targeted checks. The extracted
   current contracts pass all 70 tests on Linux x86-64/glibc with Swift 6.4.2 through
   an existing SSH host, and cross-build for static ARM64 with Swift 6.2.
   A full Linux suite on Swift 6.2 remains open; its static SDK lacks `Testing`.
3. **Fuzzing on macOS** with the Xcode toolchain, or only on Linux.
4. **Editor-analysis delivery estimate and native rule subset.** The explicit
   syntax/underline/native-lint scope changes M2/M3 work; select and test the
   first rule subset and revise estimates before scheduling integration.

The M0 findings, corrections and validation are recorded in
[Review-M0.md](Review-M0.md). M1's first implementation and example trees are
documented in [SyntaxTree.md](SyntaxTree.md). HTML/reference behavior and tests
are in [HTMLReferences.md](HTMLReferences.md). The M1 architecture, code,
QA and extensibility review is in [Review-M1.md](Review-M1.md), including the
follow-up assessment, reproduced defects and proposed work packages. The
assessment qualifies the historical speed comparison and retains release tree
validation. M1-A fixes the three reproduced defects and is merged in PR #4.
M1-B records two authorised full runs, a checked validation optimisation and a
local performance gate in [M1Measurements.md](M1Measurements.md). The current
block baseline passes its measured budgets; completed inline/GFM performance
is not established. M1-B is merged in PR #5 (`7c0f4ea`).

The agreed pre-M2 sequence is technically complete: portability, phase split,
shared extension/storage proof, fixed inline allowance and M1-D acceptance.
[M1Acceptance.md](M1Acceptance.md) records all results and the remaining platform
combinations without claiming editor/device checks. M1-C contracts and the now integrated M2 inline controller are in
[ExtensionContracts.md](ExtensionContracts.md) and [M2Inlines.md](M2Inlines.md).
The cumulative PR also carries the phase extraction from PR #8, merged into
its former base branch after PR #7 had already reached main. The owner merged that work in PR #9 (`61fcb95`) and the block optimisation
in PR #10 (`34cbe31`). M2 builds on that main revision. Functional checks and the frozen core/selected-rule performance gates pass;
PR #11 merged at `021f110`; the verified M2 branch was removed locally and remotely.

The frozen CommonMark baseline leaves 1.048 / 15.286 / 69.207 ms total headroom
at 100 KB / 1 MB / 5 MB. M2 receives a fixed **0.5 / 8 / 40 ms** allowance for
all additional parse work, checked by `Scripts/check_m2_budget.py` against a
hashed baseline. A positive reserve remains at every size. Selected rule
callbacks, new validation and allocation costs count inside this allowance.
String/segment reconstruction and optional parent-index costs are measured;
there is no assumed saving from a future lazy/pool representation.
Merged PR #10 (`34cbe31`) makes the block parse about three
times faster in a local harness, with byte-identical output (see
[Benchmarks](Benchmarks.md#block-parser-hot-path-optimisation-branch-perfblock-parser-hot-paths)).
A full package-benchmark run confirms this: CommonMark 1 MB takes 7.385 ms
against 19.153 ms for source-positioned C, and both budget checks pass. The
frozen M2 allowance stays unchanged; the gain is reserve. The GFM
ratios remain informational until the actual extensions are implemented.
Existing measurement-series authorization remains valid; otherwise follow the
full-benchmark owner rule.

M2 protected all 652 CommonMark examples and 641 pinned GFM examples; M4
protects all 672 GFM examples, run per example with its own extension as
upstream does. No fixture or protected ID was removed. The latest
functional, source-span, diagnostic, portability and timing evidence is in
[M2Inlines.md](M2Inlines.md); M2 technical acceptance uses the full/focused package-benchmark series and
unchanged gate inputs, not a short timing probe.

Follow-up status from the first consumer integration (Setzkit,
20 November 2026), before M5:

**Completed:** the versioned library release requested by the first consumer.
Source-only v0.4.0 is published after successful macOS/Linux checks, without
binary assets. Consumer version pinning remains a task in the consumer's own
repository; it no longer blocks library publication.

1. **Localised finding texts.** `NativeAnalyzer` findings and fix titles carry
   stable message keys (`gmsetzer.*`). **Merged in PR #17 (`0434ff5`), not yet
   in a versioned release:** the
   library ships optional English/German text lookup as pure Swift data/code
   in `SetzerAnalysis`; the caller selects a language tag explicitly or uses
   its own translations. English defaults are unchanged, heading findings
   additionally expose the integer `maximumLevel`, and unknown keys/languages
   or invalid required arguments retain `defaultText`. The stable key/argument
   contract is in [NativeAnalysisMessages](NativeAnalysisMessages.md).
   That step bumped provider/parser development identity to `0.4.1-dev`;
   the marker step below advances it to `0.5.0-dev`. Neither creates a release
   tag. Consumer adoption remains separate.
2. **Container marker tokens.** Merged in PR #18 (`4397819`), not yet in a
   versioned release: `core.blockQuote.marker` covers each actual quote
   prefix; `core.list.marker` covers each item's original bullet or ordered
   marker without padding. Collection remains opt-in and preserves semantic
   output. Development identity is `0.5.0-dev`; there is no new release tag.
   Exact ownership, extension and fallback contracts are documented in
   [ContainerMarkers](ContainerMarkers.md). Consumer color mapping remains
   outside the library.

Current next work: profile intermediate copies and HTML output after the merged
scan experiment, alongside separately
reviewed source-only 0.7 release preparation after the [M7 candidate](M7Readiness.md)
merged in PR #26 (`a273810`). The measured
scratch/token/buffer/UTF-8 optimizations now have current full Mac/x64 benchmark
controls, minimum Swift 6.2 CI, a source-matched 42-case progressive resource
matrix and bounded ASan/coverage-guided evidence. Historical baseline reports
retain their original identities; current reports link the actual hashes and
coverage limits. General C parity remains the aim: current x64 CommonMark takes
1.24–1.55× C time and GFM 0.92–0.99× on mixed-v1. Further intermediate-copy and
HTML-emission profiling, longer/larger campaigns and peak-memory investigation
remain useful follow-ups rather than claims established by these measurements.
The M6 progressive-output API and reviewed post-baseline budgets are accepted;
merged-main CI passes on macOS/Linux at the minimum Swift 6.2 toolchain.
Owner acceptance of the recorded M7 performance/robustness candidate remains
open; API/DocC/1.0 completion stays M8. Full benchmark
and long-test execution still requires the existing owner confirmation.
Consumer scheduling, dependency pinning and device acceptance remain in their
own repositories. The source-only v0.6.0 preview is published; 0.7 work remains separate.
