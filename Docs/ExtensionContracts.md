# M1-C extension and storage contracts

This is the implemented block contract and the executable **draft** of the
M2 inline boundary. It does not implement footnotes, alerts or math as shipped
features. The small rules in `ContainerExtensionTests`, `TransformTests` and
`InlineContractTests` are architecture probes, not feature-conformance tests.

## Configuration and dispatch

`ExtensionDescriptor` lives in `SetzerSyntax`: identifier, version, owned node
kinds and an option schema. `MarkdownExtension` supplies the parser callbacks;
renderer hooks remain in `SetzerHTML`. A caller catalog can share the same
descriptor without introducing a renderer dependency into the parser.

The parser resolves registrations once at initialization. Configuration issues
have no source range and live in `MarkdownParser.configurationIssues`;
`validated()` rejects them with `ConfigurationError`. Tolerant parsing retains
valid registrations/defaults, skips unavailable or invalid registrations and
rejects invalid option values. Unknown options are ignored after reporting;
a valid default survives an invalid supplied value. Invalid configuration never
becomes an editor underline at `0..<0`.

Extension and rule identifiers use nonempty ASCII components separated by dots; component bytes
are letters, digits, underscores or hyphens. `core` is reserved. Short rule IDs
are qualified once with the extension ID; fully qualified IDs must belong to
that namespace. Custom kinds must be declared and owned. Duplicate selections,
implementations, rule IDs and claimed kinds are configuration issues.

Core and custom rules use one resolved phase registry. The default opening
phase is custom rules (descending priority, then profile order), quote, list.
The default leaf phase is indented code, fence, ATX, thematic break, HTML, then
paragraph fallback. `Profile.disabledRules` uses qualified IDs;
`Profile.ruleOrder` places specified rules first **within their phase**, keeping
unspecified order stable. Phase boundaries, open-container matching and lazy
continuation remain core-owned; paragraph fallback cannot be removed. Setext
and reference definitions have stable enable/disable IDs, but are continuation/
finish rules and cannot be moved by `ruleOrder`. Transform order is profile
order. Unknown, disabled or non-orderable IDs in `ruleOrder` are reported.
Disabling a core rule also disables its paragraph-interruption behavior.

## Parsed custom containers, diagnostics and tokens

A `BlockMatch` consumes a positive bounded number of physical lines. The
callback implements enter/continue/finish by inspecting projected `line(at:)`
views; nil marks EOF or an enclosing quote/item boundary. Optional `children`
are ordered suffix projections of those same physical lines. The core parses
these views over the **same original bytes**, then imports the validated tree
and remaps token owners. No reconstructed Markdown or byte-offset rebasing is
used. `droppingASCII` and `droppingIndentation` retain line endings, physical
columns and residual tab spaces. Child validation is linear in consumed lines.

Custom parsing adds bounded recursive calls around the iterative core driver.
The combined custom/core container depth is capped by `ParserLimits` (default
128, maximum 256); overflow retains projected literal text and reports the
nesting limit. This is not a claim that arbitrary extension callbacks terminate:
callbacks are trusted compiled-in code and may themselves trap or loop.

Match tokens must use the descriptor namespace; the core assigns their owner.
Match diagnostics use `extensionFinding` with the exact extension owner and
must stay inside the match. Consumption, payload, segments, child order, tokens
and diagnostics are validated **before** builder mutation. Invalid matches fall
back to ordinary parsing with `invalidExtensionResult(qualifiedRuleID)`.

## Transform and renderer boundaries

`BlockTransform` runs once after block parsing and before the future inline
phase. It returns a validated `Document` with identical source bytes and the
same syntax-collection mode. Introduced custom kinds must be declared by its
descriptor; introduced tokens must use its namespace. Existing foreign nodes
and tokens may be retained. A thrown or invalid result preserves the previous
tree and records an invalid runtime extension result. This is distinct from
configuration validation. A transform must update semantic text and provenance
together; the alert probe removes its marker from the first text projection.

`ContextualHTMLRendererHook` receives snapshot-bound node index, node, parent,
ancestors and built-in tight-item state. It takes precedence over a legacy hook;
a nil result tries the legacy hook and then normal rendering. A parent index
is built once per render only when contextual hooks are registered. Wrappers
continue to use built-in list child scheduling. Hook HTML remains trusted.

Post-inline transforms are **not** a callable phase yet. M2 must add that phase
with core inline dispatch; M4/M5 feature implementations must test their own
syntax, continuation, diagnostics and renderer policy.

