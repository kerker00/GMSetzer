# M3 editor services

20 November 2026. Implemented after M2
merged in [PR #11](https://github.com/kerker00/GMSetzer/pull/11) (`021f110`).
Portable library services were reviewed ([Review-M3](Review-M3.md)) and merged
in [PR #12](https://github.com/kerker00/GMSetzer/pull/12) (`651af17`).
Application-specific adapters and device acceptance live in consumer repositories.
This repository remains private; publication is a separate owner decision.

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

## Safe HTML and preview anchors

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

## Native analysis catalogue

`SetzerAnalysis` depends only on `SetzerSyntax`; it never reparses, renders or
accesses files/UI/network. `NativeAnalyzer.analyze` takes an existing document,
`MarkdownDialect` identity (default `.commonMark`; `.gfm` and custom
non-empty identifiers are possible) and a typed configuration. Rules default to
an empty set. Provider: `gmsetzer.native`, version `GMSetzerVersion.current`
(currently `0.5.0-dev` on the unreleased marker branch, following PR #17's
`0.4.1-dev`; neither is a published tag). Findings are style warnings. Analysis walks the tree
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

The unreleased `NativeAnalysisMessages.text(for:languageTag:)` lookup supplies
English/German text for these findings and the whitespace fix title. English
defaults remain unchanged; heading findings additionally supply the integer
`maximumLevel` argument. Locale selection and display stay with the consumer.
See the [stable message catalogue](NativeAnalysisMessages.md) for exact keys,
argument schemas, v0.4.0 compatibility and fallback behavior.

Configuration identities are deterministic, independent of Set ordering and
process hashing. Invalid suppressions throw provider errors, never document
findings; an empty dialect identifier cannot be constructed. CommonMark literal fallbacks remain valid.

## Portable integration boundary

All public values and operations are independent of consumers. `Document`,
`SourceIndex`, `DocumentIndex`, syntax roles, `DiagnosticReport` and advisory
edits are usable by editors, command-line tools and servers. No application
session/revision type, UI framework or sibling checkout is required. Library
targets import only other modules of this package and the Swift standard library.

Consumers keep their own revision identity, scheduling, localization, themes,
platform range mapping and atomic edit/undo policy in their adapters. The library
has no reverse dependency on those adapters. Interactive UI and device acceptance
belong to consumers; they do not block this package's milestones or release.
See [EditorAnalysis](EditorAnalysis.md) for general adapter guidance.

## Rebuild cost and scheduling

Every service is snapshot-bound and rebuilt in O(n) for a new document version:
parse, then optional `SourceIndex`, `DocumentIndex` and analysis. Incremental
updates are out of scope for M3. Consumers should debounce or coalesce edits and
build only the indexes a feature needs.

## Library evidence and limits

The original implementation passed 106 library tests (99 parser/service + 7
spec/normalizer) on macOS Swift 6.4.2 debug/release, minimum Swift 6.2, and Linux
x86_64 Swift 6.4.2/glibc 2.44. After the [M3 review](Review-M3.md) corrections,
108 tests (101 + 7) pass on macOS Swift 6.4.2 debug; Swift 6.2 and Linux were
not re-run. A differential probe compared `275a69b` with the corrected tree over
2,958 documents (every CommonMark/GFM example as LF and CRLF, a 20 KB benchmark
corpus, 300 pseudo-random byte strings including invalid UTF-8 and NUL, and long
lines around checkpoint boundaries): every UTF-8/UTF-16/line-column conversion,
caret query in both affinities, parent/ancestor table, outline, anchored and safe
HTML output and analysis report (with and without suppressions) is byte-identical.
All 652 CommonMark and 641 protected GFM examples remain. Linux validation
exported only this package's manifest, sources and tests to a temporary directory;
no consumer repository was involved. Commands and library source/test hashes
are in `Validation/M3/receipt.json`.

The independence clarification changes documentation and report ownership only;
public APIs, implementation and specification baselines are unchanged. Additional
standalone-build and dependency/import audit evidence is recorded separately in
`Validation/M3/independence.json`. Consumer-specific integration reports are kept
in the consuming repository.

Performance of the indexes, queries, outline and analysis is recorded in
[Benchmarks](Benchmarks.md#m3-editor-services-20-november-2026): at 1 MB the
optional services add 4.9 ms in isolation and 6.7 ms in a combined snapshot
to a 27.6 ms parse, and queries allocate
nothing. A consumer's presentation work is not measured here. Full tree
validation and eager public text values remain intact. Library review and
owner-confirmed publication remain separate steps.
