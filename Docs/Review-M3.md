# M3 review — 20 November 2026

Scope: code, public API and architecture of `feature/m3-editor-services`
(`275a69b`, three commits on top of `main` at `89e3f46`), with emphasis on the
performance of the new editor services. Reviewed: `SourceIndex`,
`DocumentIndex` (child tables, caret lookup, outline, plain text),
`SetzerAnalysis/NativeAnalyzer`, the `SetzerHTML` URL and anchor changes, and
the accompanying tests and [M3EditorServices.md](M3EditorServices.md). This
review records findings and recommendations only; no library code was changed.
Cost statements are estimates from reading the code; fresh measurements are
milestone step 3.

**Follow-up, 20 November 2026:** all items were addressed on the same branch
before merge; items 10 (global outline) and 11 (configurable scheme set) were
decided as described in [M3EditorServices.md](M3EditorServices.md). Results are
byte-identical to `275a69b` in a differential probe over 2,958 documents and
108 tests pass. The findings below remain the historical review record.

## Summary

No definite correctness defect was found. Boundary handling is careful: CRLF
interiors, surrogate halves, maximal-subpart replacement for invalid UTF-8,
downstream/upstream affinity at BOF/EOF, and the protected scopes of the
trailing-whitespace rule (code, HTML, references, custom nodes, hard breaks,
empty list markers). Sibling binary search is sound because `Document.init`
already validates source-ordered, parent-contained siblings.

The architecture, however, reintroduces allocation-heavy and redundant work
that the block parser optimisation (PR #10) removed. Because editors rebuild
these indexes for every document snapshot, the optional services can cost more
than parsing. Items 1–5 should be fixed before the step-3 measurements, so the
recorded numbers describe the code that ships.

## Important: performance and architecture

1. **`DocumentIndex` allocates one array per parent node**
   ([DocumentIndex.swift](../Sources/SetzerSyntax/DocumentIndex.swift)).
   `children: [[Int]]` creates a heap array for every node with children —
   tens of thousands for a 1 MB document, plus retain/release traffic.
   `parents: [Int?]` costs 16 bytes per entry. Recommendation: a CSR layout
   (`childStart: [Int32]`, `childIndices: [Int32]`, `parents: [Int32]` with
   `-1` sentinel), built in two passes (count, prefix sum, fill) with exactly
   three allocations. `ancestors(of:)` could become a non-allocating sequence.

2. **`NativeAnalyzer` builds a full `SourceIndex` only to validate
   suppressions** ([NativeAnalyzer.swift](../Sources/SetzerAnalysis/NativeAnalyzer.swift)).
   This is an O(bytes) decode on every analysis, even when no suppressions are
   configured. `SourceIndex.isBoundary` answers the same question in constant
   time per bound; the index construction can be removed.

3. **`SourceIndex` construction has no ASCII fast path**
   ([SourceIndex.swift](../Sources/SetzerSyntax/SourceIndex.swift)). Every
   scalar goes through `advance` with bounds-checked array access, although
   Markdown is mostly ASCII. ASCII runs without CR/LF can advance column and
   UTF-16 count by the run length using the SWAR technique of
   `LineTerminators` (move `ByteSearch` to `SetzerSyntax` as `package`).
   Checkpoints are 32 bytes and, because every line start is one, roughly as
   numerous as lines; `Int32` fields halve that. `lineStarts` duplicates
   checkpoint information.

4. **`outline()` visits every inline node**
   ([DocumentIndex.swift](../Sources/SetzerSyntax/DocumentIndex.swift)).
   Headings only occur in block containers (document, block quote, list, list
   item, custom containers). Not descending into paragraphs and headings makes
   the traversal O(block nodes) instead of O(all nodes).

5. **Smaller analysis costs**
   - `tree.ancestors(of:)` allocates per heading only to detect a custom
     ancestor; track this during the traversal instead.
   - Three `compactMap` passes over all nodes plus three sorts; one pass can
     fill all three scope lists.
   - Suppression lookup is linear per finding (O(findings × suppressions));
     sort once and use a cursor.
   - A complete `DocumentIndex` is built only for `outline()`; cheap after
     item 1, or replace with an internal `firstChild`/`nextSibling` walk.

6. **Full rebuild per snapshot.** Each keystroke costs parse + `SourceIndex`
   + `DocumentIndex` + analysis, all O(n). Acceptable as the M3 contract, but
   the documentation should state that incremental updates are out of scope
   and that consumers are expected to debounce.

## API

7. **Representation details are public.** `SourceIndex.lineStarts` and
   `source` fix the internal layout. Prefer `lineCount` /
   `utf8Offset(ofLine:)` and keep the arrays internal. `SourceIndex` is not
   bound to a `Document`, so ranges from another snapshot are silently
   accepted; consider `init(_ document: Document)` or a lazily built position
   index owned by `DocumentIndex`.

8. **Scalar columns.** `SourcePosition.column` counts Unicode scalars, while
   LSP and TextKit use UTF-16. Document this prominently, or add a UTF-16
   column query.

9. **Stringly typed identities.** `dialect: String` is untyped and
   `NativeAnalyzer.version = "0.1.0-m3"` will go stale silently. Prefer a
   central version constant and a small dialect type with predefined values.

10. **Outline semantics (owner decision).** Headings inside block quotes and
    list items appear in the outline, and `parentHeading` crosses container
    boundaries. `heading-level` requires a first heading of level ≤ 1, unlike
    markdownlint MD001, which accepts any first level. Both are defensible but
    should be explicit decisions.

11. **HTML.** The URL scheme allowlist is the right default, but it also
    blocks `tel:` and `ftp:`; a configurable allowed-scheme set would be a
    cleaner API than the all-or-nothing `allowUnsafeURLs`. Minor:
    `Self.escape(prefix)` runs per node (escape once in `init`), and
    `sourceAnchorID` builds a string for every contextual hook call.

## Recommended order

1. Fix items 1–5 and 7; decide items 10 and 11 (scheme set).
2. Verify byte-identical results with the differential harness used for PR #10,
   extended to index and analysis output.
3. Measure separately at 100 KB and 1 MB, time and allocations:
   `SourceIndex` build, `DocumentIndex` build, `node(atUTF8Offset:)` and
   position-conversion query latency, `outline()`, and `analyze` with all rules.
