# GMSetzer

A pure Swift Markdown parser with CommonMark, GitHub Flavored Markdown,
optional extensions, exact source positions and safe-default HTML output.
The library has no runtime dependencies and supports Linux.

[Releases](https://github.com/kerker00/GMSetzer/releases) ·
[Documentation](Docs/README.md) · [Development status](Docs/Status.md)

Requires **Swift 6.2+**. Current provisional Apple minimums: macOS 15,
iOS 18 and visionOS 2. APIs may change before 1.0.

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

The **unreleased M7 candidate**, measured on Apple M2 / macOS 27.0.1 /
Swift 6.4.2 in Release mode, parses the same `mixed-v1` documents as follows.
These are median parse times, including parser/tree construction and teardown;
HTML rendering is outside the measurement; GMSetzer syntax-token collection is off.

| Input | GMSetzer CommonMark | cmark-gfm C core | swift-markdown |
| --- | ---: | ---: | ---: |
| 100 KB | 2.30 ms | 1.68 ms | 22.63 ms |
| 1 MB | 24.17 ms | 18.37 ms | 223.22 ms |

GMSetzer and C enable source positions. `swift-markdown` uses different default
options and includes its Swift tree; it is a contextual comparison. The rows
are not measurements of the published 0.6.0 release or a general speed guarantee.
Actual inputs are 100,284 and 1,000,100 UTF-8 bytes. See
[measurement conditions and raw evidence](Docs/Validation/M7/utf8-2026-11-22.md#full-mac-control-refresh),
[native x64 results](Docs/Validation/M7/final-x64-2026-11-22.md) and
[all benchmark reports](Docs/Benchmarks.md).

## What it provides

- CommonMark and GFM tables, task lists, strikethrough, extended autolinks and
  rendering policies, tested against all 652 CommonMark / 672 pinned GFM examples.
- Selectable front matter, footnotes, alerts, callouts and opaque TeX syntax.
  Math rendering is caller-owned; no TeX engine is included. See the
  [extension and rendering examples](Docs/README.md#modules).
- Original UTF-8 bytes, immutable `Sendable` trees, optional syntax tokens,
  byte/UTF-16 position conversion, parent/caret queries and heading outlines.
- Three optional native analysis rules, portable findings and suggested edits,
  with English/German message lookup. See [editor services](Docs/M3EditorServices.md).
- Custom block/inline rules, transforms and HTML hooks through the
  [extension API](Docs/ExtensionContracts.md).

`parse(bytes:)` preserves malformed UTF-8 in the original source and replacement-
decodes literals. A leading UTF-8 BOM remains in the source and byte offsets.
The library is independent of application sessions, UI frameworks and consumer
checkouts. `import GMSetzer` exposes all five modules; each is also available
separately. See the [syntax/source contract](Docs/SyntaxTree.md).

## Progressive HTML

Prepare structural HTML groups once and render requested groups with complete
Markdown context, including references and footnotes. Full parsing precedes
output; this is not input streaming. Giant blocks remain indivisible, raw HTML
and document-order hooks can require a whole-document fallback, and no general
peak-memory reduction is established. See the [API and limits](Docs/ProgressiveHTML.md).

## Installation

The latest published source-only preview is **[v0.6.0](https://github.com/kerker00/GMSetzer/releases/tag/v0.6.0)**.
Pin it with Swift Package Manager:

```swift
.package(url: "https://github.com/kerker00/GMSetzer.git", exact: "0.6.0")
```

Add `.product(name: "GMSetzer", package: "GMSetzer")` to your target's
dependencies. GitHub provides source ZIP/tar.gz archives; no binary assets or
package registry are required. See [release notes](Docs/Releases/0.6.0.md).
The M7 performance candidate is not a published 0.7 release; its
[readiness report](Docs/M7Readiness.md) records validation and remaining scope.

## Development

Run `swift test` for library/specification tests and
`python3 -I -m unittest discover -s Scripts` for offline development-script tests.
Reference comparisons and benchmarks live in the separate `Tools/` package;
their dependencies do not reach library users. Follow
[CONTRIBUTING](CONTRIBUTING.md) and the [measurement instructions](Docs/Benchmarks.md)
before full benchmark or long-test runs.

## Licence

[MIT](LICENSE). Third-party notices and test-fixture licences are in [NOTICE](NOTICE).
The specification examples are CC-BY-SA 4.0 test data, not part of the library.
