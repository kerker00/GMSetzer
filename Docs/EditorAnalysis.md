# Editor syntax services and lint analysis

20 November 2026. **Portable positions, syntax tokens, diagnostic/fix values and
three optional native rules are implemented; M3 review remains open.**
GMSetzer supplies reusable syntax and analysis services for any Markdown
consumer. Application adapters and UI acceptance belong in the consuming
repository and do not gate this library's release.

## Responsibilities

| Service | GMSetzer | Consumer |
| --- | --- | --- |
| Parsing | Dialect-aware immutable tree and original source | Supply source and effective dialect; schedule work |
| Syntax highlighting | Optional semantic roles and exact UTF-8 lexical ranges | Choose theme and presentation; convert portable ranges to platform coordinates |
| Native linting | Optional `SetzerAnalysis` rules over an existing `Document` | Activation, configuration resolution and localized presentation |
| Other analyzers | Portable findings and advisory edits | Supply authorized context or coordinate additional providers |
| Suggested fixes | Expected original bytes, replacements and validated edit sets | Choose whether to apply; validate current source/configuration and apply atomically |

Library targets depend only on other modules in this package and the Swift
standard library. Public types contain no application session, revision,
transaction, UI framework or editor implementation. `SetzerAnalysis` depends
only on `SetzerSyntax`; it does not import a parser or renderer and never
reparses the supplied document. `SetzerSyntax` owns portable span, diagnostic
and fix values. Engines do not access files, networks or a live editor.

## Syntax and document findings

`MarkdownParser(collectSyntaxDetails: true)` fills the optional `Document.tokens`
table with role, owning node and original UTF-8 range. It covers reference and
fence components, inline delimiters/link parts, escapes/entities, raw HTML and
custom roles. `referenceSyntax(for:)` offers a reference-component view.
`DocumentIndex` supplies parents/ancestors, boundary-aware offset queries and
heading outline. `SourceIndex` converts original byte positions/ranges to
portable UTF-16 offsets/ranges or one-based lines/scalar columns.

The [container marker step](ContainerMarkers.md), merged in PR #18 (`4397819`), adds explicit
quote prefixes and each item's complete list marker. These lexical ranges
exclude indentation/padding and are not inferred from a container's broad
semantic bounds. Collection also retains prefixes on lines consumed by
validated multi-line extensions without recording speculative lookahead.

AST bounds alone are insufficient for exact syntax decoration. A container's
broad range must not be presented as a lexical marker. Semantic content ranges
and lexical token ranges are distinct. Preserve zero-length locations and
original trivia. No colors, Foundation ranges or UI framework types enter the
library; omitted syntax collection avoids its optional storage cost.

CommonMark defines literal-text fallbacks for apparently unfinished markup.
An unmatched emphasis marker, unknown syntax or unclosed fence is not
automatically a syntax error. Optional lint rules must not change the parse or
invalidate conforming Markdown. Disabled extensions do not produce errors merely
because another dialect recognizes them.

`MarkdownParser.configurationIssues` reports configuration failures without
source locations. `ParseDiagnostic` reports extension/resource-limit conditions.
Neither is automatically a document lint finding or an arbitrary red underline.
Native analysis uses the separate `DocumentDiagnostic` and `DiagnosticReport`
values. Provider failures and invalid configuration are distinct from findings.

## Native rules and configuration

`SetzerAnalysis` provides `NativeAnalyzer.analyze(_:dialect:configuration:)`
using the existing document. The enabled rule set defaults to empty. The M3
catalogue names `gmsetzer.heading-level`, `gmsetzer.duplicate-heading` and
`gmsetzer.trailing-whitespace`; scope, examples, exclusions and fixes are in
[M3EditorServices.md](M3EditorServices.md). Text/trivia rules inspect original
bytes, not HTML or decoded literals. Code, HTML, reference and unknown custom
contexts are respected; semantic hard-break whitespace is retained.

`NativeAnalysisConfiguration.identity` deterministically identifies effective
rules and explicit `NativeSuppression` source scopes. Suppressions apply only
to fully contained primary findings of the named rule. They do not alter the
parse or heading history. Invalid ranges and empty dialect identity produce
provider/configuration errors, not text findings. No markdownlint rule,
configuration or inline suppression-language compatibility is claimed.

