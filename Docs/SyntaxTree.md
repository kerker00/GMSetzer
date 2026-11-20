# Syntax tree contract — M1 blocks and containers

Status: M1-C contract updated on 20 November 2026. This is the contract for the current
Swift values, with explicit extension points for the remaining parser phases.
The Markdown input language is governed by CommonMark and the pinned GFM
fixtures. There is no ANTLR grammar or generated parser/runtime dependency.

Editor syntax checking, semantic syntax spans and native lint findings are now
explicit planned consumers of this model; see [EditorAnalysis.md](EditorAnalysis.md).
Node ranges alone do not constitute a finished highlighter or linter. Preserve
original marker/trivia provenance as the remaining block/inline payloads grow.

## Values and construction

`Document` owns the original `[UInt8]`, an immutable `[Node]` and parse
diagnostics, optional generic `tokens`, plus sparse `customLeafFallbacks` keyed
by custom leaf index. It is
`Sendable`. Root index is always zero; indices belong to
one document snapshot, not to later parses. Setzkit owns snapshot revisions
and configuration fingerprints outside this module.

`Node.data` is a typed `NodeData` enum. `Node.kind` is derived from it, so a
heading cannot accidentally carry code-block data. `NodeKind` names identify
renderer hooks and custom kinds; they do not replace typed built-in payloads.

| Current payload | Children | Meaning |
| --- | --- | --- |
| `document` | Block nodes | Root covering the entire original input |
| `paragraph` | Inline nodes | A leaf block's inline content |
| `heading(level:)` | Inline nodes | ATX/setext heading, level 1 through 6 |
| `text(String)` | None | Literal text, currently without inline markup decoding |
| `softBreak` | None | A physical line break between inline content lines |
| `thematicBreak` | None | Horizontal rule |
| `codeBlock(info:literal:)` | None | Optional fence info and literal code |
| `referenceDefinition` | None | Raw label, destination and optional title; emits no HTML |
| `htmlBlock(HTMLBlock)` | None | CommonMark start/end class and normalised literal; escaped by default |
| `blockQuote` | Block nodes | Quoted blocks, including nested containers |
| `list(ListAttributes)` | List items only | Bullet marker or ordered start/delimiter, plus tightness |
| `listItem` | Block nodes | Item content; its range includes its own marker |
| `custom(kind:role:attributes:)` | See below | Namespaced extension kind with portable data |

`SyntaxValue` supports strings, integers, booleans, arrays and objects. A custom
inline node can contain inline children; a custom block can contain block or
inline children, with list items allowed only under lists. Extension-specific restrictions are the extension's
responsibility. A built-in leaf cannot have children. New built-in payloads
will be introduced with their corresponding parser support, rather than
pretending that all syntax is already implemented.

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
there is no unchecked parser-only construction path. The M1-B benchmark and
local budget gate cover the cost of this validated construction.

The parser treats a failure of its own builder validation as an implementation
invariant violation. Extension match results are checked before insertion, so
malformed returned ranges or consumption counts do not reach that boundary.

## Source ranges and literals

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
- A segment is provenance, not a guarantee that slicing it equals the decoded
  literal. Code line endings become LF; a missing final code newline is
  synthesised. A tab partially removed by a container prefix or indentation contributes residual
  virtual spaces, and the corresponding source segment includes that tab byte.
- `parse(bytes:)` preserves malformed UTF-8 exactly in the source array. Literal
  decoding uses Swift UTF-8 replacement decoding and replaces NUL with U+FFFD.
  The `String` entry point feeds its UTF-8 bytes into the same path.

Tabs advance to the next four-column stop for block indentation. Position
conversion will use zero-based UTF-16 offsets and one-based lines/Unicode
scalar columns (a tab counts as one scalar, separately from visual indentation).
Offsets inside a UTF-8 scalar, a replacement-decoding subpart or a CRLF pair
will be rejected, so conversions cannot silently round source locations.
The converter is still M3 work. No source-to-rendered-character map is implied
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

## Open containers and limits

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

## Profiles and extension rules

`Profile` is a hashable name and ordered `[ExtensionConfiguration]`, including
portable options. `MarkdownExtension` supplies code separately to
`MarkdownParser(profile:extensions:)`; registration alone does not activate
syntax. Missing implementations, duplicate identifiers, unknown options/rules
and namespace violations become `MarkdownParser.configurationIssues`, separate
from source findings. `validated()` throws if any are present.
Keep parser/registry versions in the caller's configuration fingerprint: a
profile hash does not identify callback implementation code.

The registry implements leaf blocks, optional core-parsed child projections and
post-block transforms. Descriptors declare versions, owned kinds and option
schemas in `SetzerSyntax`. Default priority/profile order is preserved;
`disabledRules` and `ruleOrder` configure shared core/custom rule identities
within fixed phases. [ExtensionContracts.md](ExtensionContracts.md) defines the
exact phases, validation and draft inline boundary.

Callbacks receive an immutable current line and their selected options.
`BlockContext.line(at:)` projects following physical lines through the active
container prefixes and returns nil at a container boundary or EOF. It replaces
the original raw `.lines` array. `SourceLine.physicalRange` retains the entire
physical line; `range`/`contentRange` address the remaining view, and
`virtualIndentation` records residual spaces from a partial tab. Multi-line
matches are checked against the same boundary before consumption.

