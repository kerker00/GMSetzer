# 1.0 source compatibility contract

23 November 2026. Release preparation freezes the source API reviewed in M8,
merged through PR #30 at `5f81308`. The owner requested this preparation after
confirming the merge. The latest published preview remains 0.6.0; choosing an
exact merged release commit, tagging and publication remain separate steps.

## Supported surface

All six public library products remain supported: `GMSetzer`, `SetzerSyntax`,
`SetzerParser`, `SetzerExtensions`, `SetzerHTML` and `SetzerAnalysis`.
`GMSetzer` continues re-exporting the five lower-level modules. None acquires
a runtime dependency, platform UI framework, file/network access or consumer
checkout requirement. Swift 6.2 and the existing declared Apple deployment
minimums (macOS 15, iOS 18, visionOS 2) are the declared 1.0 floor; Linux remains
supported. Actual runtime/minimum-compiler evidence has its own recorded scope.

The frozen source API inventory is [API/1.0.0.json](API/1.0.0.json). Its module
records are exactly equal to the [review inventory](API/1.0-candidate.json),
which remains unchanged as historical evidence. Its 611 export records include 610 source-declared public symbols
and one presentation-only `extension Profile` grouping node. Checks normalise
that grouping node while retaining the actual `Profile` type, the GFM member
and declared conformances. The baseline is preserved without source paths or line numbers.
Compiler-synthesised declarations and re-export duplicates are not counted as
new owned declarations. This is the compatibility baseline used by release
and subsequent 1.x CI.

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
python3 -I Scripts/check_public_api.py --graph-dir .build/documentation/symbolgraph
```

The checker rejects removed/changed declarations, lost conformances and cases
added to existing enums, while allowing additive methods/types. Regression
tests exercise these boundaries. Further checks cover extraction-format
normalisation without accepting removal of the defining type or its extension
members. A new baseline is created only with
`--write-baseline`, which refuses to overwrite an existing file. Do not reset
the baseline to hide a breaking change.

Swift 6.2 omits `@Sendable` in some callback display signatures. Only this
display omission is accepted, and only when the complete actual source header
matches the baseline's lexical tokens, including each annotation's position.
A missing annotation, an annotation on another parameter or one found only
inside a function body still fails. The candidate baseline is not rewritten
to accommodate the older compiler.

Symbol graphs do not establish behavioural compatibility, default-argument
values, raw string identifiers, binary ABI or specification correctness. Those
remain source review, protected tests and release-review responsibilities.
