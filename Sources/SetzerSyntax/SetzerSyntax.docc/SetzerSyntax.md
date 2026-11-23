# ``SetzerSyntax``

Represent immutable source-positioned Markdown and portable editor-service values.

## Overview

`Document` validates tree topology, payloads, ranges and token ownership. Source
is the exact original UTF-8 snapshot, including malformed bytes. Ranges are
half-open and node indices are snapshot-local. `DocumentBuilder` supports
extension authors; invalid structures throw during validation.

Construct `SourceIndex` and `DocumentIndex` only when needed. Their values own
the snapshot; consumers must add their own revision identity. Diagnostic and
fix values are advisory and never apply edits or access a text view.

## Topics

### Syntax tree
- ``Document``
- ``DocumentBuilder``
- ``DocumentError``
- ``Node``
- ``NodeKind``
- ``NodeData``
- ``SourceRange``
- ``SyntaxToken``

### Positions and queries
- ``SourceIndex``
- ``SourcePosition``
- ``UTF16Range``
- ``DocumentIndex``

### Findings and fixes
- ``DiagnosticReport``
- ``SuggestedEdit``
- ``SuggestedFix``
- ``DiagnosticMessage``
- ``ParseDiagnostic``

### Identities and extensions
- ``GMSetzerVersion``
- ``MarkdownDialect``
- ``ExtensionDescriptor``
- ``SyntaxValue``
