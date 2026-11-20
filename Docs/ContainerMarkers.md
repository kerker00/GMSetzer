# Quote and list marker provenance

Merged in PR #18 (`4397819`), implementation `c58b6ac` based on `57d13d8`
after localization PR #17. Available on `main`, not yet in a versioned release.
This completes the marker step toward 0.5; M5's additional syntax remains open.

## Contract

`MarkdownParser(collectSyntaxDetails: true)` records these additional roles in
`Document.tokens`. They use original, half-open UTF-8 byte ranges, like all
other `SyntaxToken` values. Consumers map them through `SourceIndex` when
they need UTF-16 editor ranges.

| Role | Source spelling | Owner before consumer transforms |
| --- | --- | --- |
| `core.blockQuote.marker` | Exactly one explicit `>` byte; no indentation, optional padding or line ending | The quote whose prefix was matched or opened on that physical line |
| `core.list.marker` | One `-`, `+` or `*`, or every original ordered-list digit plus its `.` / `)` delimiter | The individual `listItem` or GFM `taskListItem`, not the enclosing list |

There is one quote token for each explicitly consumed quote prefix, including
prefixed blank lines and multiple nested prefixes on the same physical line.
Lazy continuation lines without `>` do not receive a synthetic token. List
markers occur on each item's opening line; continuation indentation is not a
list marker. An empty item's existing marker is still syntax. Original digit
spelling is retained, including leading zeros; the list's semantic integer
start value is not used to reconstruct it.

Tabs, partial-tab virtual spaces and enclosing prefixes do not enlarge the
marker. Leading BOM bytes and CRLF remain part of the original snapshot and
offsets, but are not marker bytes. Recognition still follows the selected
rules, precedence and depth limits. Disabled rules, overflow literal fallback,
escaped text, indented/fenced code content, thematic breaks and setext
underlines do not acquire false list/quote roles. An explicit parent quote
prefix around fenced code is still a quote marker.

GFM checkboxes keep their separate `gfm.tasklist.marker` role. A recognised
task item's bullet and checkbox share its item owner, but have separate ranges.
Task-list semantics are unchanged by this provenance step.

Tokens follow the existing emission-order contract; the array is not globally
sorted by source position. Core subtree imports and inline rebuilding remap
owners into the returned document. A transform that converts a quote into a
custom alert/callout can preserve its quote-marker provenance; the owner's
final kind can then be custom. Owners are indices in this snapshot only.

## Optional collection and extension boundaries

```swift
import GMSetzer

let document = MarkdownParser(collectSyntaxDetails: true)
    .parse("> - item\n>   continuation\n")
let positions = SourceIndex(document)
let markerRanges = (document.tokens ?? [])
    .filter { $0.role == "core.blockQuote.marker" || $0.role == "core.list.marker" }
    .compactMap { positions.utf16Range(for: $0.range) }
```

Only actual accepted prefixes produce tokens. Callback lookahead and
speculative rule matching remain free of token side effects. If an accepted
extension consumes several lines and skips the normal per-line parser loop,
the core collects enclosing quote prefixes for those consumed continuation
lines after match validation. Both custom leaves and parsed-child containers
are covered. Projected child parsers collect their own nested marker syntax
over the same original source.

Collection defaults to off and leaves `tokens == nil`. Enabling it does not
change the source, semantic nodes, source segments, diagnostics or HTML. It
does not add a parsing rule, editor dependency, theme or runtime dependency.
Parser/provider development identity is `0.5.0-dev` for the new provenance;
there is no new release tag.

## Validation

`ContainerMarkerTests` checks exact spelling, owner identity, nested explicit
and lazy quotes, blank prefixes, leading-zero ordered lists, partial tabs,
BOM/Unicode/CRLF and UTF-16 offsets, task checkboxes, literal/disabled/depth
fallbacks, projected child imports and transforms. A regression test covers
multi-line custom leaves/containers and non-consuming lookahead. Deterministic
arbitrary-byte cases compare annotated/unannotated trees and diagnostics in
CommonMark and GFM, including invalid UTF-8/NUL and nesting limits.

`SpecTests.syntaxCollectionPreservesEverySpecificationTreeAndHTML` additionally
checks all 1,324 pinned specification inputs with collection on and off:
source, complete nodes/segments, diagnostics and fallback metadata are equal;
annotated HTML remains exact and marker tokens are not duplicated. No fixture
or protected example ID is changed. The pre-existing extension-token test now
locates its own role explicitly because earlier enclosing markers can precede it.

Validation on 20 November 2026, branch based on `57d13d8`:

| Platform / compiler | Commands | Result |
| --- | --- | --- |
| macOS ARM64 / Apple Swift 6.4.2, Xcode 27.2 | `swift test`; `swift build -c release` | All 135 tests pass (127 library tests, 8 spec/fixture tests); optimized build passes |
| macOS ARM64 / Swift 6.2 | `swift test --disable-xctest` with the SDK/Testing setup in [Portability](Portability.md) | All 135 tests pass |
| Existing Linux x86-64 host / Swift 6.4.2 | `swift test`; `swift build -c release` | All 135 tests and optimized build pass |

All runs retain 652/652 CommonMark and 672/672 GFM examples. The multi-line
extension regression first reproduced the missing consumed-line marker for
both a parsed-child container and an opaque leaf, then passed after the
accepted-prefix collection fix. The final full suites include that fix.

macOS runs used isolated scratch/cache/config/security/module paths and
`--disable-sandbox`. Linux ran a source-only package copy in a task-specific
temporary directory; no consumer checkout or new execution environment was
needed. Twelve tests were added. Local script tests were not repeated because no
scripts changed. No fresh benchmark/reference series, performance claim, consumer
editor/device acceptance, version tag or release is part of this step.

Subsequent [PR CI](https://github.com/kerker00/GMSetzer/actions/runs/44789966780)
and [merged-main CI](https://github.com/kerker00/GMSetzer/actions/runs/44792200115)
both pass on macOS and Linux, including library/specification tests, optimized
builds and the offline Python checks. The Linux job uses the minimum Swift 6.2
compiler; the macOS job uses Xcode 26.2. The merged feature branch was removed
locally and remotely; no additional worktree existed.
