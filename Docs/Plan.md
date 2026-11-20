# GMSetzer – Plan and Requirements

**Status: 19 November 2026, M1 block implementations present, including HTML and multiline references; final acceptance/API review open.** This document is the
reference for everyone working on GMSetzer. It records what the library must
do, why it exists, how it is built and in which order. It is self-contained:
no knowledge of earlier discussions is needed.

GMSetzer is developed for [Setzkit](#setzkit), a native Markdown editor for
macOS, iPadOS and iOS, but it is a general-purpose library. Nothing in its
API refers to Setzkit.

## Contents

1. [Why GMSetzer exists](#why)
2. [Decisions](#decisions)
3. [Requirements](#requirements)
4. [What Setzkit needs from the library](#setzkit)
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

Setzkit needs a parser that handles CommonMark, the complete GFM, footnotes,
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
| Write an own parser in pure Swift instead of using comrak, micromark or swift-markdown | Full control over extensions, positions and speed; no extra toolchain; useful beyond Setzkit |
| Learn from existing parsers as much as possible and do it better, faster and more complete | Algorithms and tests are taken over deliberately, under the licence rules in [section 7](#learning) |
| Own repository from the first line of code | The parser is testable without Setzkit from day one |
| Name **GMSetzer** | Family name with GMSnagNav; a *Setzer* is a typesetter. No collision found in a search |
| Repository private until milestone M2, then public | Publishing is a separate step that the owner confirms explicitly |
| MIT licence | Permissive, usable in commercial and open source apps |
| Linux supported | The core uses only the Swift standard library |
| No runtime dependencies in the library | Tool and test dependencies live in the separate package `Tools/` |
| No interim parser in Setzkit | Setzkit starts rendering when GMSetzer reaches M3 |
| Math is recognised, not rendered | The library stays free of JavaScript; the caller converts TeX through a renderer hook (Setzkit uses Temml to produce MathML) |

<a id="requirements"></a>

## 3. Requirements

### Functional

| Area | Version 1.0 | Later |
| --- | --- | --- |
| Core | CommonMark 0.31.2, all 652 examples | Later spec versions |
| GFM | Tables, task lists, strikethrough, extended autolinks and disallowed raw HTML (tag filtering); all 672 examples in the pinned GFM 0.29-derived cmark corpus, including the two task list examples marked `disabled` upstream | – |
| Further syntax | Footnotes; front matter (YAML/TOML at the start, delivered as raw text); math inline `$…$`, display `$$…$$` and ` ```math ` blocks; GitHub alerts `> [!NOTE]` (NOTE, TIP, IMPORTANT, WARNING, CAUTION); Obsidian callouts `> [!type]` with optional `+`/`-` folding marker and title | – |
| Profiles | Every extension switchable on its own; shipped profiles "CommonMark strict" and "GFM" | Obsidian (wikilinks, embeds `![[…]]`, `==highlight==`, tags), Pandoc (definition lists, attributes `{.class}`, fenced divs, sub-/superscript, citations `[@key]`), MultiMarkdown, kramdown, user-defined profiles |
| Output | Syntax tree with source ranges; HTML renderer with block anchors | Markdown serialiser (for converting between profiles), other output formats |
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
  scalars are defined in [SyntaxTree.md](SyntaxTree.md); conversion follows in M3.
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

<a id="setzkit"></a>

## 4. What Setzkit needs from the library

Setzkit is the first user. Its needs shape the API, but every one of them is
useful to other apps as well.

| Need | Why |
| --- | --- |
| Exact UTF-16 ranges for every node | The editor (TextKit 2) highlights, folds and links syntax in `NSRange` terms |
| Block anchors in the HTML (source line or byte offset on block elements) | Scroll synchronisation between editor and preview |
| An outline query (headings and blocks with ranges and levels) | Folding, a breadcrumb of the current section and an outline overview all read the same model |
| Switchable extensions and named profiles | Setzkit lets the user choose a dialect per app, project or document; changing the profile never changes the file |
| A renderer hook per node kind | Math becomes MathML through Temml, code blocks get syntax highlighting, Mermaid diagrams are rendered elsewhere |
| Speed on the iPhone and in a Quick Look extension | Large documents (up to 5 MB) must stay usable; Quick Look runs with tight limits and without JavaScript |
| `Sendable` results | The Setzkit adapter associates background parse results with their snapshot revision, dialect and configuration; GMSetzer does not import app-specific revision types |
| Safe HTML by default | Previews and exports never run active content from documents |
| Syntax roles and document findings | Theme-based highlighting and precise underline/caret/gutter locations in TextKit; preserve delimiters and original trivia |
| Native lint rules over the same parse | Optional checks reuse GMSetzer's dialect semantics and source, with provider/rule IDs, severity, related ranges and advisory fixes |

### Editor analysis is an explicit deliverable

The original position requirements were necessary but did not define complete
syntax-checking and lint services. The owner confirmed these uses on
19 November 2026. [EditorAnalysis.md](EditorAnalysis.md) now specifies them,
including source-spelled syntax spans, a future optional analysis module,
revision-bound UTF-16 underlines, diagnostics versus parser/provider failures,
rule profiles and strict suggested-fix transactions.

This is a planned contract. Current `ParseDiagnostic` covers infrastructure
conditions, not a finished linter. CommonMark literal fallbacks are not syntax
errors by default. Markdownlint remains an optional compatibility/provider
path; equivalence is not assumed for native rules.

<a id="architecture"></a>

## 5. Architecture

### Modules

| Module | Contents | Depends on |
| --- | --- | --- |
| `SetzerSyntax` | Syntax tree (node kinds, source ranges), position conversion, outline query, visitors | – |
| `SetzerParser` | Block and inline parser, extension API, profiles | `SetzerSyntax` |
| `SetzerExtensions` | GFM, footnotes, front matter, math, alerts and callouts | `SetzerParser`, `SetzerSyntax` |
| `SetzerHTML` | HTML renderer, block anchors, escaping and URL checks, renderer hooks | `SetzerSyntax` |
| `SetzerAnalysis` (planned) | Optional native rules over existing tree/source; portable findings and suggested edits | `SetzerSyntax` |
| `GMSetzer` | Re-exports all of the above | all |

Portable syntax-span/diagnostic/fix values belong in `SetzerSyntax`.
`SetzerAnalysis` is not implemented or a package target yet; introduce it with
its first tested rules. The parser remains independent of analysis and HTML.

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
  container continuation and depth limits are now included. Custom container
  hooks and link payloads remain subsequent M1/M2 work.
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
Custom container/inline hooks and post-processing remain open. The detailed contract
and callback trust boundary are in [SyntaxTree.md](SyntaxTree.md). Renderer
hooks stay in `SetzerHTML`, without a parser-to-renderer dependency.

Math: the library produces nodes with the TeX source and nothing else.

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
  a separate reviewed change. The comparison is exact today. Introduce a
  narrowly defined HTML normaliser, with its own regression tests, by M2;
  never erase meaningful whitespace in code or raw HTML.
- **Version differences:** CommonMark 0.31.2 and the GFM 0.29-derived corpus
  are distinct targets. Classify conflicting inputs before M4; retain both
  original fixtures and use explicit profile-specific behaviour. Any proposed
  deviation needs a documented decision, never an implicit skipped example.
- **Extensions:** test each switch independently, off/on and in combinations;
  own fixtures per extension, with comrak's and micromark's
  tests as references for expected behaviour (with attribution).
- **Positions:** ranges address the exact original snapshot, with tests for
  syntax versus decoded content, container prefixes, CRLF/CR/LF, tabs,
  entities and escapes. UTF-16 conversion is tested with umlauts, emoji,
  combining characters, CJK and right-to-left text.
- **Rendering:** conformance configuration is separate from safe defaults.
  Test escaping, comments, decoded/obfuscated URL schemes, GFM tag filtering,
  anchors and caller hook trust before Setzkit integration in M3.
- **Editor analysis:** exact delimiter/finding ranges, native rule selection,
  legal literal fallbacks, source trivia, zero-length/related ranges and fix
  preconditions. Setzkit must prove UTF-16 underlines, stale-result rejection,
  IME/undo protection and accessible problem navigation. See
  [EditorAnalysis.md](EditorAnalysis.md); these acceptance checks remain open.
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
| M1 | Source/payload/builder and extension contracts; block parser: paragraphs, ATX/setext headings, thematic breaks, quotes, lists, indented/fenced code, HTML blocks, references; basic HTML renderer grows alongside blocks | Block AST/range tests cover all block sections; HTML-compatible subset passes. Examples needing inline parsing remain M2 work | 8–12 | **reviewed; acceptance open**: M1-A merged in PR #4 (`51efee6`); M1-B measurements, checked validation optimisation and local budget gate implemented. 57 tests and 3,919 reference comparisons pass; 339/652 CommonMark and 339/672 GFM examples pass. [Review-M1](Review-M1.md) tracks the completed block-phase split, remaining M1-C extension/storage proof and M1-D invariant/hardening acceptance before M2 |
| M2 | Inline parser and opt-in delimiter spans; portable document-diagnostic/fix contract; complete CommonMark rendering and tested normalisation | 652/652 CommonMark with explicit conformance settings; editor source-span tests pass; publication only after owner confirmation | re-estimate | |
| M3 | Safe HTML, anchors/hooks, position conversion, outline; optional native analysis with a named rule subset; editor adapter for syntax spans/findings | Security/position/analysis tests pass; Setzkit proves snapshot-bound syntax decoration and diagnostic underlines; integration can start | re-estimate | |
| M4 | GFM extensions including tag filtering; resolve version differences explicitly | 672/672 pinned GFM corpus, including task lists; independent extension switch tests pass | 4–6 | |
| M5 | Footnotes, front matter, math, alerts and callouts; profiles "CommonMark strict" and "GFM" | Setzkit's corpus complete | 5–8 | |
| M6 | Speed and hardening: measurements, optimisation, hostile input, fuzzing | Speed targets of section 3 met | 5–8 | |
| M7 | Version 1.0: API review, DocC documentation, release; Setzkit pins the version | Setzkit uses 1.0 | 3–5 | |
| | **Original total before explicit editor-analysis scope** | | **38–59; re-estimate required** | |

After 1.0: further profiles (Obsidian, Pandoc), a Markdown serialiser for
profile conversions, incremental parsing if measurements call for it.

<a id="repository"></a>

## 11. Repository rules

- **Language:** code, comments, commit messages, pull requests and
  documentation in English.
- **Branches:** `main` is the only long-lived branch. Work happens on feature
  branches from `main`; pull requests target `main`. The owner merges.
- **Visibility:** private until M2. Making the repository public, tagging
  releases and publishing anything happens only after the owner's explicit
  confirmation right before the step.
- **No CI** unless the owner decides otherwise.
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
| Setzkit waits for the library (accepted) | Setzkit works on parser-independent parts meanwhile; M3 is the earliest point of use |
| Licence mistakes when taking over code | MIT/BSD/Apache-2.0 only, origin in file headers, `NOTICE` kept up to date; GPL/LGPL excluded |

<a id="open"></a>

## 13. Open questions

The block-loop decomposition has moved to the beginning of M1-C, before shared
registry dispatch; its implemented boundaries and verification are in
[BlockPhases.md](BlockPhases.md). Remaining M1-D work includes the builder
invariant/`try!` audit and final acceptance, not a second decomposition.

1. **Minimum platform and Swift versions.** The manifest requires Swift tools
   6.2 and provisionally macOS 15, iOS 18 and visionOS 2. Swift 6.2 now builds
   all library modules for macOS and Linux ARM64; all 57 macOS tests pass with
   a compatible SDK/testing runtime. Compile probes confirm that `Span` and
   an unsafe-buffer bridge support macOS 15, while direct `Array.span` and
   `UTF8Span` require macOS 26. Minimum Apple OS runtime checks remain open;
   keep the byte-buffer path. See [Portability.md](Portability.md).
2. **Linux verification coverage.** The initial static ARM64 probe retains all
   protected IDs across 1,324 spec inputs plus targeted checks. The extracted
   phases now pass all 57 tests on Linux x86-64/glibc with Swift 6.4.2 through
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
is not established. M1-B is merged in PR #5 (`7c0f4ea`); the Setzkit-side
documentation alignment is merged in Setzkit PR #22 (`39e5fd0`).

The agreed order before M2 is now: verify Linux and Swift 6.2 first; split the
block-parser main loop at the start of M1-C, before introducing shared rule
dispatch; then prove extension/storage contracts with an explicit inline
budget; finally complete the remaining M1-D checks and accept M1. The current
core baseline leaves 0.724 ms at 100 KB and 11.223 ms at 1 MB for all additional
parse work, not exclusively inlines. M1-C must measure remaining string/segment
costs and establish a tested budget rather than assume that this reserve is
sufficient. Existing measurement-series
authorization remains valid; otherwise follow the full-benchmark owner rule.

M1-C implementation and M1-D invariant policy are described in
[ExtensionContracts.md](ExtensionContracts.md). The acceptance branch carries
the block-phase extraction merged into the former portability branch after its
main merge. Final tests, timings and the M2 inline allowance are pending the
[M1 acceptance receipt](M1Acceptance.md); no M2 work has started.
