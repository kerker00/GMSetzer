# GMSetzer

A Markdown parser written in pure Swift: CommonMark and GitHub Flavored
Markdown with switchable extensions, exact source positions and an HTML
renderer. No C, no Rust, no JavaScript, no runtime dependencies — it builds
wherever Swift runs, including Linux.

> **Status, 20 November 2026:** M1–M4 are merged in `main`, including
> M3 editor services (PR #12, `651af17`), their measurements (PR #13,
> `c5f9a0b`) and GFM (PR #14, `e163e6f`). All 652 CommonMark 0.31.2 and
> 672 pinned GFM specification examples pass by exact HTML. The source-only
> [v0.4.0 preview release](https://github.com/kerker00/GMSetzer/releases/tag/v0.4.0)
> is published; macOS/Linux CI and release preparation are merged in PR #16
> (`6a0eb8e`). Both platforms pass all 118 Swift tests and 17 Python tests.

Requires **Swift 6.2 or later**. The current provisional Apple minimums are
macOS 15, iOS 18 and visionOS 2; Linux is supported. The repository is public
and can be fetched over HTTPS without GitHub authentication. Consumers pin
version tags through Swift Package Manager; no binary release assets or package
registry are required.

## Installation

Pin the **0.4.0 preview release** with Swift Package Manager:

```swift
.package(url: "https://github.com/kerker00/GMSetzer.git", exact: "0.4.0")
```

Add `.product(name: "GMSetzer", package: "GMSetzer")` to your target's
dependencies. APIs may change before 1.0. GitHub provides source ZIP and tar.gz
archives; no binary assets are uploaded. See the
[release notes](Docs/Releases/0.4.0.md) and
[release process](Docs/Releasing.md) for scope, checks and publication steps.

## Independence

GMSetzer is a standalone MIT-licensed Swift package for editors, command-line
utilities, servers and other Markdown consumers. Every library target depends
only on modules inside this package. No consumer checkout, application session,
UI framework or editor implementation is needed to build or use it.

Public APIs exchange original UTF-8 bytes, immutable syntax trees, portable
positions, diagnostic reports and advisory edits. A consumer owns revision
identity, scheduling, localization, UI ranges and undo/IME integration in its
own adapter. The library never imports that adapter. Application integration
and device acceptance do not determine this package's API or release readiness.

## Goals

- **Correct:** every example of CommonMark 0.31.2 and of the GFM spec.
- **Extensible:** shipped CommonMark and GFM profiles, independently selectable
  GFM features, custom block/inline rules and transforms. Footnotes, front
  matter, math, alerts and callouts are planned for M5; further dialects follow.
- **Positions:** every node knows its source range in UTF-8 bytes;
  conversion to lines, columns and UTF-16 offsets for text views.
- **Fast:** parse time at most twice that of cmark-gfm, aiming for parity,
  and linear time on pathological input.
- **Safe defaults:** raw HTML is written as text unless the caller allows
  it.
- **Swift 6:** `Sendable` values, strict concurrency, no global state.
- **Editor services:** optional syntax tokens, UTF-16/line/column conversion,
  parent/caret queries and a heading outline. Three opt-in native rules detect
  skipped heading levels, duplicate headings and trailing whitespace, with
  portable findings and suggested fixes. Analysis is not a complete linter;
  messages are English and block-quote/list marker tokens remain follow-up work.

## Documentation

- [Docs/Plan.md](Docs/Plan.md) – requirements, decisions, architecture,
  milestones and licence rules. Start here.
- [Docs/Benchmarks.md](Docs/Benchmarks.md) – measurements against cmark-gfm.
- [Docs/Portability.md](Docs/Portability.md) – Swift 6.2 tests, Linux ARM64
  execution evidence, SDK selection, span availability and remaining coverage.
- [Docs/Review-M0.md](Docs/Review-M0.md) – review findings and corrections.
- [Docs/M1Acceptance.md](Docs/M1Acceptance.md) – technical decision, measured
  M2 allowance, portability matrix and acceptance evidence.
- [Docs/Review-M1.md](Docs/Review-M1.md) – M1 architecture, code, QA and
  extensibility review with recommendations before M2.
- [Docs/SyntaxTree.md](Docs/SyntaxTree.md) – implemented tree/extension contract,
  example ranges and the implemented block contracts.
- [Docs/ExtensionContracts.md](Docs/ExtensionContracts.md) – shared configuration,
  container/inline rules, transforms, token ownership and hook context.
- [Docs/M2Inlines.md](Docs/M2Inlines.md) – inline API, source tokens, diagnostic/fix
  values, current validation and remaining performance acceptance.
- [Docs/BlockPhases.md](Docs/BlockPhases.md) – extracted block-phase boundaries,
  full Linux regression suite and performance countermeasurement before registry work.
- [Docs/EditorAnalysis.md](Docs/EditorAnalysis.md) – syntax, native lint and
  editor-diagnostic contracts, including planned extensions and acceptance gates.
- [Docs/M3EditorServices.md](Docs/M3EditorServices.md) – implemented position,
  outline, HTML and native analysis APIs and their validation limits.
- [Docs/M4GFM.md](Docs/M4GFM.md) – merged GFM profiles, switches, source ranges,
  conformance and measurements.
- [Docs/HTMLReferences.md](Docs/HTMLReferences.md) – HTML policies, multiline
  definitions, opt-in editor provenance and validation.
- [CONTRIBUTING.md](CONTRIBUTING.md) – workflow and rules.

## Modules

| Module | Implemented | Planned |
| --- | --- | --- |
| `SetzerSyntax` | Validated block/inline tree, source ranges/tokens, parent/offset/outline index, position conversion, diagnostic/fix values | Additional query conveniences |
| `SetzerParser` | Block/inline parser, custom rules/children, pre/post transforms and profiles | Additional dialect syntax |
| `SetzerExtensions` | GFM profile (built-in GFM features) | Footnotes, front matter, math, alerts and callouts |
| `SetzerHTML` | CommonMark and GFM HTML, source anchors, escaping, comment policy, tag filter and decoded URL checks | – |
| `SetzerAnalysis` | Three optional native rules over the existing document | Broader rule catalogue |
| `GMSetzer` | Imports the five implemented modules above | Additional convenience APIs |

M1 acceptance is merged in PR #9 and block hot-path optimisation in PR #10.
M2 adds CommonMark inlines and 867 exact C comparisons. M4 adds GFM as typed
built-in nodes, compared with cmark-gfm; see [Docs/M4GFM.md](Docs/M4GFM.md).

## Usage

```swift
import GMSetzer

let document = MarkdownParser().parse("# Hello")
let html = HTMLRenderer().render(document)
// <h1>Hello</h1>\n
```

`parse(bytes:)` also accepts original UTF-8 bytes, preserving invalid sequences
in `Document.source` while replacing them in literals. A leading UTF-8 BOM is
ignored for syntax recognition but retained in the original bytes and offsets.
`MarkdownParser(profile: .gfm)` enables tables, task lists, strikethrough,
extended autolinks, the tag filter and GitHub's nested-strong rendering; each
`BuiltinExtension` can also be selected on its own.

`collectSyntaxDetails: true` optionally collects `Document.tokens`, including
reference/fence components, inline delimiters, link parts, escapes/entities,
raw HTML and extension roles. `referenceSyntax(for:)` is a
convenience view. `DocumentIndex` provides snapshot-bound parents/ancestors, caret queries and heading outline. `SourceIndex` converts original-byte ranges to UTF-16 without rounding. HTML blocks are escaped and recognised comments omitted by default;
`allowRawHTML` and `preserveHTMLComments` are explicit renderer options.
Dangerous decoded URL schemes are neutralised even with raw HTML enabled.
`HTMLRenderer.conformance` explicitly permits raw HTML, comments and unsafe URLs
for trusted fixtures; it is not the production configuration.
Custom leaf fallbacks retain projected content without quote/list prefixes;
renderer wrappers preserve built-in list tightness.

```swift
let positions = SourceIndex(document)
let utf16Range = positions.utf16Range(for: document.root.range)
let outline = DocumentIndex(document).outline()
let report = try NativeAnalyzer.analyze(document, dialect: .commonMark,
    configuration: NativeAnalysisConfiguration(rules: [.headingLevel]))
```

Service contracts, the native rule catalogue and validation limits are in
[Docs/M3EditorServices.md](Docs/M3EditorServices.md).

## Development

- `swift test` runs the unit tests and every specification example (652
  CommonMark, 672 in the pinned GFM corpus, including task lists). The IDs of
  passing examples are recorded in
  `Tests/SetzerSpecTests/Resources/baseline.json`; each recorded example must
  keep passing. Both corpora have explicit completeness assertions (652/652,
  672/672); GFM examples run with their own extension, as upstream does.
- `Scripts/update-specs.sh` reproduces the specification examples from pinned,
  SHA-256 checked sources.
- `python3 -I -m unittest discover -s Scripts` tests the update tools offline.
- `swift test --package-path Tools --filter ContainerReferenceTests` compares
  1,985 documents by exact HTML, 1,924 HTML/reference documents by block
  structure and literal content, and ten BOM cases with pinned cmark in C. These
  development dependencies remain separate from the library.
- `GMSETZER_SPEC_DIAGNOSTICS=1 swift test --filter SpecTests` also prints each
  mismatching example with source, expected HTML and actual HTML as JSON.
- `Tools/` is a separate package for benchmarks against cmark-gfm in C and
  swift-markdown: `cd Tools && swift package benchmark`.
- [M1 measurements](Docs/M1Measurements.md) describe the recorded block-only
  baseline, optional syntax costs and local performance gate. Run
  `python3 -I Scripts/check_benchmark_budget.py <results.log>` against a full
  Markdown benchmark export to check matching C/absolute parse budgets.

## Licence

GMSetzer is released under the [MIT licence](LICENSE). Third-party material
and its licences are listed in [NOTICE](NOTICE); the specification examples
used as test data are licensed CC-BY-SA 4.0 and are not part of the library.
