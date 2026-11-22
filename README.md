# GMSetzer

A Markdown parser written in pure Swift: CommonMark and GitHub Flavored
Markdown with switchable extensions, exact source positions and an HTML
renderer. No C, no Rust, no JavaScript, no runtime dependencies — it builds
wherever Swift runs, including Linux.

> **Status, 21 November 2026:** M1–M6 are merged in `main`. M5 has
> [functional acceptance](Docs/M5Acceptance.md); M6's progressive-output
> [library gates are accepted](Docs/M6Acceptance.md). Merged-main CI passes
> 242 Swift tests, all 652 CommonMark and 672 GFM examples, optimized builds
> and 31 Python tests on macOS/Swift 6.2.3 and Linux/Swift 6.2. The latest
> published source-only preview is [v0.6.0](https://github.com/kerker00/GMSetzer/releases/tag/v0.6.0), including M6.

[PR #24](https://github.com/kerker00/GMSetzer/pull/24) (`a8a0351`) adds
**progressive HTML**; its accepted M6 snapshot used identity `0.6.0-dev.1`.
That implementation is published separately as source-only **v0.6.0** at
`8ff2061`, after [PR #25](https://github.com/kerker00/GMSetzer/pull/25) merged.
See its [release notes](Docs/Releases/0.6.0.md) and
[validation](Docs/Validation/Release/0.6.0.md).
This M7 branch now reports **`0.7.0-dev.1`** and retains the new hardening/
optimization work for the next preview.
`HTMLRenderer.prepare` and `FootnotesHTMLRenderer.prepare` retain complete
Markdown context and emit structural HTML groups on demand, with explicit
whole-document fallbacks for raw HTML and document-order hooks. The
[API and limits](Docs/ProgressiveHTML.md), [self-review](Docs/Review-M6.md)
and [M6 acceptance](Docs/M6Acceptance.md) describe the supported contract.

For the accepted M6 snapshot, the 42-case Linux ARM64 stage/RSS/allocation
matrix meets the reviewed post-baseline budgets. Mixed 1 MB/5 MB inputs reach
first HTML in about half the parse-plus-full-output time on that host. Full parsing still precedes
output; giant blocks remain indivisible and no general peak-memory reduction
is established. The [0.6.0 installation](#installation) includes progressive output.

Next is **M7: general speed and hardening**, beginning with reproducible
adversarial/mutation coverage and a measured investigation of remaining costs.
API/DocC/1.0 completion stays **M8**. Full benchmark and long fuzzing execution
follow the existing approval requirement.

The initial `feature/m7-hardening` step adds bounded deterministic mutation
coverage: 1,024 profile/input combinations and 24 depth cases across strict,
GFM and selected M5 configurations. At that preparation checkpoint, all 245
tests pass in Debug and Release on macOS and native Linux ARM64/x64 with
Swift 6.4.2. The owner-approved [72-case Apple M2 baseline](Docs/Validation/M7/baseline-2026-11-21.md)
passes all six parser/C budgets and nine frozen M2 checks. The separate
[72-case Raspberry Pi baseline](Docs/Validation/M7/linux-arm64-2026-11-21.md)
satisfies all six same-host C ratios, with high-load/sample-count limitations.
The [direct x64 baseline](Docs/Validation/M7/linux-x64-2026-11-21.md) also
passes all six C ratios: GFM is within about 7% of C on this corpus; CommonMark
is 33–62% slower and remains the parser profiling priority toward parity.

The [first measured optimization](Docs/Validation/M7/inline-scratch-2026-11-21.md)
reuses inline scratch buffers: CommonMark time improves 15–17% on M2 and 6–7%
on x64; the 1 MB Mac allocation profile records about 48% fewer requests.
Current macOS/x64 Debug/Release suites and Release C-reference tests pass;
CommonMark remains 24–54% slower than C on x64. Candidate ARM64/minimum-compiler
checks, fresh progressive resource measurements, larger-input scaling
and broader fuzzing remain open. See [M7 hardening](Docs/M7Hardening.md)
for scope, reproduction and remaining portability/performance gates.

The separate [extension/hostile-input matrix](Docs/M7HardeningWorkloads.md)
completes **69/69 Mac cases in 5 min 26 s**, at 16/64/256 KiB with syntax
details off/on, composed M5 rendering and informational C controls. The
[scaling report](Docs/Validation/M7/hardening-scaling-2026-11-22.md) observes
approximately proportional timing, while identifying expensive deep-emphasis
tokens, large bracket buffers and malformed-byte processing for profiling.
The preparation's ten Release tool tests and 36 Python tests in both modes
remain valid for the unchanged harness. New-harness Linux/minimum-compiler
validation, resource/fuzz work and M7 acceptance remain pending; existing
reference cases and budgets are unchanged.

Merged PR #17 (`0434ff5`) adds an optional English/German lookup for native
findings and fix titles on `main`, with a documented
[message-key/argument catalogue](Docs/NativeAnalysisMessages.md). The v0.4.0
release still supplies English defaults only.

Merged PR #18 (`4397819`) adds exact quote/list marker tokens on `main`;
see [ContainerMarkers](Docs/ContainerMarkers.md). Its PR and merged-main CI
pass on macOS and Linux. These features are included in v0.5.0;
M5 is now functionally accepted across the separately merged steps below.

Merged PR #19 (`4b0f105`) adds opt-in raw YAML/TOML front matter on `main`
through the existing extension API; see [FrontMatter](Docs/FrontMatter.md).
Its PR and merged-main CI pass on macOS and Linux.

Merged PR #20 (`a6a2da6`) adds named footnotes, source-spelled tokens,
numbering and a separate HTML renderer with backlinks on `main`; see
[Footnotes](Docs/Footnotes.md). PR and merged-main CI pass on macOS and Linux.

Merged PR #21 (`6f166b7`) adds opaque inline/display/fenced TeX on `main`
with exact provenance and caller-owned rendering; see [Math](Docs/Math.md).
PR and merged-main CI pass on macOS and Linux.

Merged PR #22 (`c9543fe`) adds GitHub-style alerts and
Obsidian-style callouts with parsed titles, folding and an optional HTML
recipe; see [Admonitions](Docs/Admonitions.md). PR and merged-main CI pass
on macOS and Linux. [M5 functional acceptance](Docs/M5Acceptance.md) is
complete. PR #23 (`2d8ecef`) prepared the published v0.5.0 preview with
[release notes](Docs/Releases/0.5.0.md), result identity `0.5.0` and
[release validation](Docs/Validation/Release/0.5.0.md).

Requires **Swift 6.2 or later**. The current provisional Apple minimums are
macOS 15, iOS 18 and visionOS 2; Linux is supported. The repository is public
and can be fetched over HTTPS without GitHub authentication. Consumers pin
version tags through Swift Package Manager; no binary release assets or package
registry are required.

## Installation

Pin the **0.6.0 preview release** with Swift Package Manager:

```swift
.package(url: "https://github.com/kerker00/GMSetzer.git", exact: "0.6.0")
```

Add `.product(name: "GMSetzer", package: "GMSetzer")` to your target's
dependencies. APIs may change before 1.0. GitHub provides source ZIP and tar.gz
archives; no binary assets are uploaded. See the
[release notes](Docs/Releases/0.6.0.md) and
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
  GFM features, custom block/inline rules and transforms. The first M5
  steps add raw YAML/TOML front matter, named footnotes and opaque TeX syntax
  on `main`, alongside alerts and callouts. Further dialects
  follow separately.
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
  English defaults remain available, with an optional English/German lookup
  on `main` since PR #17. Original quote/list marker ranges are on `main`
  since PR #18; these additions are included in 0.5.0. Consumers
  choose editor colors themselves.

## Documentation

- [Docs/Plan.md](Docs/Plan.md) – requirements, decisions, architecture,
  milestones and licence rules. Start here.
- [Docs/ProgressiveHTML.md](Docs/ProgressiveHTML.md) – prepared structural HTML,
  pull consumption/cancellation, complete-document context and explicit fallbacks.
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
- [Docs/NativeAnalysisMessages.md](Docs/NativeAnalysisMessages.md) – stable
  finding/fix message keys and arguments, optional English/German text lookup
  and fallback behavior (since 0.5.0).
- [Docs/ContainerMarkers.md](Docs/ContainerMarkers.md) – original quote/list
  marker ranges, owners, extension boundaries and annotation-mode checks
  (since 0.5.0).
- [Docs/M4GFM.md](Docs/M4GFM.md) – merged GFM profiles, switches, source ranges,
  conformance and measurements.
- [Docs/HTMLReferences.md](Docs/HTMLReferences.md) – HTML policies, multiline
  definitions, opt-in editor provenance and validation.
- [CONTRIBUTING.md](CONTRIBUTING.md) – workflow and rules.

## Modules

M5 selection/rendering examples are documented in [FrontMatter](Docs/FrontMatter.md),
[Footnotes](Docs/Footnotes.md), [Math](Docs/Math.md) and
[Admonitions](Docs/Admonitions.md); these additions are not part of v0.4.0.

| Module | Implemented | Planned |
| --- | --- | --- |
| `SetzerSyntax` | Validated block/inline tree, source ranges/tokens, parent/offset/outline index, position conversion, diagnostic/fix values | Additional query conveniences |
| `SetzerParser` | Block/inline parser, custom rules/children, pre/post transforms and profiles | Additional dialect syntax |
| `SetzerExtensions` | GFM profile; raw YAML/TOML front matter; named footnotes; opaque TeX; alerts/callouts | Further dialects |
| `SetzerHTML` | CommonMark/GFM HTML, source anchors and safe defaults; prepared/grouped output with explicit fallbacks | Further rendering conveniences |
| `SetzerAnalysis` | Three optional native rules over the existing document | Broader rule catalogue |
| `GMSetzer` | Imports the five modules above; composed footnote HTML and admonition HTML recipe | Additional convenience APIs |

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
  swift-markdown: see the build/measurement instructions in
  [Docs/Benchmarks.md](Docs/Benchmarks.md), including the direct Linux driver.
- [M1 measurements](Docs/M1Measurements.md) describe the recorded block-only
  baseline, optional syntax costs and local performance gate. Run
  `python3 -I Scripts/check_benchmark_budget.py <results.log>` against a full
  Markdown benchmark export to check matching C/absolute parse budgets.

## Licence

GMSetzer is released under the [MIT licence](LICENSE). Third-party material
and its licences are listed in [NOTICE](NOTICE); the specification examples
used as test data are licensed CC-BY-SA 4.0 and are not part of the library.
