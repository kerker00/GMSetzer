# GMSetzer

A Markdown parser written in pure Swift: CommonMark and GitHub Flavored
Markdown with switchable extensions, exact source positions and an HTML
renderer. No C, no Rust, no JavaScript, no runtime dependencies — it builds
wherever Swift runs, including Linux.

> **Status:** M1 technical acceptance passed; cumulative PR/owner merge pending. The first slice implements a validated
> syntax tree, paragraphs, headings, code, nested block quotes and ordered/bullet
> lists, including lazy continuation, tightness and depth limits. Custom block
> rules receive projected source lines and optional core-parsed children. HTML blocks and multiline reference
> definitions are implemented, with an opt-in generic token table. Inline
> markup and editor analysis remain pending. Current spec passes: 339/652
> CommonMark and 339/672 GFM. The repository stays private until
> milestone M2 and owner approval.

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
  container/transform probes, token ownership, hook context and the inline API draft.
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
| `SetzerSyntax` | Validated tree, source ranges/segments, optional tokens and parent index | Position conversion, outline queries |
| `SetzerParser` | Block parser, custom children/transforms, validated registry and profiles | Inline parser and promotion of the inline API draft |
| `SetzerExtensions` | GFM profile selections | GFM rule implementations, footnotes, front matter, math, alerts and callouts |
| `SetzerHTML` | Block HTML rendering, source anchors, escaping and comment policy | Inline rendering and URL safety |
| `GMSetzer` | Imports the four implemented modules above | Optional analysis module with its first tested rules |

The [M1 acceptance record](Docs/M1Acceptance.md) closes the review work with
70 library tests, 3,919 C comparisons and a fixed M2 parse budget. Owner merge
is pending. Actual inlines, complete GFM and editor integration remain M2–M5.

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
reference components/markers and extension roles. `referenceSyntax(for:)` is a
convenience view. `DocumentIndex` provides snapshot-bound parents/ancestors. HTML blocks are escaped and recognised comments omitted by default;
`allowRawHTML` and `preserveHTMLComments` are explicit renderer options.
Custom leaf fallbacks retain projected content without quote/list prefixes;
renderer wrappers preserve built-in list tightness.

## Development

- `swift test` runs the unit tests and every specification example (652
  CommonMark, 672 in the pinned GFM corpus, including task lists). The IDs of
  passing examples are recorded in
  `Tests/SetzerSpecTests/Resources/baseline.json`; each recorded example must
  keep passing. Green tests mean the recorded baseline is preserved; they do
  not claim complete CommonMark or GFM conformance.
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
