# M1 HTML blocks and reference definitions

Implemented on 19 November 2026 on `feature/m1-html-references`, building on the
M1 foundation. M2 adds CommonMark inlines, exact lexical spans and decoded
reference lookup; M3 adds UTF-16 conversion, native analysis, safe URL allowlisting and escaped per-node preview IDs (see [M3EditorServices](M3EditorServices.md)). See
[M2Inlines.md](M2Inlines.md) for current functional/acceptance status.

## HTML blocks

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
source-anchor attributes. M2 handles inline raw HTML with the same explicit HTML/comment options,
and generated links/images with decoded URL-scheme checks. Existing source anchors apply to the supported generated block elements.

## Reference definitions

Definitions are extracted from the beginning of a collected paragraph. Labels,
destinations and titles may use their specified continuation lines; blank lines
or a new containing block cannot be crossed. Quoted titles can span lines.
Malformed next-line title candidates fall back to a complete destination line,
leaving the candidate as paragraph content. Malformed same-line titles invalidate
that definition. Labels allow at most 999 Unicode scalars, need a character other than a space/tab/line ending, and do not allow unescaped nested brackets.

Every definition is retained as a node, including duplicates. M2 resolves
references with first-definition-wins lookup, Unicode full folding and collapse of ASCII label
spaces/tabs/line endings. Raw component text has paragraph indentation/container
prefixes removed and line endings normalised. The payload keeps escapes and
entities source-spelled; inline lookup decodes destination/title values once. Original spelling remains in `Document.source` and node segments.

Definitions emit no HTML and do not create phantom visible children that make
a list loose. A setext candidate with only definitions before it stays paragraph
text, rather than becoming an empty heading or a new list item.

## Opt-in editor provenance

`MarkdownParser(collectSyntaxDetails: true)` fills `Document.tokens` with
reference component/marker roles and owning node indices. Use
`document.referenceSyntax(for: nodeIndex)` for the ordered label/destination/
title and bracket/colon/angle/quote view. The default keeps the generic table
nil. These source roles are not a complete syntax-highlighting service or
linter; the M1-C storage contract is in [ExtensionContracts.md](ExtensionContracts.md).

All ranges address original bytes. Container prefixes, CRLF and replacement
UTF-8 decoding never shift them; empty components retain zero-length ranges.
For `> [α]: <>\r\n> "t"\r\n`, the label is `[3, 5)`, the empty destination
`[9, 9)`, and the title `[15, 16)`. Tests validate these exact values and reject
metadata outside its definition node.

## Initial HTML/reference verification (historical)

- 49 library Swift Testing tests pass: original tree/container checks, HTML
  classes/rendering policies, multiline references, exact metadata and all 27
  CommonMark reference-definition examples' expected definition counts.
- Exact conformance HTML baselines: 339/652 CommonMark and 339/672 pinned GFM.
  Trusted fixtures opt into raw HTML and comments; production defaults remain
  separate tests. Remaining HTML-section mismatches require M2 inline markup.
- The Tools tests compare 1,985 plain-text documents by exact HTML and 1,924
  HTML/reference documents by block kind, depth, list properties and literal
  code/HTML content. All 3,909 comparisons agree with pinned cmark. The second
  comparison deliberately excludes inline nodes and retained definition nodes.
- Short malformed-byte/prefix/depth tests pass; the benchmark executable builds.
  New release timings, Linux and the minimum Swift 6.2 toolchain remain unverified.

This was the initial HTML/reference evidence. The subsequent M1-C contracts
and final acceptance matrix are recorded in [M1Acceptance.md](M1Acceptance.md).
M2 now implements inline syntax, entity/escape decoding, reference lookup and
opt-in syntax spans; its technical acceptance passed on the M2 branch. `EditorAnalysis.md` remains the authority for the later editor/lint gate.

M1-C now implements custom parsed children, validated configuration and generic
tokens. The current acceptance matrix and outstanding M2/M3 boundaries are in
[M1Acceptance.md](M1Acceptance.md); the preceding test counts are the historical
HTML/reference implementation evidence.
