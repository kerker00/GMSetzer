# GMSetzer – Plan and Requirements

**Status: 19 November 2026, milestone M0 done.** This document is the
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
licence. The candidates were checked against their sources and documentation
on 19 November 2026:

| Candidate | Result |
| --- | --- |
| [swift-markdown](https://github.com/swiftlang/swift-markdown) (Apple, wraps cmark-gfm in C) | GFM only. No footnotes, front matter or math in its source tree, no API for custom syntax, extensions cannot be switched. Inline math cannot be added by pre- or post-processing because cmark already treats `_` and `*` inside `$…$` as emphasis. |
| [micromark](https://github.com/micromark/micromark) / unified (JavaScript) | All needed extensions and exact positions, but it would run in JavaScriptCore. Inside iOS apps that engine has no JIT; reported slowdowns are up to about 7.5× (reports from 2019/2020). Too risky for large documents on the iPhone. |
| [comrak](https://github.com/kivikakk/comrak) (Rust, BSD-2) | Everything needed and more, 652/652 CommonMark and 670/670 GFM. Costs a Rust toolchain in the build, an XCFramework and a C interface. |
| [MarkdownKit by objecthub](https://github.com/objecthub/swift-markdownkit) (pure Swift, Apache-2.0) | Closest pure Swift parser: passes all 652 CommonMark examples according to its README and is extensible. Apple platforms only, no footnotes, no extended autolinks, no documented source positions. |
| Other Swift packages for GFM on Linux (swift-cmark, Swift-GFM, cmark-gfm wrappers) | All wrap cmark-gfm in C. |

**The gap:** there is no Swift library that implements CommonMark and complete
GFM in pure Swift, runs on Linux, gives exact source positions and offers
switchable extensions and profiles. GMSetzer fills that gap.

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
| GFM | Tables, task lists, strikethrough, extended autolinks; all 670 enabled examples of the GFM spec 0.29 | – |
| Further syntax | Footnotes; front matter (YAML/TOML at the start, delivered as raw text); math inline `$…$`, display `$$…$$` and ` ```math ` blocks; GitHub alerts `> [!NOTE]` (NOTE, TIP, IMPORTANT, WARNING, CAUTION); Obsidian callouts `> [!type]` with optional `+`/`-` folding marker and title | – |
| Profiles | Every extension switchable on its own; shipped profiles "CommonMark strict" and "GFM" | Obsidian (wikilinks, embeds `![[…]]`, `==highlight==`, tags), Pandoc (definition lists, attributes `{.class}`, fenced divs, sub-/superscript, citations `[@key]`), MultiMarkdown, kramdown, user-defined profiles |
| Output | Syntax tree with source ranges; HTML renderer with block anchors | Markdown serialiser (for converting between profiles), other output formats |
| Outline | Query for headings and block structure with their ranges | – |

### Non-functional

- **Pure Swift, no runtime dependencies.** The core uses the standard library
  only (Foundation at most in the HTML renderer, if at all). It runs in apps,
  app extensions such as Quick Look, command-line tools and on Linux.
- **Swift 6, strict concurrency.** Syntax tree and results are `Sendable`
  values; parsing works on any thread, there is no global mutable state.
- **Positions.** Every node carries its source range as UTF-8 byte offsets.
  A conversion helper gives lines, columns and UTF-16 offsets (what TextKit
  and `NSRange` use). Positions must be exact for every node kind, including
  extensions.
- **Speed.** Measured with the benchmarks in `Tools/` (see
  [Benchmarks.md](Benchmarks.md)):

  | Size | Mac (Apple Silicon) | Oldest test iPhone |
  | --- | --- | --- |
  | 100 KB | < 10 ms | < 30 ms |
  | 1 MB | < 60 ms | < 200 ms |
  | 5 MB | < 300 ms | < 1 s |

  The stricter rule: **at most twice the time of cmark-gfm in C** on the same
  machine and document, aiming for parity. Measured reference on the owner's
  Mac (M2): 1.7 ms for 100 KB, 19 ms for 1 MB, 96 ms for 5 MB.
- **Robust.** Linear time even on hostile input (deep nesting, many open
  brackets, long runs of emphasis characters); limits for nesting depth; no
  crash on invalid UTF-8.
- **Safe by default.** The HTML renderer writes raw HTML from the source as
  escaped text unless the caller allows it; HTML comments are left out;
  dangerous URL schemes (`javascript:`, `vbscript:`, `data:` except images)
  are neutralised. Allowing raw HTML is an explicit option.

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
| `Sendable` results | Parsing runs in the background on immutable snapshots of the text; results carry the text revision they come from |
| Safe HTML by default | Previews and exports never run active content from documents |

<a id="architecture"></a>

## 5. Architecture

### Modules

| Module | Contents | Depends on |
| --- | --- | --- |
| `SetzerSyntax` | Syntax tree (node kinds, source ranges), position conversion, outline query, visitors | – |
| `SetzerParser` | Block and inline parser, extension API, profiles | `SetzerSyntax` |
| `SetzerExtensions` | GFM, footnotes, front matter, math, alerts and callouts | `SetzerParser` |
| `SetzerHTML` | HTML renderer, block anchors, escaping and URL checks, renderer hooks | `SetzerSyntax` |
| `GMSetzer` | Re-exports all of the above | all |

### Approach

- **Input as UTF-8 bytes**, not as `String` characters. Parsing works on one
  contiguous byte buffer with integer indices, as cmark does. This is what
  makes the speed and exact positions possible. `Span`/`UTF8Span` (Swift 6.2)
  are the intended tools.
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
- **Node kinds** are predefined for CommonMark and GFM; extensions register
  their own kinds by name (`NodeKind`), so new syntax never needs a fork.
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
| Fast byte access | Standard library, `Span`/`UTF8Span` (Swift 6.2) | yes | core |
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
  0.31.2 and of the GFM spec. `baseline.json` records how many pass; the tests
  fail when the number drops. Raise the baseline in the same commit that makes
  more examples pass. The comparison is exact today; the spec's HTML
  normalisation (as in cmark's `normalize.py`) is added in M3.
- **Extensions:** own fixtures per extension, with comrak's and micromark's
  tests as references for expected behaviour (with attribution).
- **Positions:** for every node, its source range must contain exactly the
  text it came from. UTF-16 conversion is tested with umlauts, emoji,
  combining characters, CJK and right-to-left text.
- **Reference comparisons:** a corpus of real documents is compared with
  cmark-gfm; every difference is explained.
- **Hostile input:** cmark's pathological cases with a time limit.
- **Fuzzing:** random and mutated input must never crash or exceed the time
  limit.
- **Benchmarks:** fixed documents (100 KB, 1 MB, 5 MB), recorded with commit,
  machine and OS in [Benchmarks.md](Benchmarks.md).

<a id="milestones"></a>

## 10. Milestones

Estimates in person days for an experienced developer. Every milestone ends
with a measurable result.

| Milestone | Contents | Done when | Estimate | Status |
| --- | --- | --- | --- | --- |
| M0 | Repository, package layout, specification run, benchmark setup, name and gap check | Spec run shows the starting point; benchmarks measure the reference | 2–3 | **done** (19 Nov 2026) |
| M1 | Block parser: paragraphs, ATX and setext headings, thematic breaks, block quotes, lists, indented and fenced code, HTML blocks, link reference definitions | All block sections of the spec pass | 8–12 | next |
| M2 | Inline parser: escapes, entities, code spans, emphasis (delimiter stack), links and images, autolinks, raw HTML, line breaks | 652/652 CommonMark; repository goes public after the owner confirms | 8–12 | |
| M3 | HTML renderer with spec normalisation, block anchors, position conversion, outline query | Position tests pass; Setzkit starts using GMSetzer | 3–5 | |
| M4 | GFM extensions | 670/670 GFM | 4–6 | |
| M5 | Footnotes, front matter, math, alerts and callouts; profiles "CommonMark strict" and "GFM" | Setzkit's corpus complete | 5–8 | |
| M6 | Speed and hardening: measurements, optimisation, hostile input, fuzzing | Speed targets of section 3 met | 5–8 | |
| M7 | Version 1.0: API review, DocC documentation, release; Setzkit pins the version | Setzkit uses 1.0 | 3–5 | |
| | **Total** | | **38–59** | |

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

1. **Minimum platform and Swift versions.** `Package.swift` currently declares
   macOS 15, iOS 18 and visionOS 2 provisionally; using `Span` needs Swift 6.2
   and may raise the OS minimums.
2. **Linux verification.** The package is designed for Linux but has not been
   built there yet (no container tool on the owner's Mac).
3. **Fuzzing on macOS** with the Xcode toolchain, or only on Linux.
