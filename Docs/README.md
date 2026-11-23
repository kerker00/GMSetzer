# GMSetzer package guide

This is the current usage and source-contract guide for the six library products.
For requirements, architecture, roadmap, validation and publication, read
[Development](Development.md). The [DocC catalog](../Sources/GMSetzer/GMSetzer.docc/GMSetzer.md)
provides task guides and individual symbol references.

- [Installation and quick start](#installation-and-quick-start)
- [Source compatibility](#source-compatibility)
- [Tree and source coordinates](#tree-and-source-coordinates)
- [Position and tree queries](#position-and-tree-queries)
- [Syntax tokens](#syntax-tokens)
- [Safe HTML and hooks](#safe-html-and-hooks)
- [Progressive HTML](#progressive-html)
- [GFM](#gfm)
- [Optional syntax](#optional-syntax)
- [Custom extensions](#custom-extensions)
- [Analysis and suggested fixes](#analysis-and-suggested-fixes)
- [Native message catalogue](#native-message-catalogue)

## Installation and quick start

Requires Swift 6.2+, with declared deployment minimums macOS 15, iOS 18 and
visionOS 2; Linux is supported. The package has no runtime dependencies.
The public `v1.0.0` tag is available to SwiftPM; its GitHub release is a reviewed
draft awaiting publication. The latest published GitHub preview remains 0.6.0.
The examples below describe the 1.0 API. The [release checklist](Development.md#release-checklist)
distinguishes tagging from release publication.

Depend on the tagged 1.x series:

```swift
.package(url: "https://github.com/kerker00/GMSetzer.git", from: "1.0.0")
```

Select `.product(name: "GMSetzer", package: "GMSetzer")` for the umbrella
product, or depend on individual products listed in the
[module graph](Development.md#architecture). Older previews require their matching
API; `MarkdownHTML` is not part of the 0.6.0 tag.

```swift
import GMSetzer

let parser = MarkdownParser(profile: .gfm, collectSyntaxDetails: true)
let html = try MarkdownHTML.render("# Hello\n\n- [x] Done", parser: parser)
let document = parser.parse("# Hello\n\nText with *emphasis*.")
let outline = DocumentIndex(document).outline()
```

`MarkdownHTML.render` accepts a String or original bytes and validates the
supplied parser configuration before parsing. It composes standard HTML for
selected footnotes, alerts and callouts. Front matter keeps its escaped fallback
unless a caller hook hides it; math stays opaque. The lower-level
`MarkdownParser.parse` and `HTMLRenderer.render` APIs remain available.

## Source compatibility

### Supported surface

All six public library products remain supported: `GMSetzer`, `SetzerSyntax`,
`SetzerParser`, `SetzerExtensions`, `SetzerHTML` and `SetzerAnalysis`.
`GMSetzer` continues re-exporting the five lower-level modules. None acquires
a runtime dependency, platform UI framework, file/network access or consumer
checkout requirement. Swift 6.2 and the existing declared Apple deployment
minimums (macOS 15, iOS 18, visionOS 2) are the declared 1.0 floor; Linux remains
supported. Actual runtime/minimum-compiler evidence has its own recorded scope.

The frozen source API inventory is [API/1.0.0.json](API/1.0.0.json). Its module
records are exactly equal to the [review inventory](API/1.0-candidate.json),
which remains unchanged as historical evidence. Its 611 export records include 610 source-declared public symbols
and one presentation-only `extension Profile` grouping node. Checks normalise
that grouping node while retaining the actual `Profile` type, the GFM member
and declared conformances. The baseline is preserved without source paths or line numbers.
Compiler-synthesised declarations and re-export duplicates are not counted as
new owned declarations. This is the compatibility baseline used by release
and subsequent 1.x CI.

### 1.x policy

- Preserve public source signatures, module/product names, existing
  conformances, documented coordinate/ownership contracts and safe defaults.
- Keep CommonMark and GFM selections explicit. New grammar is opt-in; passing
  an extension implementation alone does not activate it.
- Preserve named built-in extension/rule/token identifiers and the documented
  native-message key/argument catalogue. Default finding text can be corrected
  or translated; consumers identify findings through keys, not English strings.
- Use a major release for source-breaking signature/default changes, removals,
  newly required throwing behaviour, tighter documented preconditions or enum
  changes that invalidate exhaustive client switches.
- Correct parsing/specification and safety bugs in compatible releases, with
  regression tests and release notes. Exact incidental HTML whitespace and
  internal node ordering are not a cross-version serialisation promise.

This is source compatibility, not binary ABI, stable memory layout, persistent
tree schemas, stable hash values, cross-snapshot node IDs or fixed performance.
Public enums are not an invitation to add cases silently in a patch release.

## Tree and source coordinates

### Values and construction

`Document` owns the original `[UInt8]`, an immutable `[Node]` and parse
diagnostics, optional generic `tokens`, plus sparse `customLeafFallbacks` keyed
by custom leaf index. It is
`Sendable`. Root index is always zero; indices belong to
one document snapshot, not to later parses. Consumers own snapshot revisions
and configuration fingerprints outside this module.

`Node.data` is a typed `NodeData` enum. `Node.kind` is derived from it, so a
heading cannot accidentally carry code-block data. `NodeKind` names identify
renderer hooks and custom kinds; they do not replace typed built-in payloads.

| Current payload | Children | Meaning |
| --- | --- | --- |
| `document` | Block nodes | Root covering the entire original input |
| `paragraph` | Inline nodes | A leaf block's inline content |
| `heading(level:)` | Inline nodes | ATX/setext heading, level 1 through 6 |
| `text(String)` | None | Decoded text; source range retains escapes/entities |
| `softBreak` | None | A physical line break between inline content lines |
| `hardBreak` | None | Backslash or two-space line break |
| `code(String)` | None | Normalised inline code literal |
| `emphasis`, `strong` | Inline nodes | Resolved CommonMark delimiter span |
| `link(destination:title:)`, `image(destination:title:)` | Inline nodes | Decoded destination/title and label/alt children |
| `htmlInline(String)` | None | Source HTML with normalised line endings; escaped by default |
| `thematicBreak` | None | Horizontal rule |
| `codeBlock(info:literal:)` | None | Optional fence info and literal code |
| `referenceDefinition` | None | Raw label, destination and optional title; emits no HTML |
| `htmlBlock(HTMLBlock)` | None | CommonMark start/end class and normalised literal; escaped by default |
| `blockQuote` | Block nodes | Quoted blocks, including nested containers |
| `list(ListAttributes)` | List items only | Bullet marker or ordered start/delimiter, plus tightness |
| `listItem` | Block nodes | Item content; its range includes its own marker |
| `taskListItem(checked:)` | Block nodes | GFM task list item; a list item with a checkbox state |
| `table(TableAttributes)` | Table rows only | GFM table; one alignment per column, the first row is the header |
| `tableRow(isHeader:)` | Table cells only | One table line; the delimiter row has no node |
| `tableCell(alignment:)` | Inline nodes | Raw bytes between pipes; text excludes escaping backslashes |
| `strikethrough` | Inline nodes | GFM tilde span |
| `custom(kind:role:attributes:)` | See below | Namespaced extension kind with portable data |

`SyntaxValue` supports strings, integers, booleans, arrays and objects. A custom
inline node can contain inline children; a custom block can contain block or
inline children, with list items allowed only under lists. Extension-specific restrictions are the extension's
responsibility. A built-in leaf cannot have children.

`DocumentBuilder` appends children to existing parents in constant time.
`finish` completes an open node's data/range while retaining its child/sibling
links; incomplete values never escape as a `Document`.
`build()` performs one iterative validation. `Document(source:nodes:)` also
validates externally assembled trees and throws `DocumentError` for invalid
root/ranges, indices, content models, heading levels, list markers/starts, segments, reserved
custom kind names, repeated nodes, overlapping siblings or unreachable nodes.
Fallback entries must refer to existing custom nodes without children;
otherwise validation throws `DocumentError.invalidFallback(node:)`. Builder
`append` accepts an optional `fallbackLiteral`; `finish` replaces it when
supplied and preserves it when omitted. `clearFallback(for:)` explicitly removes it. Built-in-only documents keep the table empty.
Only zero is a document root. Siblings follow non-overlapping source order;
children stay within their parent. Empty ranges are allowed. Custom extension
names should use a namespace such as `example.notice`.

Validation uses direct optional-index checks and a dense visited buffer after
all indices have been checked. It remains iterative and active in release;
there is no unchecked parser-only construction path. Validated construction remains part of performance measurements.


The parser treats a failure of its own builder validation as an implementation
invariant violation. Extension match results are checked before insertion, so
malformed returned ranges or consumption counts do not reach that boundary.

### Source ranges and literals

- All ranges are half-open `[lowerBound, upperBound)` byte offsets into
  `Document.source`. Bounds are immutable, non-negative and ordered.
- Root range includes every byte, including blank lines and final line endings.
- A single UTF-8 BOM at byte zero is ignored for block recognition. It remains
  in `Document.source` and the root range. First-line block/content offsets
  begin after those three bytes, while `SourceLine.physicalRange` retains
  byte zero and indentation columns start at zero after the BOM. Later U+FEFF
  characters and incomplete BOM byte sequences are not stripped.
- Top-level block ranges start at the physical line start (after an initial
  BOM, if present). Nested blocks start
  after enclosing quote/item prefixes, retaining their own indentation/markers.
  Ranges include consumed final line endings and may span ancestor prefixes on
  subsequent lines. Headings include opening and
  closing markers or the setext underline; fenced blocks include their fences.
- Inline text ranges address contributing original bytes. Heading delimiters,
  removed indentation and a heading's closing marker are excluded from its
  text children. Soft breaks cover the original CRLF/CR/LF bytes.
- `sourceSegments` lists ordered, non-overlapping contributing ranges within a
  node. Paragraph/heading segments identify content lines. Code-block segments
  include code line endings, but exclude fences and removed indentation.
  Nodes store zero or one segment inline and only allocate an array for
  several; `sourceSegments` builds the public array view on access.
- A segment is provenance, not a guarantee that slicing it equals the decoded
  literal. Code line endings become LF; a missing final code newline is
  synthesised. A tab partially removed by a container prefix or indentation contributes residual
  virtual spaces, and the corresponding source segment includes that tab byte.
- `parse(bytes:)` preserves malformed UTF-8 exactly in the source array. Literal
  decoding uses Swift UTF-8 replacement decoding and replaces NUL with U+FFFD.
  The `String` entry point feeds its UTF-8 bytes into the same path.

Tabs advance to the next four-column stop for block indentation. Position
conversion uses zero-based UTF-16 offsets and one-based lines/Unicode
scalar columns (a tab counts as one scalar, separately from visual indentation).
Offsets inside a UTF-8 scalar, a replacement-decoding subpart or a CRLF pair
are rejected, so conversions cannot silently round source locations.
`SourceIndex` implements the optional coordinate conversions described below. No source-to-rendered-character map is implied
by these provenance segments.

Example input: `## A\n\none\ntwo\n` (14 bytes).

```text
0 document                 [0, 14)
  1 heading(level: 2)      [0, 5)   segments: [3, 4)
    2 text("A")            [3, 4)
  3 paragraph              [6, 14)  segments: [6, 9), [10, 13)
    4 text("one")          [6, 9)
    5 softBreak            [9, 10)
    6 text("two")          [10, 13)
```

Fenced input: ` ```txt\nx\n```\n` without the leading space (13 bytes).

```text
0 document                               [0, 13)
  1 codeBlock(info: "txt", literal: "x\n") [0, 13)  segments: [7, 9)
```

Reference input: `[a]: /x\n\nA\n` (11 bytes). Definitions remain available to
the inline phase without appearing in HTML.

```text
0 document                                     [0, 11)
  1 referenceDefinition(label: "a", dest: "/x") [0, 8)
  2 paragraph                                  [9, 11)  segments: [9, 10)
    3 text("A")                                [9, 10)
```

These examples are executable contracts in `SyntaxTreeTests`; additional
boundary cases live in `LeafBlockTests`, `ContainerTests` and `ExtensionTests`.

Nested input: `- > Ä\r\n  > B\r\n` (15 bytes). Ancestor prefixes do not enter
the paragraph's content segments, and the soft break retains the original CRLF.

```text
0 document                     [0, 15)
  1 list(bullet: "-", tight)    [0, 15)
    2 listItem                 [0, 15)
      3 blockQuote             [2, 15)
        4 paragraph            [4, 15)  segments: [4, 6), [12, 13)
          5 text("Ä")          [4, 6)
          6 softBreak          [6, 8)
          7 text("B")          [12, 13)
```

### Open containers and limits

The parser matches open quote and item prefixes once per physical line, then
continues its current leaf or opens/closes containers. It does not recursively
strip and reparse substrings. Tabs use absolute four-column stops, and a partly
consumed tab keeps a virtual suffix tied to its original byte.

Only an open paragraph can accept a lazy line with missing prefixes. A new
block at the matched outer level closes unmatched containers. In particular,
`2.` cannot interrupt an existing paragraph at the same level, but can start a
list outside a quote whose prefix is missing. Empty markers follow the same
distinction. Ordered list delimiters and bullet markers determine list grouping.

List tightness tracks blank separation between direct blocks/items. Blank lines
inside quotes or fenced code do not automatically loosen an enclosing list.
The renderer unwraps only direct item paragraphs in tight lists; nested quotes
and loose lists retain their own paragraph tags.

`ParserLimits.maximumContainerDepth` defaults to 128 and accepts 1 through 256.
Quotes, lists and items each consume a slot, so opening a new list requires two
slots. At the limit the remaining syntax is kept as escaped paragraph text and
`nestingLimitExceeded` is reported. The parser, validator and renderer are
iterative for built-ins; custom child parsing uses bounded recursive calls over
projected views, counting custom and built-in containers against the same limit.
No release performance target is established by correctness tests alone.

## Position and tree queries

`SourceIndex(document)` (or `SourceIndex(bytes)` before parsing) owns the exact
original byte snapshot; the bytes are not exposed. It converts
UTF-8 byte offsets, zero-based UTF-16 code-unit offsets/ranges, and one-based
physical lines/Unicode-scalar columns, and answers `lineCount` and
`utf8Offset(ofLine:)`. Tabs count as one scalar, combining scalars separately.
Columns are not UTF-16 columns as used by LSP or TextKit; such APIs use the
UTF-16 offsets and ranges. A BOM and NUL each contribute one UTF-16 unit; malformed
UTF-8 uses Unicode maximal-subpart replacement decoding. No normalization of
the stored bytes occurs. CRLF advances two UTF-16 units and one physical line.
Its interior, surrogate halves, scalar interiors and invalid-subpart interiors
are rejected with `nil`. Empty and EOF ranges are valid boundaries.

Checkpoints occur at line starts and about every 128 bytes, stored as 16-byte
`Int32` records (native width beyond 2 GiB). Construction skips ASCII runs
without CR/LF eight bytes at a time. The opt-in index uses O(bytes/128 + lines)
memory and bounded decoding after binary search, including on very long lines.
It is not constructed by the parser.

`DocumentIndex` stores parents and source-order children in a compressed
sparse row layout: three flat `Int32` tables (native width for larger trees),
built in two passes without per-node allocation. `ancestors(of:)` is a lazy
sequence. It adds `node(atUTF8Offset:affinity:)`.
A constant-size UTF-8 boundary check avoids constructing a position index.
Downstream uses `[start,end)`, upstream `(start,end]`; zero-length nodes never
capture a caret. Downstream EOF and upstream BOF return the root. Sibling search
is binary followed by boundary/empty-node handling. `outline()` visits block
containers in source order once, never descending into paragraph or heading
inlines except to build titles, and returns node/range/level/plain title and the
nearest preceding lower-level heading. The outline is global: headings inside
quotes, list items and custom block containers are included, and the parent
heading can lie outside the heading's container. Plain titles include text, code and image labels, omitting
raw HTML and unknown custom content. Node identities belong to this snapshot.

## Syntax tokens

`collectSyntaxDetails: true` records optional original-byte `(role, range, owner)`
values in `Document.tokens`; `nil` means collection off, `[]` means collected
with no tokens. Tokens can overlap, include empty insertion ranges and remain
in emission order, rather than a global source sort. Owners are local to the
returned snapshot. Public construction validates every owner and range.

Emphasis/code delimiters, escapes/entities, hard breaks, link/reference parts,
raw HTML and fences retain their exact spelling. Disjoint projections produce
separate tokens; contiguous pieces coalesce. Semantic bounds and lexical marker
ranges are distinct. `referenceSyntax(for:)` provides a linear on-demand scan of
reference tokens; avoid calling it once per node on large trees.

### Contract

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

### Optional collection and extension boundaries

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


## Safe HTML and hooks

Generated URLs allow relative addresses and the schemes in
`allowedURLSchemes`, by default `http`, `https` and `mailto`. `HTMLURLScheme`
validates RFC 3986 scheme names, compares case-insensitively and predefines
`tel` and `ftp` for callers that opt in. Unknown schemes, `data`, `file`,
JavaScript and control/case obfuscations are blocked independently of raw-HTML
permission. A colon after a path/query/fragment
separator is part of a relative URL. Attribute and literal escaping remain in
force. This deliberately narrows the previous scheme denylist; consumers that
explicitly trust every destination can choose `allowUnsafeURLs`.

Raw HTML and hooks remain explicit caller trust boundaries, not a sanitizer.
The trusted-fixture `.conformance` setting retains exact spec behavior.
`sourceAnchorPrefix` (escaped once per renderer) adds unique per-node IDs to generated block tags;
`includeSourceRanges` independently adds original byte bounds. IDs are namespaced
by the caller and are not stable across edits. Tight paragraphs have no generated
tag; their containing list item still has an anchor. Raw HTML is not rewritten.
Contextual hooks can read `sourceAnchorID`, built only on access, and own any
wrapper/anchor they emit.

Hooks can replace a node, wrap its rendered children or return nil for normal
rendering. Contextual hooks take precedence over legacy hooks, and receive
snapshot node identity, parents, ancestors and tight-item state. Use
`HTMLRenderer.escape` for source-derived values. Unknown custom containers
render children; unknown leaves use escaped projected fallback text, or raw
node-range bytes for a hand-built tree without fallback metadata. Preserve
`customLeafFallbacks` when rebuilding a document.

`wrapChildren` retains built-in list/item scheduling and tightness. Hooks own
their wrapper whitespace and any anchors they emit. `SetzerHTML` depends only
on `SetzerSyntax`; rendering does not require a parser or extension catalog.


### HTML blocks

`NodeData.htmlBlock(HTMLBlock)` stores the seven CommonMark start/end classes
and the literal with LF-normalised line endings. Original bytes and projected
line segments remain in the document. HTML content is not parsed as Markdown;
code fences inside an HTML block do not start code blocks. Container boundaries
still end the block, and only paragraph leaves allow lazy continuation.

Types 1–5 end at their respective terminator or container/EOF boundary. Types
6/7 end before a blank line. Type 7 cannot interrupt a paragraph at its own
level, but can start at an outer level after a quote/item prefix fails. Matching
uses byte scanners, including complete-tag attributes and quoted values.

The renderer defaults to escaped HTML and omitted recognised comments. Comment
filtering runs only inside recognised HTML blocks, respecting quoted tag
attributes, processing instructions, CDATA and raw-text elements; it never
strips comment-shaped text from Markdown/code literals.

```swift
let document = MarkdownParser().parse("<!-- hidden -->\n<div>visible</div>\n")
let safeHTML = HTMLRenderer().render(document)
let specHTML = HTMLRenderer(allowRawHTML: true, preserveHTMLComments: true)
    .render(document)
```

Raw HTML permission and comment preservation are independent options; hooks
still supply trusted caller HTML. Raw block output is not rewritten to add
source-anchor attributes. Inline raw HTML uses with the same explicit HTML/comment options,
and generated links/images with decoded URL-scheme checks. Existing source anchors apply to the supported generated block elements.

### Reference definitions

Definitions are extracted from the beginning of a collected paragraph. Labels,
destinations and titles may use their specified continuation lines; blank lines
or a new containing block cannot be crossed. Quoted titles can span lines.
Malformed next-line title candidates fall back to a complete destination line,
leaving the candidate as paragraph content. Malformed same-line titles invalidate
that definition. Labels allow at most 999 Unicode scalars, need a character other than a space/tab/line ending, and do not allow unescaped nested brackets.

Lookup compares fully folded UTF-8 bytes, without canonical Unicode-equivalence
matching. Label whitespace folding applies only to ASCII spaces, tabs and line
endings; other separators such as NBSP remain part of a label. Destination/title
values decode escapes/entities once. Generated entity and non-Turkic Unicode
case-folding tables use pinned data, without a runtime locale or dependency.

Every definition is retained as a node, including duplicates. The parser resolves
references with first-definition-wins lookup, Unicode full folding and collapse of ASCII label
spaces/tabs/line endings. Raw component text has paragraph indentation/container
prefixes removed and line endings normalised. The payload keeps escapes and
entities source-spelled; inline lookup decodes destination/title values once. Original spelling remains in `Document.source` and node segments.

Definitions emit no HTML and do not create phantom visible children that make
a list loose. A setext candidate with only definitions before it stays paragraph
text, rather than becoming an empty heading or a new list item.

## Progressive HTML

This API consumes an already parsed, complete `Document`; it does not stream
or incrementally parse Markdown.

### Prepare and consume

```swift
import GMSetzer

let document = MarkdownParser(profile: .gfm).parse(source)
let renderer = HTMLRenderer(includeSourceRanges: true)
let plan = try renderer.prepare(document, maximumSourceBytesPerGroup: 32_768)

try plan.forEachGroup { group, html in
    print(html, terminator: "")
    return true // false stops before the next group is rendered
}
```

The complete document and the renderer options belong to the plan. Preparation
groups top-level blocks and creates a shared `DocumentIndex` only when
contextual hooks need it. It does not render body blocks or call hooks.
Known non-rendering reference definitions are omitted from structural groups;
a custom reference-definition hook still receives them.

`maximumSourceBytesPerGroup` is a positive, soft source-byte budget. A complete
table, list, quote, code block or custom container is never cut in half. A block
larger than the budget remains one group; HTML escaping and source attributes
can make output much larger than its source. This is not a strict HTML-byte,
time or memory limit. Empty documents have no groups unless a document-level
fallback/hook requires output. A caller hook can produce an empty group.

Each `HTMLRenderGroup` supplies its ordinal, body/appendix kind, source range
and top-level node indices. These are snapshot-local values, not stable IDs
across edits. A body group's range spans its nodes, possibly including source
gaps. An appendix uses the whole document's range and has no body node indices.

`renderGroup(at:)` materialises only the requested group. Structural groups can
be requested in any order, including concurrently, and placed back in ordinal
order by a consumer. `forEachGroup` is synchronous and pull-based: it has no
producer queue, and does not retain previously delivered HTML. Its return value
counts groups handed to the consumer, including the final group returning false.
The plan itself retains the full syntax document and its small grouping/index
metadata. It does not promise constant total memory or evict source/tree data.

### Stopping and cancellation

```swift
let html = try plan.renderGroup(at: ordinal, checkpoint: {
    try Task.checkCancellation()
})
```

Checkpoints run before/after group output and between renderer events. Throwing
aborts the current render without delivering an incomplete group; the plan is
still reusable. A literal conversion, a caller hook, or a hook recursively
rendering its children is indivisible until it returns. Synchronous parsing and
preparation have already happened and are not cancelled by this callback.
Invalid nonpositive budgets and invalid ordinals throw `HTMLRenderPlanError`.

Consumers own revision/configuration checks, latest-work scheduling, cache
lifetime, backpressure across asynchronous boundaries and UI insertion. No app
session type, Foundation, JavaScript or UI dependency is added to the library.

### Explicit fallbacks and hooks

`plan.mode` distinguishes `.structural` from `.wholeDocument(reason)`:

| Reason | Why the whole output remains one group |
| --- | --- |
| `.rawHTML` | Raw source HTML can open a wrapper in one block and close it in another. Any renderer allowing raw HTML conservatively uses this fallback, including `.conformance`. |
| `.documentHook` | A root replacement/wrapper can change the structure of all children. |
| `.documentOrderHooks` | Caller hooks have not promised independent execution. |

The precedence is raw HTML, document hook, then document-order hooks. Fallback
preparation remains lazy, but its only output group materialises the complete
result. Such a plan does not shorten first-output latency through grouping.

Custom hooks default to `HTMLHookBehavior.documentOrder`. Only opt into
`.independent` when every hook is deterministic, thread-safe, has no dependence
on invocation order and returns markup contained inside its block. The promise
is the caller's responsibility; `Sendable` alone does not establish it.
Repeated requests to a fallback plan re-run its whole renderer and may repeat
caller effects, just as repeated full `render` calls do. The caller should
consume such a result once rather than treating it as independent tiles.

The existing escaping, URL policies, original node-based anchors and trusted
caller-hook boundary apply unchanged. Preparing groups is not an HTML sanitizer.
The existing `render(_:) -> String` API remains available.

### Footnotes and other extensions

`FootnotesHTMLRenderer.prepare` numbers all references over the complete
document, including forward, repeated and cyclic calls, and shares the
prepared renderer/index with every group. Top-level definitions are suppressed
in the body and cited notes become one lazy appendix group at the end. The
appendix can be requested first without changing numbering/backlinks, but must
be placed last. A whole-document fallback includes that appendix in its single
group. The appendix may itself be large and is intentionally indivisible.

`AdmonitionHTML.renderer` certifies its own built-in hooks as independent.
Combining it with footnotes preserves title rendering, nesting, source anchors
and complete-document context. A caller hook requiring document order keeps
the combined renderer in fallback mode. Math hooks and front-matter omission
remain caller policies; pure custom hooks must explicitly opt into independence.

## GFM

### Profile and switches

`Profile.gfm` selects six built-in identifiers (`BuiltinExtension`). Each can
be selected alone or combined; no implementation is supplied by the caller,
and supplying one with the same identifier is a configuration issue.

| Identifier | Effect |
| --- | --- |
| `gfm.table` | `table(TableAttributes)`, `tableRow(isHeader:)`, `tableCell(alignment:)` |
| `gfm.tasklist` | `taskListItem(checked:)` in place of `listItem` |
| `gfm.strikethrough` | `strikethrough` inline (one or two tildes) |
| `gfm.autolink` | `link` nodes for www, http(s)/ftp URLs, email, `mailto:` and `xmpp:` |
| `gfm.tagfilter` | Rendering policy `filtersDisallowedRawHTML` |
| `gfm.collapseNestedStrong` | Rendering policy `collapsesNestedStrong` |

Rendering policies live in `Document.renderingPolicy`, set by the parser from
the profile and applied by `HTMLRenderer`. They change output only. The tag
filter acts when raw HTML is emitted (`allowRawHTML`); safe default rendering
escapes raw HTML anyway. Extended autolinks are ordinary links: under safe
rendering an `ftp:` destination is blank unless `allowedURLSchemes` contains
`.ftp`.

### Recognition

GFM rules use the byte/line model below. Ported algorithms retain their BSD-2
attribution in [NOTICE](../NOTICE).

- **Tables.** A delimiter row (`[|]? marker ([|] marker)* [|]?`, marker
  `:?-+:?`) on a fully matched paragraph continuation line, at most three
  columns indented, after every other block start failed, turns the paragraph's
  last line into a header with the same cell count. A header that continued
  the paragraph lazily keeps its whitespace after the matched containers, as
  cmark-gfm stores lazy lines; a leading space then adds an empty first cell.
  A paragraph that fails this
  check is never rechecked. Rows continue until a blank line, a lazy line, any
  other block start (including indented code and HTML type 7) or a line that is
  not a row. Short rows are completed with empty, unaligned cells; extra cells
  are dropped. A pipe after a backslash belongs to its cell; that backslash is
  removed from the cell text. cmark-gfm's limit of 0x80000 completed cells
  applies.
- **Lines before a table header** become a paragraph exactly as cmark-gfm
  inserts it: reference definitions in it remain text and `\|` loses its
  backslash. GitHub renders the same.
- **Task lists.** The physical line must match
  `spacechar* (-|+|*|digits any) spacechar+ [ ]|[x]|[X] spacechar+`, with the
  checkbox at the content start of the item opened on that line. Items inside
  block quotes therefore stay plain, as on GitHub. The rest of the line is
  always paragraph text.
- **Strikethrough.** Runs of at most two tildes (scanned up to 100) flank like
  `*`, using cmark-gfm's Unicode P-category punctuation. Equal openers and
  closers wrap; unequal ones remain text.
- **Autolinks.** www and URL matches run at `w` and `:` outside open brackets,
  with cmark-gfm's domain, underscore, trailing-punctuation, parenthesis and
  entity trimming rules. Email, `mailto:` and `xmpp:` matches run after the
  leaf over consecutive decoded text outside links, so `a\@b.cd` links like in
  cmark-gfm. Links keep exact source ranges; a boundary inside an escape or
  entity snaps to its start.
- **Tag filter.** `<` of `title`, `textarea`, `style`, `xmp`, `iframe`,
  `noembed`, `noframes`, `script` and `plaintext` (case-insensitive, followed by
  whitespace, `>` or `/>`) becomes `&lt;` in emitted raw HTML.

### Source ranges and syntax tokens

Rows span their line; cells span the raw bytes between pipes; a cell's text
segments exclude escaping backslashes and trimmed whitespace. With
`collectSyntaxDetails`, the parser records `gfm.table.delimiterRow`,
`gfm.table.pipe`, `gfm.tasklist.marker`, `gfm.strikethrough.open/close` and
`gfm.autolink` tokens. Analysis, outline and traversal descend into task list
items like list items; tables contain no headings.

## Optional syntax

Strict CommonMark and GFM selections stay unchanged. For each optional feature,
both select its identifier and supply its implementation; registration alone
does not activate it. To combine all shipped optional syntax with GFM:

```swift
let implementations = [FrontMatter.implementation, Footnotes.implementation,
                       Math.implementation, Alert.implementation, Callout.implementation]
let profile = Profile(name: "gfm-with-extras", extensions: Profile.gfm.extensions
    + implementations.map { ExtensionConfiguration($0.identifier) })
let parser = try MarkdownParser(profile: profile, extensions: implementations,
    collectSyntaxDetails: true).validated()
let html = try MarkdownHTML.render(source, parser: parser)
```

Typed views are `Hashable`/`Sendable` and bound to the supplied snapshot. Invalid
indices, kinds or payload shapes return nil. Syntax collection off preserves
semantic nodes and HTML. No YAML/TOML serializer, TeX engine, stylesheet or
external resource loader is bundled.

### Front matter

`FrontMatter(document, at:)` exposes `.yaml` / `.toml` format, full `range`,
`contentRange`, owned `rawBytes` and computed replacement-decoded `rawText`.
Disable formats with `frontmatter.yaml` / `frontmatter.toml` in
`Profile.disabledRules`; disabling both restores ordinary Markdown recognition.

#### Fence grammar

- Open on the original first physical line, at column zero, optionally after
  one UTF-8 BOM. No preceding blank line or indentation is accepted. Quotes,
  lists and projected extension children cannot restart this recognition.
- YAML uses exactly `---` on both fence lines; TOML uses exactly `+++`.
  Only ASCII spaces/tabs may follow the three markers. The closing delimiter
  is also at column zero and may end at EOF without a line ending. LF, CRLF
  and CR are supported.
- The first matching closing fence ends the block. A closing fence is
  required; dangling/mismatched fences leave all input to ordinary Markdown
  parsing without an extension diagnostic. Empty metadata is valid.
- Interior data is opaque. Invalid YAML/TOML is still front matter, and
  serialization string quoting does not change markup fence recognition.
  No fields, values, references or document settings are interpreted.
- JSON, YAML `...` closing delimiters and configurable alternative fences
  are outside the supported grammar. Later front-matter-looking blocks are normal
  Markdown.

Behavior references are [Hugo's delimiter examples](https://gohugo.io/content-management/front-matter/)
and [remark's frontmatter syntax extension](https://github.com/remarkjs/remark-frontmatter).
This is not a claim of complete compatibility with those systems/serializers.

#### Source and extension contract

The node is `.custom(kind: FrontMatter.kind, role: .block, ...)`, with kind
`frontmatter.block`, attribute `format: .string("yaml" / "toml")`, no children
and exactly one source segment covering only the original interior. Empty
metadata retains an empty insertion segment. The node range includes both
fence lines and the closing line ending; it excludes a leading BOM, which
remains in `Document.source`.

`contentRange` starts after the opening line ending and ends at the beginning
of the closing line. Raw bytes, line endings, Unicode, NUL and invalid UTF-8
remain available without normalisation. `rawText` uses Swift replacement
decoding for invalid UTF-8 while preserving valid NUL and line endings. This
is separate from the core's normalized safe fallback.

With collection enabled, three tokens share the metadata node owner:

| Role | Range |
| --- | --- |
| `frontmatter.fence.open` | Exactly the three opening marker bytes |
| `frontmatter.content` | Complete original interior, including an empty insertion range |
| `frontmatter.fence.close` | Exactly the three closing marker bytes |

Collection off keeps identical metadata/body and `tokens == nil`.
`BlockContext.isDocumentStart` is true only on the original first line before
containers open, and false in projected child parsers. Rules still validate
exact indentation/spelling. A wrapper projecting the original first line
without removing bytes cannot accidentally restart front matter.

#### Rendering and other services

Rendering remains a caller policy. The generic fallback displays escaped
metadata including fences; even `allowRawHTML: true` does not execute it as
HTML. To omit front matter from output:

```swift
let renderer = HTMLRenderer(hooks: [FrontMatter.kind: { _, _ in .replace("") }])
let html = renderer.render(document)
// <h1>Body</h1>\n
```

The extension does not depend on `SetzerHTML`. A caller can instead use the
raw metadata to select a template and supply its own hook. Analysis and
outline see an opaque leaf: metadata does not become Markdown headings,
link-reference definitions, lint findings or fixes. Body Markdown and GFM
features continue normally.

### Footnotes

#### Declared grammar and lookup

- A definition starts with `[^label]:`, preceded by zero to three indentation
  columns. It can interrupt a running paragraph. Up to four indentation
  columns after the colon are removed from the first content line; additional
  indentation remains available to Markdown, including indented code.
- Subsequent nonblank definition lines require four indentation columns,
  removed through the core's physical tab-stop projection. Blank lines are
  retained, allowing multiple paragraphs, lists, quotes and code. An
  unindented nonblank line ends the definition. **Lazy unindented continuation
  is deliberately outside the supported grammar.**
- Definitions can be empty and can occur in lists, quotes and nested
  definitions. Existing container boundaries and depth limits apply. Labels
  contain 1...999 Unicode scalars; ASCII controls/space, DEL and unescaped
  brackets are rejected. Backslash escapes of `[`, `]` and `\` are retained
  as part of the source-spelled label. Failed scans have a fixed byte bound.
- References use `[^label]` and resolve against definitions from the complete
  block tree, including forward definitions. Matching uses the existing
  locale-independent Unicode full case folding over raw label spelling, with
  byte-exact equality after folding. No canonical Unicode normalization,
  entity decoding or escape decoding is applied. The first matching
  definition in source order wins; duplicates remain in the tree.
- Only known labels become reference nodes. Unknown/malformed references
  continue through ordinary Markdown parsing without a footnote diagnostic.
  A known reference takes precedence over a following ordinary link target.
- Escaped opening brackets, code, raw HTML, consumed link destinations/titles
  and any open link/image bracket context remain protected. This conservative
  bracket policy also applies when an outer bracket ultimately remains
  unresolved. Pandoc inline `^[...]` notes are not supported.

The syntax starting points are
[GitHub's footnote documentation](https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/basic-writing-and-formatting-syntax#footnotes)
and [micromark's documented footnote grammar](https://github.com/micromark/micromark-extension-gfm-footnote#syntax).
The explicit continuation and bracket policies above define the supported scope; it is
not a claim of complete GitHub, Pandoc or micromark equivalence. Code and test
strings are original; no third-party implementation or fixture was copied.

#### Tree, numbering and source

`footnotes.definition` is a custom block container with a raw `label` string
attribute and ordinary parsed Markdown children. `footnotes.reference` is a
custom inline leaf with the same raw label attribute. `Footnotes.label(node)`
returns that spelling for either kind. Definition ranges include their marker,
content and consumed line endings; child projections exclude the marker and
continuation prefixes without rebuilding source bytes. Reference ranges cover
the complete `[^label]` spelling. All offsets remain in `Document.source`.

`Footnotes.Index(document)` returns cited notes in display order, each with
`number`, winning `definition` index and `references` indices. Body references
assign numbers first. Then each cited definition body is visited once, in
assigned-note order, discovering further notes. Uncited definition bodies are
not searched for calls. Self references and cycles are finite; no node is
copied or recursively expanded for display. Repeated calls share a number and
receive distinct occurrence identifiers.

The post-inline `footnotes.number` transform stores the computed `number`
integer on cited definitions/references and `occurrence` integer on reachable
references. It preserves node indices, topology, tokens, fallbacks, diagnostics
and rendering policy. `Footnotes.Index` can also compute the same view when
that annotation transform is disabled. Indices/ranges are snapshot-bound;
consumers own revision identity and caches.

With collection enabled, definition and reference nodes own these tokens:

| Role | Exact spelling |
| --- | --- |
| `footnotes.definition.open` / `footnotes.reference.open` | `[^` |
| `footnotes.definition.label` / `footnotes.reference.label` | Original label bytes |
| `footnotes.definition.close` | `]:` |
| `footnotes.reference.close` | `]` |

Body syntax and enclosing quote/list marker tokens remain available. Annotation
off preserves identical nodes, numbering and HTML, with `tokens == nil`.
Disable rules independently through `Profile.disabledRules` using
`footnotes.definition`, `footnotes.reference` and `footnotes.number`.

#### HTML and other services

`FootnotesHTMLRenderer.prepare` supports [progressive HTML](#progressive-html). It prepares numbering/reference context
once, omits top-level definitions from body groups and emits cited notes as
one lazy final appendix. Out-of-order requests preserve numbering/backlinks;
raw HTML or non-independent caller hooks retain a whole-document fallback.
This addition does not change the 0.5.0 grammar or full-string output.

`FootnotesHTMLRenderer(renderer:idPrefix:backlinkLabel:)` renders body calls as
numbered links, then appends a `section.footnotes` with an ordered list of cited
definitions and one backlink per reachable call. Unused and duplicate
definitions are omitted. The wrapper's own numeric IDs use a caller-selected
namespace; unsafe prefix bytes (including underscore) are hex-encoded without
collisions. `backlinkLabel` is plain text that callers may localise.

The supplied `HTMLRenderer` retains URL restrictions, raw-HTML/comment policy,
GFM tag filtering and hooks for other kinds, including front matter. Footnote
hooks are owned by this wrapper. Child block anchors/source attributes remain
those of the base renderer; the generated note wrappers use footnote IDs.
Contextual hooks reuse one `DocumentIndex` across body and note rendering.
All source text and generated attribute values are escaped as appropriate;
caller-returned hook HTML retains the existing trust boundary.

Plain `HTMLRenderer` retains its generic custom-node fallback: parsed children
or escaped source for a leaf. It does not group footnotes or hide unused notes.
Native analysis retains its existing opaque-custom-content policy, including
note bodies. The source-order outline retains its existing traversal through
custom block containers, so headings in notes appear there. Consumers may
filter that outline through `DocumentIndex` parent/ancestor queries.

### Math

`Math(document, at:)` exposes format (`.inline`, `.display`, `.fenced`),
`isDisplay`, full `range`, original `contentRanges`, `rawBytes` and projected
`tex`. Disable forms separately with `math.inline`, `math.display` and
`math.fenced` in `Profile.disabledRules`.

#### Declared grammar

##### Inline dollars

Single `$` delimiters surround nonempty TeX on one physical line. An opener
must not be followed by Unicode whitespace. A closer must not follow Unicode
whitespace or precede an ASCII digit. Backslash-escaped dollars do not delimit;
even/odd backslash parity matters. Delimiters must be runs of exactly one
dollar; longer runs are not separate single-dollar delimiters. Thus ordinary
`$20,000 and $30,000` stays prose. TeX contents are opaque: Markdown emphasis,
code, links, entities and escapes inside an accepted span are not interpreted.

Core escapes, code spans, raw HTML and consumed link destinations/titles stay
protected. Math may appear inside emphasis and link/image labels, using the
existing inline controller. A prepared next-close lookup is built once per
snapshot; each opener is indexed independently, so a dollar in consumed code
cannot steal later pairs. Matches additionally require one contiguous original
source range inside the current projected inline input, preventing cross-cell
or cross-leaf consumption. Failed candidates remain ordinary Markdown without
an extension diagnostic. Selecting a custom trigger can split adjacent text
nodes even when no math matches; unchanged literal cases preserve exact HTML
and source, not necessarily the strict parser's text-node grouping.

The spacing/currency starting point is
[Pandoc's dollar-math rules](https://pandoc.org/MANUAL.html#extension-tex_math_dollars).
The supported grammar excludes multiline single-dollar math and GitHub's
alternative dollar/backtick syntax; it does not claim dialect equivalence.

##### Dollar display blocks

A display opener starts a line after zero to three indentation columns and
may interrupt a paragraph. Supported forms are:

```text
$$ x^2 + y^2 $$

$$
\begin{aligned}
x &= y
\end{aligned}
$$
```

The one-line form has distinct, exact-width `$$` fences; its closing fence
ends the line apart from ASCII spaces/tabs and must be unescaped. Interior
whitespace is retained. In the multiline form, opening and closing lines
contain only `$$` plus optional ASCII spaces/tabs after indentation. The first
matching closing line ends the block, including at EOF. Blank interior lines
and empty bodies are allowed. Content removes up to the opener's indentation,
using the existing physical-tab projection; enclosing quote/list prefixes
remain excluded. A closing fence is required. Unclosed/wrong-width forms fall
back to ordinary Markdown without swallowing input or adding a diagnostic.
Paragraph-internal `text $$x$$` is outside this block grammar.

##### Math code fences

Existing CommonMark backtick/tilde fences are recognised by the core first.
The post-inline `math.fenced` transform converts code blocks whose decoded
first info word is exactly, case-sensitively `math`. Further info words are
permitted. Fence length, indentation, container boundaries, empty blocks and
unclosed-EOF behavior remain those of core code fences. Other languages stay
ordinary code. Unlike dollar blocks, unclosed math code fences are accepted
through EOF, including the core's synthetic final LF in the semantic literal.

[GitHub's mathematical-expression documentation](https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/writing-mathematical-expressions)
is the reference for dollar-display and `math`-fence authoring forms. Grammar
details above are this implementation's declared scope. Code/tests are original;
no external implementation or fixture was copied.

#### Tree and source contract

`math.inline` is a custom inline leaf; `math.block` is a custom block leaf.
Both carry string attributes `format` and `tex`, have no Markdown children
and do not validate TeX commands, syntax or macros. `tex` retains TeX spelling
without Markdown entity/escape decoding, normalizes block line endings to LF
and replacement-decodes invalid UTF-8/NUL. Math code fences use the existing
core code literal, including virtual indentation and EOF normalization.

`rawBytes` concatenates only the original `contentRanges`: original CRLF/CR,
Unicode, invalid UTF-8 and NUL remain available. It is provenance rather than
a reconstructed semantic string: a partially consumed tab retains its source
byte, while `tex` contains the projected spaces. An empty block retains an
empty insertion range. Complete block ranges include delimiters and consumed
line endings/indentation; a leading BOM stays in `Document.source` outside
syntax. Inline node segments cover the whole match; the typed view derives
their delimiter-free content range. Block segments cover content only.

With syntax collection enabled, the expression owns `math.fence.open`,
`math.content` and `math.fence.close` tokens. Multiline blocks have one content
token per source segment; empty content has an empty token. Fenced math retains
existing `core.fence.*` tokens verbatim and adds namespaced aliases, including
`math.fence.info`. An unclosed code fence has no closing token. Token emission
order is not a source-sort contract. Annotation off yields the same nodes,
expressions, fallbacks and HTML, with `tokens == nil`.

#### Rendering and other services

The caller uses `Math.inlineKind` / `Math.blockKind` hooks to pass `tex` and
`isDisplay` into a separately chosen TeX engine. This package does not evaluate
TeX, produce MathML, install JavaScript or load external resources. For an
escaped-text presentation, for example:

```swift
let hook: ContextualHTMLRendererHook = { context in
    guard let math = Math(context.tree.document, at: context.index) else { return nil }
    let tag = math.isDisplay ? "div" : "span"
    return .replace("<\(tag) class=\"tex\">\(HTMLRenderer.escape(math.tex))</\(tag)>")
}
let html = HTMLRenderer(contextualHooks:
    [Math.inlineKind: hook, Math.blockKind: hook]).render(document)
```

This example displays escaped TeX text, not typeset formulas. Caller-produced
hook HTML retains the existing trust boundary. Default rendering escapes
custom leaves even with `allowRawHTML: true`: inline and dollar-block fallbacks
retain projected delimiter spelling; converted code fences use their semantic
code literal. Generic outline/plain-text/image-alt and native-analysis handling
keep the existing custom-leaf policies; math contents do not become headings,
references, lint findings or fixes. Image-alt text requires a caller image hook
if it should include a custom math leaf. Math hooks compose with front-matter
hooks and `FootnotesHTMLRenderer` through its base renderer.

### Alerts and callouts

When both implementations match an untitled/unfolded `[!NOTE]`, priority/profile
order decides; select alerts first for the stricter form. Explicit `ruleOrder`
can override `alerts.recognise` / `callouts.recognise`. Folded/titled headers and
other types belong to callouts. Disable recognition with those same rule IDs.
The separate `alerts.wrap` / `callouts.wrap` transforms can be disabled; doing
so deliberately retains an internal header with escaped fallback in a quote.

#### Declared grammar

The marker must start the first physical line of a newly opened core quote,
after its prefix and zero to three indentation columns. A blank initial quote
line, a preceding paragraph, code/HTML context or escaped marker is not a
header. Core quote/list continuation, nesting and depth limits still apply.

- Alerts accept exactly `[!NOTE]`, `[!TIP]`, `[!IMPORTANT]`, `[!WARNING]` and
  `[!CAUTION]`, followed only by ASCII spaces/tabs. The marker has its own line;
  body blocks start on following lines. Empty alerts are allowed.
- Callouts accept a case-insensitive ASCII type with letters, digits, `_` or
  `-`, including at least one alphanumeric byte. An optional adjacent `+`
  expands by default; `-` collapses. An optional title follows ASCII space/tab
  separation. Trailing ASCII spaces/tabs are removed from the title. A custom
  title is parsed as inline Markdown independently of the body; title-only
  callouts are allowed. Without a title, the normalised type supplies a title.
- Nested callouts and quotes in lists are supported. Body paragraphs, lists,
  tables, code, headings and thematic breaks are parsed normally. A dedicated
  header block prevents a following underline/table delimiter from consuming
  the marker as a heading or table header. There is no Markdown reconstruction
  or second parse of body text.
- Obsidian's built-in style names and aliases are mapped to canonical styles.
  Examples: `summary`/`tldr` → `abstract`, `hint`/`important` → `tip`, `faq`/`help`
  → `question`, `caution`/`attention` → `warning`, `error` → `danger` and `cite`
  → `quote`. Unknown names keep their type but use the `note` fallback style.

Syntax references are [GitHub's alert documentation](https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/basic-writing-and-formatting-syntax#alerts)
and [Obsidian's callout documentation](https://help.obsidian.md/callouts).
This library also recognises alerts within existing quote/list containers;
GitHub's site documents a narrower nesting policy. No complete site/theme,
Obsidian wikilink/embed/plugin or CSS compatibility is claimed. Implementation
and test strings are original; no external code or fixtures were copied.

#### Tree and typed views

`Alert` and `Callout` are `Hashable`/`Sendable` snapshot views constructed with
`(document, at: nodeIndex)`. Invalid indices, other kinds or malformed typed
payload shapes return nil. `Alert` provides `category` and full quote `range`;
`Alert.Category` supplies the five names and English `defaultTitle` strings.
`Callout` provides normalised `type`, canonical `style`, `fold` (`.none`,
`.expanded`, `.collapsed`), `title`, `hasCustomTitle`, optional `titleNode`
and full `range`. A custom `title` is source-spelled Markdown with replacement
decoding for malformed UTF-8/NUL; original bytes remain in `Document.source`.

Final custom block containers are `alerts.block` and `callouts.block`, with
the original quote range and ordinary body children. Their string attributes
are `type`, plus callout `fold` and optional custom `title`. A custom callout
title is the first child, a `callouts.title` block containing one paragraph
whose inlines are parsed by the normal controller. It retains the exact title
range/segment. Generated titles have no invented source node. Empty wrappers
retain an explicit empty fallback, avoiding phantom marker text/paragraphs.

Recognition first emits an internal `alerts.header` / `callouts.header` leaf
on the marker line. Before inlines, the owning wrapping transform rebuilds
the quote as its custom container and removes the header. Node indices may
change. Consumers must use the returned snapshot rather than retaining node
indices across transforms or revisions.

#### Syntax provenance and transform validation

Header tokens use the owning `alerts.` / `callouts.` namespace:

| Suffix | Exact range |
| --- | --- |
| `marker.open` | `[!` |
| `type` | Original type spelling/case |
| `marker.close` | `]` |
| `fold` (callouts) | Adjacent `+` or `-`, when present |
| `title` (callouts) | Custom title before inline decoding, when present |

Final ownership is the resulting wrapper. Existing core quote/list, body,
title-inline and foreign extension tokens retain role/range and remap to
validated owners. Original BOM/Unicode/CRLF/CR/invalid bytes/NUL remain in
source. Collection off produces identical nodes, fallbacks and HTML with
`tokens == nil`.

`BlockContext.isBlockQuoteStart` identifies a newly opened immediate core
quote on its first physical line with no children. Rules still check their
grammar/indentation; a projected marker alone does not open a core quote.
The signal does not change existing rule selection or precedence.

Tree-rebuilding transforms may remap foreign token owners. The controller
checks a multiset of foreign `(role, range)` spellings: ownership may change
within validated node ranges, but new foreign spellings or extra copies are
rejected before replacing the previous snapshot. Own-namespace tokens remain
extension-controlled. Source identity, collection mode, namespace and tree
validation still apply; callbacks retain their existing compiled-code trust
boundary.

#### Rendering and other services

`AdmonitionHTML.renderer` certifies its built-in
hooks as independent for [prepared HTML groups](#progressive-html). A custom
base hook still requires an explicit `HTMLHookBehavior.independent` promise;
otherwise composition keeps the documented whole-document fallback. Existing
full-string rendering and complete-document title/footnote context are unchanged.

`AdmonitionHTML.renderer(base, alertTitles:calloutTitles:)` lives in the
`GMSetzer` convenience product. It returns an ordinary `HTMLRenderer` with
contextual hooks. Alerts use `<aside>` plus a generated title. Plain callouts
use `<aside>`; foldable callouts use `<details>` and a first `<summary>`, with
`open` only for `+`. Classes/data attributes expose type/style; no stylesheet,
icons, script or external resource is installed. Title dictionaries localise
generated plain-text titles; custom title Markdown retains normal parsing.

The base renderer's URL/raw-HTML/comment policy, GFM tag filter, source anchors
and other hooks remain active. Custom title rendering uses the current composed
renderer and shared tree index, so math hooks and numbered footnote calls work
inside titles as well as bodies. For footnotes, use
`FootnotesHTMLRenderer(renderer: AdmonitionHTML.renderer(base))`. Title source
containers are suppressed after their inlines have rendered in the title.
Source text and generated attributes are escaped; caller-returned HTML retains
the existing hook trust boundary. Hand-built invalid typed payloads fall back
to normal rendering.

Plain `HTMLRenderer` retains its custom-container fallback and displays children
without admonition wrappers/generated titles/folding. Native analysis treats
custom bodies as opaque; the source-order outline still includes body headings.
Library tests do not establish app themes, native disclosure controls, editor
colours or device acceptance.

## Custom extensions

Callbacks must be deterministic and side-effect free: paragraph interruption
may probe a rule before consuming a block. `BlockContext.line(at:)` projects
through active prefixes and ends at a container boundary or EOF.
`SourceLine.physicalRange` retains the entire physical line, `range` and
`contentRange` address the remaining view, and `virtualIndentation` records
residual spaces from a partial tab. Configuration fingerprints must include
parser/implementation versions; a profile hash does not identify callback code.

### Configuration and dispatch

`ExtensionDescriptor` lives in `SetzerSyntax`: identifier, version, owned node
kinds and an option schema. `MarkdownExtension` supplies the parser callbacks;
renderer hooks remain in `SetzerHTML`. A caller catalog can share the same
descriptor without introducing a renderer dependency into the parser.

The parser resolves registrations once at initialization. Configuration issues
have no source range and live in `MarkdownParser.configurationIssues`;
`validated()` rejects them with `ConfigurationError`. Tolerant parsing retains
valid registrations/defaults, skips unavailable or invalid registrations and
rejects invalid option values. Unknown options are ignored after reporting;
a valid default survives an invalid supplied value. Invalid configuration never
becomes an editor underline at `0..<0`.

Extension and rule identifiers use nonempty ASCII components separated by dots; component bytes
are letters, digits, underscores or hyphens. `core` is reserved. Short rule IDs
are qualified once with the extension ID; fully qualified IDs must belong to
that namespace. Custom kinds must be declared and owned. Duplicate selections,
implementations, rule IDs and claimed kinds are configuration issues.

Core and custom rules use one resolved phase registry. The default opening
phase is custom rules (descending priority, then profile order), quote, list.
The default leaf phase is indented code, fence, ATX, thematic break, HTML, then
paragraph fallback. `Profile.disabledRules` uses qualified IDs;
`Profile.ruleOrder` places specified rules first **within their phase**, keeping
unspecified order stable. Phase boundaries, open-container matching and lazy
continuation remain core-owned; paragraph fallback cannot be removed. Setext
and reference definitions have stable enable/disable IDs, but are continuation/
finish rules and cannot be moved by `ruleOrder`. Transform order is profile
order. Unknown, disabled or non-orderable IDs in `ruleOrder` are reported.
Disabling a core rule also disables its paragraph-interruption behavior.

### Parsed custom containers, diagnostics and tokens

A `BlockMatch` consumes a positive bounded number of physical lines. The
callback implements enter/continue/finish by inspecting projected `line(at:)`
views; nil marks EOF or an enclosing quote/item boundary. Optional `children`
are ordered suffix projections of those same physical lines. The core parses
these views over the **same original bytes**, then imports the validated tree
and remaps token owners. No reconstructed Markdown or byte-offset rebasing is
used. `droppingASCII` and `droppingIndentation` retain line endings, physical
columns and residual tab spaces. `droppingBytes` additionally handles
byte-counted Unicode/invalid-UTF-8 prefixes without tabs; the callback chooses
the syntax boundary. Child validation is linear in consumed lines.

Custom parsing adds bounded recursive calls around the iterative core driver.
The combined custom/core container depth is capped by `ParserLimits` (default
128, maximum 256); overflow retains projected literal text and reports the
nesting limit. This is not a claim that arbitrary extension callbacks terminate:
callbacks are trusted compiled-in code and may themselves trap or loop.

Match tokens must use the descriptor namespace; the core assigns their owner.
Match diagnostics use `extensionFinding` with the exact extension owner and
must stay inside the match. Consumption, payload, segments, child order, tokens
and diagnostics are validated **before** builder mutation. Invalid matches fall
back to ordinary parsing with `invalidExtensionResult(qualifiedRuleID)`.

### Original document start

`BlockContext.isDocumentStart` is true only on the original first physical
line, outside containers and projected child parsers. It is a context signal,
not a whitespace/fence recognizer. The [front-matter implementation](#front-matter)
uses it to reject metadata inside quotes, lists or a custom wrapper that
projects the original first line without stripping bytes. This additive
context property does not change existing rule selection or precedence.

### Transform and renderer boundaries

`BlockContext.isBlockQuoteStart` identifies a new immediate core quote on its
first physical line with no children. Alert/callout header rules use this signal
to reserve only the marker line before paragraph/setext/table recognition;
normal body parsing starts on the following line. Wrapping removes the internal
header before inlines. See [Admonitions](#alerts-and-callouts) for grammar, temporary
header kinds, overlap precedence and phase-disable behavior.

`BlockTransform` runs once after block parsing and before inline resolution
when registered in `transforms`. It returns a validated `Document` with identical source bytes and the
same syntax-collection mode. Introduced custom kinds must be declared by its
descriptor; introduced tokens must use its namespace. Existing foreign nodes
and tokens may be retained. Rebuilding may remap a foreign token to a new
validated owner while retaining its role/range. A multiset check rejects new
foreign spellings and counts exceeding the input; own-namespace annotations
remain extension-controlled. A thrown or invalid result preserves the previous
tree and records an invalid runtime extension result. This is distinct from configuration validation. A transform must update semantic text and provenance
together; the alert probe removes its marker from the first text projection.

`ContextualHTMLRendererHook` receives snapshot-bound node index, node, parent,
ancestors and built-in tight-item state. It takes precedence over a legacy hook;
a nil result tries the legacy hook and then normal rendering. A parent index
is built once per render only when contextual hooks are registered. Wrappers
continue to use built-in list child scheduling. Hook HTML remains trusted.

`postInlineTransforms` is a callable phase, with the same source,
namespace and collection-mode validation as pre-inline transforms. Selected
features must still test their own syntax and renderer policies. GFM
features are core built-ins selected by `BuiltinExtension` identifiers, not
`MarkdownExtension` implementations; a supplied implementation with such an
identifier is a configuration issue ([GFM](#gfm)).

### Inline controller

`InlineRule`, `InlineContext`, `InlineMatch`, `DelimiterRequest` and opaque
`DelimiterHandle` replace the removed internal draft. Core and custom rules
run through one cursor/controller. Escapes, code spans and ordinary link structure are
protected entry points; custom triggers then run by explicit `ruleOrder`,
priority and profile order, before core emphasis and text. Consumed code,
link destinations/titles and raw HTML are never redispatched to callbacks.
Core protected entry points cannot be reordered or disabled through this API.
The footnote step adds an explicit `allowsBracketSyntax` opt-in for complete
custom matches at `[` outside open link/image brackets. Existing rules default
to false; bracket matches cannot open/close delimiter handles. Unknown labels
decline before mutation and keep ordinary core bracket parsing.
Trigger membership uses a byte set; the parser does not hash a rule dictionary
for every ordinary text byte. Literal decoding avoids temporary byte arrays
when no escapes/entities/NUL or code-span line-ending normalization is needed.

Callback coordinates refer to a projected leaf `input` (UTF-8 with LF line
endings), not a guessed contiguous range in the original snapshot. `source`
retains the original bytes and `originalRanges(for:)` maps input ranges back
across CRLF and removed container prefixes. Callback token ranges and optional
child ranges use input coordinates; the core converts them to source tokens.

`InlineRule(..., prepare:)` builds a `Sendable` matcher once per snapshot,
after block transforms and before inline traversal. Nested controllers reuse
it, avoiding per-call scans for document-wide definitions. Each subsequent
parse prepares a fresh matcher. Existing `match:` registrations are unchanged;
prepared-rule callbacks have the same compiled-code trust boundary.

Matches must consume a positive bounded number of bytes and declare an owned
custom inline kind. Children/tokens must remain inside the match; children
must be a strictly smaller range. Invalid results report an infrastructure
`invalidExtensionResult` before node/stack mutation and permit literal fallback.
Custom leaf fallback text uses the projected spelling, including replacement
UTF-8/NUL decoding. Existing pre-inline tokens on replaced text are retained
with the containing paragraph/heading as owner.

Custom delimiter callbacks request open/close of an entire run. Flanking,
width, rule identity, current bracket scope and a live eligible handle are
checked by the controller. Identity-bound handles from another parse or rule
cannot close an opener. Unmatched custom delimiters remain literal. Partial
run consumption is deliberately not supported by this contract.
Core emphasis uses the CommonMark delimiter stack, rule of three and
openers-bottom bounds; nodes/stack entries are spliced iteratively. Scratch
storage is reused within one parse, with all stack/handle/protected state reset
between leaves. Declined custom trigger runs cache their end positions.

Complete custom matches may ask the same controller to parse child input.
Those calls have `maximumInlineExtensionDepth` (default 16, maximum 32),
separate from block depth. Overflow emits retained literal children and a
resource diagnostic. Core code/emphasis/link parsing does not recurse.
Callbacks are trusted compiled code: the library cannot interrupt their traps,
loops or arbitrary work. Building eligible custom-handle arrays also has a
cost; selected callbacks must be measured, not assumed free.

## Analysis and suggested fixes

`SetzerAnalysis` depends only on `SetzerSyntax`; it never reparses, renders or
accesses files/UI/network. `NativeAnalyzer.analyze` takes an existing document,
`MarkdownDialect` identity (default `.commonMark`; `.gfm` and custom
non-empty identifiers are possible) and a typed configuration. Rules default to
an empty set. Provider: `gmsetzer.native`, version `GMSetzerVersion.current`
(prepared release identity `1.0.0`). Findings are style warnings. Analysis walks the tree
once per rule family, keeps protected ranges in source order without sorting,
validates suppression bounds with the constant-size boundary check (no position
index) and matches suppressions per rule with a sorted cursor.

| Rule | Scope and example | Advisory fix |
| --- | --- | --- |
| `gmsetzer.heading-level` | Global source-order heading sequence; initial level at most 1, subsequent level at most previous + 1. `# A` then `### B` warns on B | None; changing intended hierarchy is ambiguous |
| `gmsetzer.duplicate-heading` | Repeated decoded heading text, whitespace collapsed; case-sensitive, byte-exact Unicode identity. `# A *one*` then `# A one` warns with related first heading | None |
| `gmsetzer.trailing-whitespace` | Space/tab suffixes in paragraph/heading trivia; skips code, HTML, references, unknown custom contexts and semantic hard breaks. `text SPACE TAB` warns | Remove exact original whitespace |

Headings inside unknown custom containers are excluded. Empty list-marker
whitespace is outside the prose rule: removing it could change Markdown meaning.
Heading findings address the whole offending heading, not an invented marker.
Explicit `NativeSuppression(rule:range:)` values suppress only fully contained
primary findings of that rule. Suppression does not change heading history.
Ranges must follow the source boundary policy. No inline comment directive,
markdownlint compatibility or broader lint catalogue is claimed.

The `NativeAnalysisMessages.text(for:languageTag:)` lookup, shipped in 0.5.0, supplies
English/German text for these findings and the whitespace fix title. English
defaults remain unchanged; heading findings additionally supply the integer
`maximumLevel` argument. Locale selection and display stay with the consumer.
See the [stable message catalogue](#native-message-catalogue) for exact keys,
argument schemas, v0.4.0 compatibility and fallback behavior.

Configuration identities are deterministic, independent of Set ordering and
process hashing. Invalid suppressions throw provider errors, never document
findings; an empty dialect identifier cannot be constructed. CommonMark literal fallbacks remain valid.

### Portable diagnostic and edit values

`DocumentDiagnostic` carries a provider/code, category/severity, message key,
structured arguments/default text, primary location, related locations and
optional advisory fixes. A location is an original `SourceRange`, physical-line
start or explicit document scope. Empty source ranges are caret/insertion
locations; consumers must not widen them to neighboring characters.

Native finding/fix keys and argument schemas are documented in the
[message catalogue](#native-message-catalogue). An optional Foundation-free
English/German lookup is available;
the consumer still chooses its language and owns presentation. Analysis
results retain English defaults and do not depend on a process locale.

`DiagnosticReport` owns the exact source bytes and records provider version,
dialect and configuration identity. It validates findings against that source.
Ordering is source offset (document first), descending severity, code/message
key, then stable emission order. Node indices and finding indices are local to
this result, never identities across edits. Consumers choose their own revision
or content identity outside the library; there is no required session-ID or
revision type.

`SuggestedEdit` stores original-byte ranges, expected bytes and replacement
bytes, preserving malformed UTF-8. `SuggestedFix` sorts edits and rejects invalid
expected lengths, overlap and ambiguous insertion boundaries. All expected
bytes are checked before `applying(to:)` returns a replacement snapshot. It
never mutates an editor, filesystem or application model.

Matching only edited substrings is not a full revision precondition. A consumer
must ensure that the source/configuration used for a chosen fix is still current.
An interactive application applies edits through its own atomic undo/composition-
safe path; a command-line consumer can use the pure byte operation directly.
Platform editing APIs may impose stricter grapheme boundaries. Such consumers
reject unsupported edits rather than rounding or silently widening a range.

### Consumer adapter guidance

A consumer can wrap a result with its own immutable revision/content identity,
parser/provider versions, dialect and configuration fingerprint. It rejects late
results after text/configuration changes. UTF-16 conversion must use the same
original byte snapshot: scalar, replacement-subpart, surrogate and CRLF interiors
are rejected, never rounded. This preserves intended locations after emoji,
combining text, RTL/CJK, malformed bytes or stripped container prefixes.

Interactive consumers schedule parsing off their input path, apply temporary
syntax/diagnostic decorations without text or undo mutations, defer conflicting
updates during marked-text composition, and compose overlapping syntax/search/
diagnostic presentation deterministically. Selection and IME retain priority.
Accessible navigation exposes message and severity as well as color. Fixes are
explicit user choices. These are consumer responsibilities, not UI implementations
or platform types supplied by GMSetzer.

## Native message catalogue

### Presentation without reanalysis

```swift
import GMSetzer

let document = MarkdownParser().parse("# Start\n\n### Next\n")
let report = try NativeAnalyzer.analyze(document,
    configuration: NativeAnalysisConfiguration(rules: [.headingLevel]))
if let finding = report.findings.first {
    let text = NativeAnalysisMessages.text(for: finding.message, languageTag: "de-DE")
    // Überschrift überspringt eine Ebene (höchstens Ebene 2 erwartet).
}
```

Call the same function on `fix.message` for a suggested fix title. Choosing a
language does not parse again, modify a finding/fix, change source ranges or
apply an edit. It is not an analysis configuration option and does not change
`NativeAnalysisConfiguration.identity`. The caller owns locale preferences,
UI updates and any cache of presented strings; include the selected language
in such a presentation cache.

There is no `Locale.current`, global language setting, resource bundle,
Foundation import or runtime dependency. Lookup uses the case-insensitive
primary BCP 47 language subtag: `en`, `en-US`, `EN-gb` select English; `de`,
`de-DE`, `DE-ch` select German. Regions do not select separate translations.
The function is not a complete language-tag validator or locale negotiation
service. Empty/unsupported language identifiers and underscore-style identifiers
such as `de_DE` return the message's exact `defaultText`.

### Stable key and argument catalogue

These keys and the names, types and meaning of required arguments form the
consumer translation contract. Additional keys/arguments may be added; an
existing key or required argument must not be repurposed. Display wording may
improve without changing finding identity or meaning. Argument values are
portable `SyntaxValue` values, not text extracted from an English sentence.

| Message key | Required arguments | English text / `defaultText` | German text |
| --- | --- | --- | --- |
| `gmsetzer.heading-level` | `maximumLevel`: `.integer`, 1…6; highest allowed level at this heading, previous heading level + 1, initially 1 | Heading skips a level (expected at most {maximumLevel}). | Überschrift überspringt eine Ebene (höchstens Ebene {maximumLevel} erwartet). |
| `gmsetzer.duplicate-heading` | None | Heading repeats an earlier heading. | Überschrift wiederholt eine frühere Überschrift. |
| `gmsetzer.trailing-whitespace` | None | Trailing whitespace has no Markdown meaning. | Leerraum am Zeilenende hat keine Markdown-Bedeutung. |
| `gmsetzer.remove-trailing-whitespace` | None; suggested fix title | Remove trailing whitespace. | Leerraum am Zeilenende entfernen. |

The braces above document interpolation; the API returns the final plain
string.
Unknown keys, missing `maximumLevel`, a non-integer value or a value outside
1…6 return the original `defaultText`. Additional arguments are ignored. Old
v0.4.0 heading messages have no structured maximum and therefore keep their
original English text; the lookup does not infer numbers by parsing it.
Other providers' keys are not translated by this catalogue. Lookup never
changes a message key, arguments, the original English fallback, severity,
locations, related locations, fixes or report stamps.