Callbacks must
be deterministic and side-effect free; paragraph interruption can probe a rule
before the block is consumed. Return nil for no match. A successful `BlockMatch`
must consume at least one remaining physical line and produce a non-reserved
custom block kind with in-range, ordered source segments. Invalid results are
reported and ignored; the normal parser retains the source. Callbacks are
trusted code: validation cannot interrupt a callback that itself never returns.

`.gfm` now explicitly selects its five extensions. Until M4 provides their
implementations, each unavailable extension is reported instead of silently
claiming implemented GFM support.

## Rendering

`SetzerHTML` imports only `SetzerSyntax`. Rendering and validation use iterative
traversal, including for deeply nested custom trees. Built-in text/code/info
strings are HTML-escaped. Recognised HTML blocks are escaped and their comments
omitted by default; raw output and comment preservation are separate explicit
options. Inline raw HTML recognition remains M2 work. See
[HTMLReferences.md](HTMLReferences.md) for exact policies.

Hooks are keyed by kind. They can replace a node with caller-supplied HTML,
wrap rendered children, or return nil for normal rendering. **Hook output is
trusted caller output.** Use `HTMLRenderer.escape` on source-derived values.
Unknown custom containers render children; unknown custom leaves preserve their
escaped projected source through `Document.customLeafFallbacks`. The parser
records consumed lines after container-prefix projection, including residual
virtual tab spaces, replacement-decoded UTF-8/NUL and LF-normalised original
line endings. It does not add a newline at EOF. This is independent of
extension-provided semantic `sourceSegments`, which can omit delimiters or line
endings. Neither `Node` nor `NodeData` gains a per-node fallback field.
Hand-built trees can provide a fallback through the builder or document
initializer; without it, unknown custom leaves retain escaped raw node-range
bytes as before. Copy fallback metadata when reconstructing such a document.

`wrapChildren` retains built-in list/item child semantics, including tightness,
paragraph separators and omission of non-rendered reference definitions.
Nested quotes and lists retain their own paragraph/tightness rules. Hooks own
their opening/closing markup and whitespace; a list-item hook must include any
desired newline in its opening markup. Contextual hooks additionally receive
node identity, parent/ancestors and tight-item state through an opt-in index.

Optional `data-source-start`/`data-source-end` block attributes
are off by default, so source anchors do not change conformance comparisons.

## Current boundary and next work

The internal block driver is split into container matching, leaf continuation,
container opening and leaf starts; [BlockPhases.md](BlockPhases.md) records the
ordering/progress contract. M1-C extends those boundaries with the resolved registry.

This implementation supports block quotes, ordered/bullet lists and lazy
continuation, as well as paragraphs, ATX/setext headings, thematic breaks,
fenced/indented code, all seven HTML block classes, multiline reference definitions and literal
text/soft breaks. It deliberately does not claim all examples in those spec
sections: inline escapes/entities and code info decoding belong to M2.

M1-A fixes leading BOMs, wrapper tightness and custom-leaf fallback projection.
M1-B records comparable measurements and checked validation improvements.
M1-C implements/proves extension and storage contracts; M1-D audits the builder
invariants and hardening checks. The current acceptance decision and measured
inline allowance are in [M1Acceptance.md](M1Acceptance.md).
M2 adds inline payloads/rules and reference decoding/case folding. M3 completes
position queries, outline, renderer safety options and integration. GFM and the
additional dialect extensions retain their planned milestones.

The editor-analysis contract adds opt-in delimiter spans and a future portable
document-diagnostic/fix model in M2, then native analysis and a diagnostic
underline integration proof in M3. Current `ParseDiagnostic` is infrastructure
reporting; do not present every such condition as an error in document text.

`collectSyntaxDetails: true` collects the optional generic `Document.tokens`
table, with exact source roles, node owners and zero-length locations.
`referenceSyntax(for:)` offers a reference-component view over that table.
`DocumentIndex` provides opt-in, snapshot-owned parents and ancestors; offset
search and editor diagnostics remain M3 work. The implemented registry,
container/transform boundary, hook context and internal inline draft are
specified in [ExtensionContracts.md](ExtensionContracts.md).

Historical M1-A validation: all 57 library Swift Testing tests pass with Swift 6.4.2, including the
three documented trees, invalid topology/extension results, mixed line endings,
UTF-8/NUL handling, concurrent snapshots and short adversarial-input smoke
tests. The protected exact-HTML baseline is 339/652 CommonMark and 339/672 GFM.
Eight combination tests add BOM/offset, wrapper/container and projected fallback
coverage, including fallback metadata validation and immutable builder snapshots.
Tools compare 1,985 documents by exact HTML, 1,924 HTML/reference documents
by block depth/properties/literals and ten leading-BOM cases against pinned
cmark; all agree. The block
quote/list sections now pass including their HTML-comment cases. These counts
do not claim implemented inline or GFM extensions.
The measured M1-B release baseline and annotation cost are in
[Benchmarks.md](Benchmarks.md#m1-b-measured-baseline-and-checked-validation).
Subsequent [portability verification](Portability.md) builds with Swift 6.2,
passes all 57 macOS tests with a compatible SDK, and executes the protected spec
baseline plus targeted checks on static Linux ARM64. The phase extraction also
passes all 57 tests on Linux x86-64/glibc with Swift 6.4.2. Full Linux Swift 6.2
suite coverage and minimum Apple OS runtime checks remain open.

The current M1-C/M1-D verification and acceptance decision superseding the
historical counts above are recorded in [M1Acceptance.md](M1Acceptance.md).
