# ``SetzerAnalysis``

Analyze an existing Markdown snapshot using explicit native rules.

## Overview

No rule is enabled by default. The provider checks heading-level jumps,
duplicate headings and trailing whitespace; it is not a complete linter.
Callers choose rule subsets and source-scoped suppressions. Findings and
suggested fixes retain byte locations and original-byte preconditions, without
UI, file I/O, implicit parsing or source mutation.

`NativeAnalysisMessages` supports explicit English/German lookup. Unknown
language tags, keys or invalid arguments retain a message's default text.
Applications can use the stable key/argument catalogue for other translations.

## Topics

### Native rules
- ``NativeAnalyzer``
- ``NativeRule``
- ``NativeAnalysisConfiguration``
- ``NativeSuppression``
- ``NativeAnalysisError``
- ``NativeAnalysisMessages``
