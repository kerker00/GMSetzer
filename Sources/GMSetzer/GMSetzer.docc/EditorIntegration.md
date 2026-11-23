# Source positions and analysis

Keep syntax, positions, findings and suggested edits tied to one original snapshot.

## Coordinates

`SourceRange` uses half-open UTF-8 byte offsets. `SourceIndex` converts these
to UTF-16 code units and one-based physical line/Unicode-scalar columns.
Columns are not visual widths or LSP UTF-16 columns. Tabs count as one scalar.
CRLF is one newline with two UTF-16 units and no addressable interior.
Invalid scalar/surrogate boundaries return nil; conversion never rounds.

```swift
let document = MarkdownParser(collectSyntaxDetails: true).parse("# 👋\n")
let sourceIndex = SourceIndex(document)
let range = sourceIndex.utf16Range(for: document.root.range)
let outline = DocumentIndex(document).outline()
let tokens = document.tokens
```

Token collection is opt-in. Node indices, tokens, positions, outlines and
diagnostics must never be combined across revisions. The package does not
assign application session or revision identities.

## Native analysis

```swift
let report = try NativeAnalyzer.analyze(document, dialect: .commonMark,
    configuration: NativeAnalysisConfiguration(rules: [.headingLevel]))
```

No rule runs by default. The three rules check skipped heading levels,
duplicate headings and trailing whitespace; this is not a complete linter.
`NativeAnalysisMessages` supplies optional English/German lookup from message
keys and arguments, with default-text fallback. Consumers can supply their
own localisation and presentation.

Suggested edits retain exact original-byte preconditions. Validate the report
against the current snapshot, request a chosen fix explicitly, and apply it
through the caller's undo/IME-safe transaction. Analysis never mutates source.