## Inline draft to integrate in M2

`InlineContractDraft.swift` is internal, exercised through `@testable` tests;
it is not a public API or an active inline parser. M2 must implement core inline
rules through the same controller as extensions, before promoting these types.

The core owns source cursor progress, code/escape/link protected regions,
flanking/run calculation, delimiter stack, eligible opener handles and mutation.
Callbacks request an inline node, optional child source range, namespaced tokens
and one controlled operation: none, open(width), or close(handle, width).
They never receive mutable stack storage. Validation precedes node/stack
mutation: positive bounded byte consumption (overflow safe), declared inline
kind, contained children/tokens, flanking, run width and a live eligible opener
owned by the same extension. Foreign/stale openers are rejected atomically.

M2 dispatch order is protected core syntax first (escapes, code, link
structure), then eligible inline triggers by explicit precedence, then text.
Delimiter callbacks run only where that controller permits them; delimiter
rules cannot reopen code or link destinations. Math, strike/highlight and wiki
rules require separate syntax tests when implemented. Current draft tests prove
boundary validation and owned handles, **not** actual code-span/link exclusion
or correct CommonMark delimiter-stack behavior. M2 must test those integrations,
nested/adjacent delimiter runs and amortized linear behavior against cmark.

## Snapshot storage decision

`Document.tokens` is one optional generic table `(role, range, owner)`; nil
means collection off, and [] means collected with no tokens. Reference fields
no longer enlarge `ReferenceDefinition`/`NodeData`. `referenceSyntax(for:)`
provides an on-demand convenience view over tokens (linear scan; do not call it
for every node in a large document). Tokens may overlap, retain empty ranges
and remain in emission order. Public construction validates every owner/range.

`DocumentIndex` owns a COW copy of its immutable document and a dense parent
table. It is opt-in, with O(nodes) construction, O(1) parent lookup and O(depth)
ancestor walking. It is **not** an offset-search index. M3 still owes indexed
position queries, boundary/zero-length policy, UTF-16 conversion and outline.

Custom fallback text remains a sparse semantic table: it normalizes line
endings, virtual tabs and replacement decoding and therefore is not a lexical
token. Forcing that text into the source-only token table would conflate two
contracts. `finish` now preserves an omitted fallback; explicit replacement and
`clearFallback(for:)` avoid accidental loss. Snapshot independence is tested.

Per-text strings and per-node segment arrays remain. The benchmark adds
isolated reconstruction probes for both; these are **not** additive attribution
or proof of the savings from a lazy/pool representation. A storage replacement
needs its own controlled before/after run and projection tests. The acceptance
receipt records the measured cost and the numeric M2 allowance; no speculative
lazy-literal migration is needed to declare a larger unmeasured budget.

## M1-D invariant audit

The three parser `try!` sites are deliberate invariant checks, not unchecked
public construction. Append's parent is root or a prior builder result;
container finish receives a prior non-root append result; final build performs
all topology, payload, range, segment, token and fallback checks in release.
Callbacks supply neither builder handles nor topology, and rejected results do
not mutate it. Tests cover hostile consumption, namespaces, ranges, child
order, source changes and recursive expansion. Builder/public validation tests
cover dangling/repeated/unreachable nodes and invalid relationships.

Do not catch a final invariant failure and silently substitute a different
document: that would hide a parser defect. A future recoverable infrastructure
channel must preserve the snapshot and expose the failure separately from lint
findings. Swift callback traps cannot be caught as throwing errors. Current
acceptance retains this explicit fail-fast policy; it does not claim memory
isolation from caller code. Byte helpers guard cursor bounds and tab/line-ending
projection; existing deterministic arbitrary-byte, prefix-heavy, long-delimiter
and maximum-depth cases run in debug/release and on the Linux host.

## Pre-1.0 migration

- Supply `nodeKinds` (and option schemas when used) when constructing a
  `MarkdownExtension`, or share an explicit descriptor.
- Inspect `parser.configurationIssues`/`validated()` instead of the removed
  configuration cases in `ParseDiagnostic.Code`.
- Replace `definition.syntax` with `document.referenceSyntax(for: nodeIndex)`
  or consume the generic `document.tokens` directly.
- Copy `tokens` together with nodes/source/diagnostics/fallbacks when rebuilding
  an annotated document, and call `clearFallback(for:)` for explicit removal.
