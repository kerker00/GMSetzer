# Editor syntax services and lint analysis

Decision: 19 November 2026. **Required for version 1.0; planned, not implemented.**
GMSetzer is also the syntax and native Markdown-analysis engine for Setzkit.
The existing tree/source ranges are prerequisites, not a finished editor or
linter. The current `ParseDiagnostic` reports configuration, extension and
resource-limit problems; it does not yet implement document lint findings.

## Responsibilities

| Service | GMSetzer | Setzkit |
| --- | --- | --- |
| Parsing and syntax checking | Dialect-aware tree, original source and precisely located document diagnostics where a rule applies | Supply immutable snapshot and effective dialect; schedule background work |
| Syntax highlighting | Optional source-spelled syntax spans: role/kind and exact UTF-8 ranges, including delimiters and link parts | Resolve roles through themes and convert ranges to TextKit UTF-16 coordinates |
| Native linting | Optional `SetzerAnalysis` module: deterministic rules over the same `Document`, source and effective rule configuration | Activation, configuration resolution, localized presentation, problem list and underlines |
| Other analyzers | Portable values and extension points; no filesystem, editor or network access | Provide workspace snapshots or additional providers through existing ports |
| Suggested fixes | Explicit edits with original ranges and expected source text, when justified | Validate snapshot/configuration and apply only on user action through `EditTransaction` |

`SetzerAnalysis` will depend on `SetzerSyntax`, not UI, the HTML renderer or an
additional parser. `SetzerSyntax` will own portable diagnostic/span/fix values.
The parser must not depend on the analysis module. Native analysis reuses an
existing parse; it must not parse the same snapshot again. A separate text-only
provider can still run independently when it does not consume GMSetzer's tree.

No new package target/API is claimed by this planning change. Introduce the
module with its first tested native rules, by the M3 editor-integration gate.

The M1 HTML/reference step now offers specialised optional reference provenance
through `collectSyntaxDetails` and `ReferenceDefinition.syntax`. This preserves
exact components and markers for future editor consumers; general syntax spans,
document diagnostics, UTF-16 underlines and the native rule engine remain planned.

## Markdown validity and findings

CommonMark has defined literal-text fallbacks for apparently unfinished markup.
An unmatched emphasis marker, unknown syntax or an unclosed fence is therefore
not automatically a parser error. Possible accidental markup can be an
explicit, configurable lint rule; it must not change the parse or invalidate a
conforming document. Disabled extensions follow the selected dialect and do
not produce false syntax errors merely because another dialect recognises them.

Separate document findings from provider/configuration failures and resource
limits. An unavailable extension or internal analyzer failure must not become a
red underline on arbitrary user text. Parsing and saving remain available when
optional linting is off or fails.

The first native rule catalogue must name supported rule IDs, options, scope
and examples. Candidates include skipped heading levels, inconsistent list
markers, duplicate headings and trailing whitespace, with code/HTML/extension
contexts respected. Text/trivia rules use original source, not rendered HTML
or decoded literals. Native rule IDs use a `gmsetzer.` namespace.

The existing markdownlint plan becomes an optional compatibility/provider path.
Do not claim full markdownlint rule, configuration or suppression compatibility
without an explicit supported matrix and comparison tests. If retained, that
provider uses the same snapshot and diagnostic adapter; it does not define the
syntax semantics of the GMSetzer preview.

## Diagnostic and span contract

The future public values must be immutable and `Sendable`:

- Stable provider and rule/code identifiers, category, severity, and a message
  key plus structured arguments/default text. Setzkit owns localized UI wording.
- A precise primary `SourceRange`, optional related ranges, or an explicit
  document/line-level finding when no exact span exists. Use the offending
  marker/token where possible, rather than underlining its entire block.
- Zero-length insertion locations are retained as such. The editor can use a
  caret/gutter marker; it must not invent a range on a neighbouring character.
- Optional suggested edits, including expected original text. Multiple edits
  must have valid, non-overlapping source ranges; an ambiguous finding has no fix.
- Deterministic ordering and explicit effective dialect/rule configuration.
  Setzkit binds results to session, full text stamp, parser/provider version and
  configuration fingerprint; diagnostic IDs are never identities across edits.

AST node bounds alone are insufficient for syntax decoration. The parser must
retain opt-in lexical spans for opening/closing delimiters, fence markers and
info, link labels/destinations/titles and extension syntax, while keeping
original trivia available. A container's broad range must not be presented as
an exact token range. Omitted annotation collection should avoid its memory
cost for callers such as Quick Look. Roles are semantic; no colors, NSRange,
AppKit or UIKit types enter GMSetzer.

UTF-8 to UTF-16 conversion uses the exact immutable snapshot and the boundary
policy in `SyntaxTree.md`. No guessed scalar rounding or conversion from decoded
content. A marker after emoji, combining text, CRLF or stripped container
prefixes must select the original intended bytes and UTF-16 code units.

## Editor behavior

Setzkit applies syntax roles and diagnostic underlines as temporary decoration,
without changing text, dirty state or undo history. Linting remains off by
default and configurable per app/project/document as specified by Setzkit.
Syntax highlighting and optional document checks have separate activation.

A late result after typing, undo, reopen or a dialect/rule change is rejected
unless its full input stamp still matches. Native typing is never blocked by
parsing/linting. Debounce/cancellation are scheduler concerns; no promise of
instant interruption of arbitrary extension callbacks. Defer intersecting
updates while IME marked text is active. Overlapping syntax/search/diagnostic
roles need deterministic composition; native selection/IME has priority.

Findings remain accessible through a problem list/VoiceOver and text/severity
labels, not color alone. Fixes are advisory and apply only through Setzkit's
strict transaction path; stale fixes are rejected and recomputed.

## Acceptance and milestones

- **Remaining M1:** review which marker/trivia provenance is required by editor
  spans and analyses while completing HTML/reference blocks. Keep parser
  infrastructure diagnostics distinct from future document findings.
- **M2:** implement exact inline and delimiter spans and the portable diagnostic
  contract; test legal literal fallbacks and dialect-specific behavior.
- **M3:** ship position conversion, optional analysis module with a named native
  rule subset, and a Setzkit adapter proof for syntax roles and diagnostic
  underlines. Rendering alone no longer satisfies this integration gate.
- **M4/M5:** cover GFM/additional extension spans, rule context and suppressions;
  opt-in rule profiles must follow the active dialect.
- **M6/M7:** measure parse + optional annotation + analysis costs separately;
  review public analysis API, limits and documentation before 1.0.

Required library tests: precise finding/delimiter spans, Unicode/CRLF and nested
prefixes, invalid-byte policy, related/zero-length ranges, rules on/off,
configuration determinism, suppression scope, excluded code contexts, edit
preconditions, and configuration failures separated from document findings.
Required Setzkit acceptance: correct TextKit ranges, stale-result rejection,
IME/undo protection, overlapping decorations, optional linting, accessible
navigation and explicit fix transactions. These checks are **open**; existing
block/spec tests are not evidence that editor diagnostics are implemented.
