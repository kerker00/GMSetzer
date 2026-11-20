# GMSetzer

A Markdown parser written in pure Swift: CommonMark and GitHub Flavored
Markdown with switchable extensions, exact source positions and an HTML
renderer. No C, no Rust, no JavaScript, no runtime dependencies — it builds
wherever Swift runs, including Linux.

> **Status:** M2 merged in PR #11 (`021f110`), based on
> merged PRs #9/#10. All 652 CommonMark 0.31.2 examples pass by exact HTML;
> 641/672 pinned GFM examples pass. Blocks and inlines retain original UTF-8
> ranges, with optional lexical tokens and custom inline rules. Portable
> diagnostic/fix values are implemented; native lint and editor integration
> remain M3 work. Core and selected-rule performance gates pass; Publication remains
> a separate owner decision.

## Goals

- **Correct:** every example of CommonMark 0.31.2 and of the GFM spec.
- **Extensible:** footnotes, front matter, math, alerts and callouts, and
  later Obsidian, Pandoc and other dialects, as extensions that can be
  switched on one by one and grouped into profiles.
- **Positions:** every node knows its source range in UTF-8 bytes;
  conversion to lines, columns and UTF-16 offsets for text views.
- **Fast:** parse time at most twice that of cmark-gfm, aiming for parity,
  and linear time on pathological input.
- **Safe defaults:** raw HTML is written as text unless the caller allows
  it.
- **Swift 6:** `Sendable` values, strict concurrency, no global state.
- **Editor analysis (planned):** source-spelled syntax roles and precise native
  lint findings/fix suggestions over the same parse, for snapshot-bound editor
  highlighting and underlines. The current implementation is not a finished linter.

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
- [Docs/EditorAnalysis.md](Docs/EditorAnalysis.md) – planned syntax, native lint
  and editor-diagnostic contracts and acceptance gates.
- [Docs/HTMLReferences.md](Docs/HTMLReferences.md) – HTML policies, multiline
  definitions, opt-in editor provenance and validation.
- [CONTRIBUTING.md](CONTRIBUTING.md) – workflow and rules.

## Modules

| Module | Implemented | Planned |
| --- | --- | --- |
| `SetzerSyntax` | Validated block/inline tree, source ranges/tokens, parent index, diagnostic/fix values | Position conversion, outline queries |
| `SetzerParser` | Block/inline parser, custom rules/children, pre/post transforms and profiles | Additional dialect syntax |
| `SetzerExtensions` | GFM profile selections | GFM rule implementations, footnotes, front matter, math, alerts and callouts |
| `SetzerHTML` | CommonMark HTML, source anchors, escaping, comment policy and decoded URL checks | GFM tag filtering |
| `GMSetzer` | Imports the four implemented modules above | Optional analysis module with its first tested rules |

M1 acceptance is merged in PR #9 and block hot-path optimisation in PR #10.
M2 adds CommonMark inlines and 867 exact C comparisons. Complete GFM and
Setzkit integration remain M4 and M3 work respectively; the fixed M2 timing
allowance is unchanged.

```swift
import GMSetzer

let document = MarkdownParser().parse("# Hello")
let html = HTMLRenderer().render(document)
// <h1>Hello</h1>\n
```

`parse(bytes:)` also accepts original UTF-8 bytes, preserving invalid sequences
in `Document.source` while replacing them in literals. A leading UTF-8 BOM is
ignored for syntax recognition but retained in the original bytes and offsets.
`.gfm` selects its five
extensions explicitly; until M4 implements them, missing extensions are listed
in `MarkdownParser.configurationIssues`; `validated()` rejects them.

`collectSyntaxDetails: true` optionally collects `Document.tokens`, including
reference/fence components, inline delimiters, link parts, escapes/entities,
raw HTML and extension roles. `referenceSyntax(for:)` is a
convenience view. `DocumentIndex` provides snapshot-bound parents/ancestors. HTML blocks are escaped and recognised comments omitted by default;
`allowRawHTML` and `preserveHTMLComments` are explicit renderer options.
Dangerous decoded URL schemes are neutralised even with raw HTML enabled.
`HTMLRenderer.conformance` explicitly permits raw HTML, comments and unsafe URLs
for trusted fixtures; it is not the production configuration.
Custom leaf fallbacks retain projected content without quote/list prefixes;
renderer wrappers preserve built-in list tightness.

## Development

- `swift test` runs the unit tests and every specification example (652
  CommonMark, 672 in the pinned GFM corpus, including task lists). The IDs of
  passing examples are recorded in
  `Tests/SetzerSpecTests/Resources/baseline.json`; each recorded example must
  keep passing. Green tests mean the recorded baseline is preserved; they do
  not claim complete GFM conformance. CommonMark has an additional explicit
  652/652 completeness assertion.
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
