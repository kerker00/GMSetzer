# Extension and storage contracts — M1-C and M2

This is the implemented block and inline contract, including the M2 controller
and opt-in [M5 footnote support](Footnotes.md), merged in PR #20 (`a6a2da6`)
and not yet in a versioned release.
Alerts and math remain planned. The small rules in `ContainerExtensionTests`, `TransformTests` and
`InlineExtensionTests` are architecture probes, not feature-conformance tests.

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
columns and residual tab spaces. `droppingBytes` additionally handles
byte-counted Unicode/invalid-UTF-8 prefixes without tabs; the callback chooses
the syntax boundary. Child validation is linear in consumed lines.

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

## Original document start

`BlockContext.isDocumentStart` is true only on the original first physical
line, outside containers and projected child parsers. It is a context signal,
not a whitespace/fence recognizer. The M5 [front-matter implementation](FrontMatter.md)
uses it to reject metadata inside quotes, lists or a custom wrapper that
projects the original first line without stripping bytes. This additive
context property does not change existing rule selection or precedence.

## Transform and renderer boundaries

`BlockTransform` runs once after block parsing and before inline resolution
when registered in `transforms`. It returns a validated `Document` with identical source bytes and the
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

`postInlineTransforms` is now a callable phase, with the same source,
namespace and collection-mode validation as pre-inline transforms. M5
features must still test their own syntax and renderer policies. M4's GFM
features are core built-ins selected by `BuiltinExtension` identifiers, not
`MarkdownExtension` implementations; a supplied implementation with such an
identifier is a configuration issue ([M4GFM](M4GFM.md)).

## Integrated inline controller (M2)

`InlineRule`, `InlineContext`, `InlineMatch`, `DelimiterRequest` and opaque
`DelimiterHandle` replace the removed internal draft. Core and custom rules
run through one cursor/controller. Escapes, code spans and ordinary link structure are
protected entry points; custom triggers then run by explicit `ruleOrder`,
priority and profile order, before core emphasis and text. Consumed code,
link destinations/titles and raw HTML are never redispatched to callbacks.
Core protected entry points cannot be reordered or disabled through this API.
The footnote step adds an explicit `allowsBracketSyntax` opt-in for complete
custom matches at `[` outside open link/image brackets. Existing rules default
to false; bracket matches cannot open/close delimiter handles. Unknown labels
decline before mutation and keep ordinary core bracket parsing.
Trigger membership uses a byte set; the parser does not hash a rule dictionary
for every ordinary text byte. Literal decoding avoids temporary byte arrays
when no escapes/entities/NUL or code-span line-ending normalization is needed.

Callback coordinates refer to a projected leaf `input` (UTF-8 with LF line
endings), not a guessed contiguous range in the original snapshot. `source`
retains the original bytes and `originalRanges(for:)` maps input ranges back
across CRLF and removed container prefixes. Callback token ranges and optional
child ranges use input coordinates; the core converts them to source tokens.

`InlineRule(..., prepare:)` builds a `Sendable` matcher once per snapshot,
after block transforms and before inline traversal. Nested controllers reuse
it, avoiding per-call scans for document-wide definitions. Each subsequent
parse prepares a fresh matcher. Existing `match:` registrations are unchanged;
prepared-rule callbacks have the same compiled-code trust boundary.

Matches must consume a positive bounded number of bytes and declare an owned
custom inline kind. Children/tokens must remain inside the match; children
must be a strictly smaller range. Invalid results report an infrastructure
`invalidExtensionResult` before node/stack mutation and permit literal fallback.
Custom leaf fallback text uses the projected spelling, including replacement
UTF-8/NUL decoding. Existing pre-inline tokens on replaced text are retained
with the containing paragraph/heading as owner.

Custom delimiter callbacks request open/close of an entire run. Flanking,
width, rule identity, current bracket scope and a live eligible handle are
checked by the controller. Identity-bound handles from another parse or rule
cannot close an opener. Unmatched custom delimiters remain literal. Partial
run consumption is deliberately not supported by this first public contract.
Core emphasis uses the CommonMark delimiter stack, rule of three and
openers-bottom bounds; nodes/stack entries are spliced iteratively. Scratch
storage is reused within one parse, with all stack/handle/protected state reset
between leaves. Declined custom trigger runs cache their end positions.

Complete custom matches may ask the same controller to parse child input.
Those calls have `maximumInlineExtensionDepth` (default 16, maximum 32),
separate from block depth. Overflow emits retained literal children and a
resource diagnostic. Core code/emphasis/link parsing does not recurse.
Callbacks are trusted compiled code: the library cannot interrupt their traps,
loops or arbitrary work. Building eligible custom-handle arrays also has a
cost; selected callbacks must be measured, not assumed free.

`InlineExtensionTests` exercises real code/link exclusion, flanking, owned and
stale handles, projected CRLF offsets, precedence/disable switches, rejected
matches, preserved annotations, recursion limits and post-inline dispatch.
These are architecture probes, not shipped math/highlight/wiki features.

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
