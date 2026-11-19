# GMSetzer

A Markdown parser written in pure Swift: CommonMark and GitHub Flavored
Markdown with switchable extensions, exact source positions and an HTML
renderer. No C, no Rust, no JavaScript, no runtime dependencies — it builds
wherever Swift runs, including Linux.

> **Status:** milestone M0 (scaffold), reviewed and corrected. The parser
> emits only a document root and the renderer emits an empty string. M1 has
> not started. The repository stays private until M2 and owner approval.

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

## Documentation

- [Docs/Plan.md](Docs/Plan.md) – requirements, decisions, architecture,
  milestones and licence rules. Start here.
- [Docs/Benchmarks.md](Docs/Benchmarks.md) – measurements against cmark-gfm.
- [Docs/Review-M0.md](Docs/Review-M0.md) – review findings and corrections.
- [CONTRIBUTING.md](CONTRIBUTING.md) – workflow and rules.

## Modules

| Module | Contents |
| --- | --- |
| `SetzerSyntax` | Syntax tree, source ranges, position conversion, outline queries |
| `SetzerParser` | Block and inline parser, extension API, profiles |
| `SetzerExtensions` | GFM, footnotes, front matter, math, alerts and callouts |
| `SetzerHTML` | HTML renderer with block anchors |
| `GMSetzer` | Imports all of the above |

```swift
import GMSetzer

let document = MarkdownParser().parse("# Hello")
let html = HTMLRenderer().render(document)
```

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
- `GMSETZER_SPEC_DIAGNOSTICS=1 swift test --filter SpecTests` also prints each
  mismatching example with source, expected HTML and actual HTML as JSON.
- `Tools/` is a separate package for benchmarks against cmark-gfm in C and
  swift-markdown: `cd Tools && swift package benchmark`.

## Licence

GMSetzer is released under the [MIT licence](LICENSE). Third-party material
and its licences are listed in [NOTICE](NOTICE); the specification examples
used as test data are licensed CC-BY-SA 4.0 and are not part of the library.
