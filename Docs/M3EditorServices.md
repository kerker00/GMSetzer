# M3 editor services

20 November 2026. Implementation on `feature/m3-editor-services`, after M2
merged in [PR #11](https://github.com/kerker00/GMSetzer/pull/11) (`021f110`).
Portable library services are implemented; review/merge remains open.
Application-specific adapters and device acceptance live in consumer repositories.
This repository remains private; publication is a separate owner decision.

## Position and tree queries

`SourceIndex(document.source)` owns the exact original byte snapshot. It converts
UTF-8 byte offsets, zero-based UTF-16 code-unit offsets/ranges, and one-based
physical lines/Unicode-scalar columns. Tabs count as one scalar, combining
scalars separately. A BOM and NUL each contribute one UTF-16 unit; malformed
UTF-8 uses Unicode maximal-subpart replacement decoding. No normalization of
the stored bytes occurs. CRLF advances two UTF-16 units and one physical line.
Its interior, surrogate halves, scalar interiors and invalid-subpart interiors
are rejected with `nil`. Empty and EOF ranges are valid boundaries.

Checkpoints occur at line starts and about every 128 bytes. The opt-in index
uses O(bytes/128 + lines) memory and bounded decoding after binary search,
including on very long lines. It is not constructed by the parser.

`DocumentIndex` adds source-order child tables and `node(atUTF8Offset:affinity:)`.
A constant-size UTF-8 boundary check avoids constructing a position index.
Downstream uses `[start,end)`, upstream `(start,end]`; zero-length nodes never
capture a caret. Downstream EOF and upstream BOF return the root. Sibling search
is binary followed by boundary/empty-node handling. `outline()` visits the tree
in source order once, returning node/range/level/plain title and nearest preceding
lower-level heading. Plain titles include text, code and image labels, omitting
raw HTML and unknown custom content. Node identities belong to this snapshot.

## Safe HTML and preview anchors

Generated URLs now allow relative addresses and `http`, `https`, `mailto` schemes.
Unknown schemes, `data`, `file`, JavaScript and control/case obfuscations are
blocked independently of raw-HTML permission. A colon after a path/query/fragment
separator is part of a relative URL. Attribute and literal escaping remain in
force. This deliberately narrows the previous scheme denylist; consumers that
explicitly trust every destination can choose `allowUnsafeURLs`.

Raw HTML and hooks remain explicit caller trust boundaries, not a sanitizer.
The trusted-fixture `.conformance` setting retains exact spec behavior.
`sourceAnchorPrefix` adds escaped, unique per-node IDs to generated block tags;
`includeSourceRanges` independently adds original byte bounds. IDs are namespaced
by the caller and are not stable across edits. Tight paragraphs have no generated
tag; their containing list item still has an anchor. Raw HTML is not rewritten.
Contextual hooks receive `sourceAnchorID` and own any wrapper/anchor they emit.

## Native analysis catalogue

`SetzerAnalysis` depends only on `SetzerSyntax`; it never reparses, renders or
accesses files/UI/network. `NativeAnalyzer.analyze` takes an existing document,
dialect identity and a typed configuration. Rules default to an empty set.
Provider: `gmsetzer.native`, version `0.1.0-m3`. Findings are style warnings.

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

Configuration identities are deterministic, independent of Set ordering and
process hashing. Invalid suppressions or empty dialect identities throw provider
errors, never document findings. CommonMark literal fallbacks remain valid.

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

## Library evidence and limits

106 library tests (99 parser/service + 7 spec/normalizer) pass on macOS Swift
6.4.2 debug/release, minimum Swift 6.2, and Linux x86_64 Swift 6.4.2/glibc 2.44.
All 652 CommonMark and 641 protected GFM examples remain. Linux validation
exported only this package's manifest, sources and tests to a temporary directory;
no consumer repository was involved. Commands and library source/test hashes
are in `Validation/M3/receipt.json`.

The independence clarification changes documentation and report ownership only;
public APIs, implementation and specification baselines are unchanged. Additional
standalone-build and dependency/import audit evidence is recorded separately in
`Validation/M3/independence.json`. Consumer-specific integration reports are kept
in the consuming repository.

Fresh performance measurements remain pending. M2 timings do not measure the
optional indexes, native analysis or a consumer's presentation work. Full tree
validation and eager public text values remain intact. Library review and
owner-confirmed publication remain separate steps.