## Portable diagnostic and edit values

`DocumentDiagnostic` carries a provider/code, category/severity, message key,
structured arguments/default text, primary location, related locations and
optional advisory fixes. A location is an original `SourceRange`, physical-line
start or explicit document scope. Empty source ranges are caret/insertion
locations; consumers must not widen them to neighboring characters.

Native finding/fix keys and argument schemas are documented in the
[message catalogue](NativeAnalysisMessages.md). An optional Foundation-free
English/German lookup is merged in PR #17 (`0434ff5`) and shipped in 0.5.0;
the consumer still chooses its language and owns presentation. Analysis
results retain English defaults and do not depend on a process locale.

`DiagnosticReport` owns the exact source bytes and records provider version,
dialect and configuration identity. It validates findings against that source.
Ordering is source offset (document first), descending severity, code/message
key, then stable emission order. Node indices and finding indices are local to
this result, never identities across edits. Consumers choose their own revision
or content identity outside the library; there is no required session-ID or
revision type.

`SuggestedEdit` stores original-byte ranges, expected bytes and replacement
bytes, preserving malformed UTF-8. `SuggestedFix` sorts edits and rejects invalid
expected lengths, overlap and ambiguous insertion boundaries. All expected
bytes are checked before `applying(to:)` returns a replacement snapshot. It
never mutates an editor, filesystem or application model.

Matching only edited substrings is not a full revision precondition. A consumer
must ensure that the source/configuration used for a chosen fix is still current.
An interactive application applies edits through its own atomic undo/composition-
safe path; a command-line consumer can use the pure byte operation directly.
Platform editing APIs may impose stricter grapheme boundaries. Such consumers
reject unsupported edits rather than rounding or silently widening a range.

## Consumer adapter guidance

A consumer can wrap a result with its own immutable revision/content identity,
parser/provider versions, dialect and configuration fingerprint. It rejects late
results after text/configuration changes. UTF-16 conversion must use the same
original byte snapshot: scalar, replacement-subpart, surrogate and CRLF interiors
are rejected, never rounded. This preserves intended locations after emoji,
combining text, RTL/CJK, malformed bytes or stripped container prefixes.

Interactive consumers schedule parsing off their input path, apply temporary
syntax/diagnostic decorations without text or undo mutations, defer conflicting
updates during marked-text composition, and compose overlapping syntax/search/
diagnostic presentation deterministically. Selection and IME retain priority.
Accessible navigation exposes message and severity as well as color. Fixes are
explicit user choices. These are consumer responsibilities, not UI implementations
or platform types supplied by GMSetzer.

## Validation and remaining milestones

Library tests cover exact delimiter/finding ranges, Unicode/CRLF and nested
prefixes, malformed bytes, related/empty locations, rules on/off, deterministic
configuration, suppression scope, excluded contexts and edit preconditions.
The M3 matrix passes 106 tests across macOS debug/release, minimum Swift 6.2 and
Linux Swift 6.4.2. Evidence is in [M3EditorServices.md](M3EditorServices.md) and
`Validation/M3/receipt.json`. No source/API change accompanies the consumer-
independence documentation clarification.

M4/M5 add GFM/extension-specific spans and rule contexts. M6/M7 measure optional
annotation/index/analysis costs separately and review the public API before 1.0.
Consumer UI/device test reports remain in their own repositories; a green library
suite does not claim that any particular editor integration works.

The [math step](Math.md), merged in PR #21 (`6f166b7`) and shipped in 0.5.0, adds owned `math.fence.*` and
`math.content` spans for opaque inline/display/fenced TeX. Existing source and
UTF-16 mapping apply; no TeX validation findings or editor theme mapping are
implied. Native analysis retains its opaque-custom-content policy.

The [alert/callout step](Admonitions.md), merged in PR #22 (`c9543fe`) and
shipped in 0.5.0, adds owned marker/type/fold/
title spans and remaps original quote/list/body annotations after wrapping.
Title inlines use normal core/extension roles. Source-order outline traversal
includes body headings; native analysis keeps custom containers opaque.
Consumer editor colours and disclosure UI remain separately owned/validated.
