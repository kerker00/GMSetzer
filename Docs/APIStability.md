# Proposed 1.0 compatibility contract

23 November 2026. This is the API review candidate for M8, not a declaration
that 1.0 is released. The latest published version remains 0.6.0. The owner
requested development toward 1.0 and Swift Package Index publication; final
API acceptance, an exact release commit, tagging and publication remain separate.

## Supported surface

All six public library products remain supported: `GMSetzer`, `SetzerSyntax`,
`SetzerParser`, `SetzerExtensions`, `SetzerHTML` and `SetzerAnalysis`.
`GMSetzer` continues re-exporting the five lower-level modules. None acquires
a runtime dependency, platform UI framework, file/network access or consumer
checkout requirement. Swift 6.2 and the existing declared Apple deployment
minimums (macOS 15, iOS 18, visionOS 2) are the proposed 1.0 floor; Linux remains
supported. Actual runtime/minimum-compiler evidence has its own recorded scope.

The source API inventory is [API/1.0-candidate.json](API/1.0-candidate.json).
It records 611 source-declared public symbols and their declared conformances,
including the GFM profile extension, without source paths or line numbers.
Compiler-synthesised declarations and re-export duplicates are not counted as
new owned declarations. It is a review baseline until 1.0 acceptance.

## 1.x policy

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

## Coordinates, validation and ownership

`SourceRange` uses half-open original UTF-8 byte offsets; its constructor
requires non-negative ordered bounds. Fitting a particular snapshot is a
separate validation obligation. `Document` checks topology, ranges, payloads
and tokens in release builds as well as debug builds. `DocumentBuilder`
supports constructing valid trees; indices remain local to the result.

`SourceIndex` rejects invalid scalar/surrogate/CRLF boundaries instead of
rounding. Source positions use physical lines and Unicode-scalar columns;
UTF-16 is a separate coordinate API. `DocumentIndex`, outlines, tokens,
diagnostics and suggested edits belong to one snapshot. Consumers own revision
identity, caches, undo/IME integration and scheduling. Fixes are advisory and
retain original-byte preconditions.

## Parser, extensions and HTML

Direct parsing remains tolerant of configuration issues, exposing them through
`configurationIssues`. Strict callers use `validated()`. The new `MarkdownHTML`
entry points validate before parsing and reuse the existing `MarkdownParser`
as their single grammar/limit/token configuration. No duplicate profile or
extension-selection vocabulary is introduced.

Selected footnotes, alerts and callouts receive the existing standard HTML
recipes. Front matter retains its escaped fallback unless explicitly hidden
with a caller hook; math remains opaque with caller-owned presentation. The
lower-level renderer APIs retain their existing behaviour and composition.

Raw HTML stays escaped, comments omitted and dangerous decoded URL schemes
neutralised by default. Explicit renderer opt-ins and hook output remain
caller trust boundaries. `HTMLRenderer.conformance` is for trusted fixtures.

Progressive HTML still starts from a complete document, retains immutable
context, exposes structural/fallback modes and honours pull/cancellation
contracts. Group size is a soft source-byte budget, not a memory cap. Container
and inline-extension depth limits do not bound arbitrary callbacks or total
input/time/output. Input streaming remains outside 1.0.

## Review and regression checks

Build DocC and check the inventory with:

```sh
python3 -I Scripts/build_documentation.py
python3 -I Scripts/check_public_api.py --graph-dir .build/documentation/build
```

The checker rejects removed/changed declarations, lost conformances and cases
added to existing enums, while allowing additive methods/types. Five Python
regressions exercise these boundaries. A new baseline is created only with
`--write-baseline`, which refuses to overwrite an existing file. Do not reset
the baseline to hide a breaking change.

Symbol graphs do not establish behavioural compatibility, default-argument
values, raw string identifiers, binary ABI or specification correctness. Those
remain source review, protected tests and release-review responsibilities.
