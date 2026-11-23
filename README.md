# GMSetzer

[![Release](https://img.shields.io/github/v/release/kerker00/GMSetzer)](https://github.com/kerker00/GMSetzer/releases/latest)
[![CI](https://github.com/kerker00/GMSetzer/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/kerker00/GMSetzer/actions/workflows/ci.yml)
[![Swift](https://img.shields.io/badge/Swift-6.2%2B-F05138?logo=swift&logoColor=white)](Package.swift)
[![SwiftPM](https://img.shields.io/badge/SwiftPM-compatible-brightgreen)](Package.swift)
[![License](https://img.shields.io/github/license/kerker00/GMSetzer)](LICENSE)
[![CommonMark](https://img.shields.io/badge/CommonMark-652%2F652-brightgreen)](Tests/SetzerSpecTests/Resources/README.md)
[![GFM](https://img.shields.io/badge/GFM-672%2F672-brightgreen)](Tests/SetzerSpecTests/Resources/README.md)

A pure Swift Markdown parser with CommonMark, GitHub Flavored Markdown,
optional extensions, exact source positions and safe-default HTML output.
The library has no runtime dependencies and supports Linux.

Developed by **Markus Müller** with assistance from **Claude (Anthropic)**
and **Codex (OpenAI)**.

[Releases](https://github.com/kerker00/GMSetzer/releases) ·
[Documentation](Docs/README.md) · [Development status](Docs/Development.md#current-state)

Requires **Swift 6.2+**. Declared Apple deployment minimums: macOS 15,
iOS 18 and visionOS 2. Linux builds are verified on x86_64 and aarch64
([record](Docs/Validation/Release/1.0.0.md#native-platform-builds-after-publication-23-november-2026)). The [1.x source-compatibility policy](Docs/README.md#source-compatibility) applies.

## Usage

```swift
import GMSetzer

let source = "# Hello\n\n- [x] Built with Swift"
let document = MarkdownParser(profile: .gfm).parse(source)
let html = HTMLRenderer().render(document)
```

Raw HTML is escaped by default, HTML comments are omitted, and dangerous URL
schemes are neutralised. Allowing raw HTML is explicit; it does not sanitise
HTML supplied by your own renderer hooks.

## Performance

The **M7 measurement snapshot** (runtime `f2e0a0e`), measured on
22 November 2026 on Apple M2 / macOS 27.0.1 / Swift 6.4.2 in Release mode,
parses the same `mixed-v1` documents as follows.
These are median parse times, including parser/tree construction and teardown;
HTML rendering is outside the measurement; GMSetzer syntax-token collection is off.

| Input | GMSetzer CommonMark | cmark-gfm C core | swift-markdown |
| --- | ---: | ---: | ---: |
| 100 KB | 2.13 ms | 1.68 ms | 24.41 ms |
| 1 MB | 23.13 ms | 18.76 ms | 249.82 ms |

GMSetzer and C enable source positions. `swift-markdown` uses different default
options and includes its Swift tree; it is a contextual comparison. The rows
predate 1.0 release preparation and are not release-specific timings or a general speed guarantee.
Actual inputs are 100,284 and 1,000,100 UTF-8 bytes. See
[measurement conditions and native x64 results](Docs/Validation/M7/inline-input-2026-11-22.md#completion),
[same-run raw timings](Docs/BenchmarkData/m7-inline-input-2026-11-22/mac-parser-b/receipt.json) and
[all benchmark reports](Docs/Development.md#performance-measurements). A
[23 November control check](https://github.com/kerker00/GMSetzer/blob/418882ff66357ce17e968d389b62d77296d665db/Docs/Benchmarks.md#readme-control-check-23-november-2026)
records 2.14 / 22.33 ms for GMSetzer on the same runtime sources.

## What it provides

- CommonMark and GFM tables, task lists, strikethrough, extended autolinks and
  rendering policies, tested against all 652 CommonMark / 672 pinned GFM examples.
- Selectable front matter, footnotes, alerts, callouts and opaque TeX syntax.
  Math rendering is caller-owned; no TeX engine is included. See the
  [extension and rendering examples](Docs/README.md#optional-syntax).
- Original UTF-8 bytes, immutable `Sendable` trees, optional syntax tokens,
  byte/UTF-16 position conversion, parent/caret queries and heading outlines.
- Three optional native analysis rules, portable findings and suggested edits,
  with English/German message lookup. See [editor services](Docs/README.md#position-and-tree-queries).
- Custom block/inline rules, transforms and HTML hooks through the
  [extension API](Docs/README.md#custom-extensions).

`parse(bytes:)` preserves malformed UTF-8 in the original source and replacement-
decodes literals. A leading UTF-8 BOM remains in the source and byte offsets.
The library is independent of application sessions, UI frameworks and consumer
checkouts. `import GMSetzer` exposes all five modules; each is also available
separately. See the [syntax/source contract](Docs/README.md#tree-and-source-coordinates).

## Progressive HTML

Prepare structural HTML groups once and render requested groups with complete
Markdown context, including references and footnotes. Full parsing precedes
output; this is not input streaming. Giant blocks remain indivisible, raw HTML
and document-order hooks can require a whole-document fallback, and no general
peak-memory reduction is established. See the [API and limits](Docs/README.md#progressive-html).

## Installation

The first stable source release is **[GMSetzer 1.0.0](https://github.com/kerker00/GMSetzer/releases/tag/v1.0.0)**.
Use Swift Package Manager:

```swift
.package(url: "https://github.com/kerker00/GMSetzer.git", from: "1.0.0")
```

Add `.product(name: "GMSetzer", package: "GMSetzer")` to your target, or choose
one of the five lower-level products. GitHub provides automatic source ZIP and
tar.gz downloads; no registry or binary assets are required.
See the [release notes](Docs/Releases/1.0.0.md),
[executed release checks](Docs/Validation/Release/1.0.0.md),
[API contract](Docs/README.md#source-compatibility) and
[development roadmap](Docs/Development.md#roadmap).

## Development

Run `swift test` for library/specification tests and
`python3 -I -m unittest discover -s Scripts` for offline development-script tests.
Reference comparisons and benchmarks live in the separate `Tools/` package;
their dependencies do not reach library users. Follow
[CONTRIBUTING](CONTRIBUTING.md) and the [measurement instructions](Docs/Development.md#performance-measurements)
before full benchmark or long-test runs.

Build the six DocC archives with `python3 -I Scripts/build_documentation.py`.
Check public source compatibility with
`python3 -I Scripts/check_public_api.py --graph-dir .build/documentation/symbolgraph`.

## Licence

[MIT](LICENSE). Third-party notices and test-fixture licences are in [NOTICE](NOTICE).
The specification examples are CC-BY-SA 4.0 test data, not part of the library.
