# ``SetzerParser``

Parse CommonMark and explicitly selected extensions over original UTF-8 bytes.

## Overview

`MarkdownParser` is an immutable, Sendable configuration. Validate it before
strict use; direct parsing tolerates configuration issues and exposes them
through `configurationIssues`. A profile selects identifiers and options;
implementation objects alone do not select grammar. GFM is implemented in the
core and selected by the GFM profile supplied by `SetzerExtensions`.

Depth limits protect built-in container/custom-inline recursion. They do not
limit input bytes, elapsed time, output size or work in caller callbacks.
Block contexts expose original snapshot ranges; inline contexts project bytes
back to that snapshot. Custom nodes, tokens and transforms must obey their
declared namespaces and validated range/ownership contracts.

## Topics

### Parsing and configuration
- ``MarkdownParser``
- ``Profile``
- ``ParserLimits``
- ``ExtensionConfiguration``
- ``MarkdownExtension``
- ``BuiltinExtension``
- ``CoreBlockRule``

### Custom syntax
- ``BlockRule``
- ``BlockContext``
- ``BlockMatch``
- ``BlockToken``
- ``SourceLine``
- ``InlineRule``
- ``InlineContext``
- ``InlineMatch``
- ``BlockTransform``
