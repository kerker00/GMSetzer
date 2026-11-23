# Documentation

## Use the package

- [Installation and quick start](../README.md#usage)
- [DocC guides and API reference](../Sources/GMSetzer/GMSetzer.docc/GMSetzer.md)
- [1.0 preparation](M8Readiness.md) and [source compatibility contract](APIStability.md)
- [Development roadmap](Roadmap.md)
- [Front matter](FrontMatter.md), [footnotes](Footnotes.md), [math](Math.md) and [alerts/callouts](Admonitions.md)
- [Progressive HTML](ProgressiveHTML.md) and [safe HTML policies](HTMLReferences.md)
- [Source positions and syntax tree](SyntaxTree.md), [editor services](M3EditorServices.md) and [extension configuration](ExtensionContracts.md)
- [Performance reports](Benchmarks.md), [published releases](https://github.com/kerker00/GMSetzer/releases) and [development status](Status.md)

## Architecture and development records

- [Docs/Plan.md](Plan.md) – requirements, decisions, architecture,
  milestones and licence rules. Start here.
- [Docs/ProgressiveHTML.md](ProgressiveHTML.md) – prepared structural HTML,
  pull consumption/cancellation, complete-document context and explicit fallbacks.
- [Docs/Benchmarks.md](Benchmarks.md) – measurements against cmark-gfm.
- [Docs/Portability.md](Portability.md) – Swift 6.2 tests, Linux ARM64
  execution evidence, SDK selection, span availability and remaining coverage.
- [Docs/Review-M0.md](Review-M0.md) – review findings and corrections.
- [Docs/M1Acceptance.md](M1Acceptance.md) – technical decision, measured
  M2 allowance, portability matrix and acceptance evidence.
- [Docs/Review-M1.md](Review-M1.md) – M1 architecture, code, QA and
  extensibility review with recommendations before M2.
- [Docs/SyntaxTree.md](SyntaxTree.md) – implemented tree/extension contract,
  example ranges and the implemented block contracts.
- [Docs/ExtensionContracts.md](ExtensionContracts.md) – shared configuration,
  container/inline rules, transforms, token ownership and hook context.
- [Docs/M2Inlines.md](M2Inlines.md) – inline API, source tokens, diagnostic/fix
  values, current validation and remaining performance acceptance.
- [Docs/BlockPhases.md](BlockPhases.md) – extracted block-phase boundaries,
  full Linux regression suite and performance countermeasurement before registry work.
- [Docs/EditorAnalysis.md](EditorAnalysis.md) – syntax, native lint and
  editor-diagnostic contracts, including planned extensions and acceptance gates.
- [Docs/M3EditorServices.md](M3EditorServices.md) – implemented position,
  outline, HTML and native analysis APIs and their validation limits.
- [Docs/NativeAnalysisMessages.md](NativeAnalysisMessages.md) – stable
  finding/fix message keys and arguments, optional English/German text lookup
  and fallback behavior (since 0.5.0).
- [Docs/ContainerMarkers.md](ContainerMarkers.md) – original quote/list
  marker ranges, owners, extension boundaries and annotation-mode checks
  (since 0.5.0).
- [Docs/M4GFM.md](M4GFM.md) – merged GFM profiles, switches, source ranges,
  conformance and measurements.
- [Docs/HTMLReferences.md](HTMLReferences.md) – HTML policies, multiline
  definitions, opt-in editor provenance and validation.
- [CONTRIBUTING.md](../CONTRIBUTING.md) – workflow and rules.

## Modules

M5 selection/rendering examples are documented in [FrontMatter](FrontMatter.md),
[Footnotes](Footnotes.md), [Math](Math.md) and
[Admonitions](Admonitions.md). These features are included in the published 0.6.0 preview.

| Module | Implemented | Planned |
| --- | --- | --- |
| `SetzerSyntax` | Validated block/inline tree, source ranges/tokens, parent/offset/outline index, position conversion, diagnostic/fix values | Additional query conveniences |
| `SetzerParser` | Block/inline parser, custom rules/children, pre/post transforms and profiles | Additional dialect syntax |
| `SetzerExtensions` | GFM profile; raw YAML/TOML front matter; named footnotes; opaque TeX; alerts/callouts | Further dialects |
| `SetzerHTML` | CommonMark/GFM HTML, source anchors and safe defaults; prepared/grouped output with explicit fallbacks | Further rendering conveniences |
| `SetzerAnalysis` | Three optional native rules over the existing document | Broader rule catalogue |
| `GMSetzer` | Imports the five modules above; composed footnote HTML and admonition HTML recipe; M8 adds validated `MarkdownHTML` convenience rendering | Final 1.0 review |


For installation and a short example, see the [package README](../README.md).
Development history is in [Status](Status.md); measurements retain their
configuration/source identities in [Benchmarks](Benchmarks.md).
