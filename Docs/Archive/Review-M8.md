# M8 API and publication preparation review

> Historical record, archived during 1.0 documentation consolidation. Status,
> counts and plans below describe their original checkpoint. Current contracts
> and workflow are in the [package guide](../README.md) and
> [development handbook](../Development.md).

23 November 2026. Branch `feature/m8-api-docs`, based on merged PR #29
(`49afec9`). This is a local implementation/self-review, not owner acceptance
or a published 1.0. Development identity is `1.0.0-dev.1`.

## Decisions implemented

| Area | Review decision |
| --- | --- |
| Products and dependencies | Retain all six products and their existing dependency direction; no runtime or DocC-plugin dependency added |
| High-level HTML | Add `MarkdownHTML.render` for String/original bytes; validate one existing parser configuration and compose selected standard footnote/admonition recipes |
| Existing clients | Keep all lower-level signatures, tolerant parse behaviour and renderer defaults; front matter and opaque math keep their existing caller policies |
| Source/analysis contracts | Document original-byte snapshots, exact conversion boundaries, advisory fixes, configuration errors versus parse diagnostics and consumer revision ownership |
| HTML safety | Document raw-HTML opt-ins, decoded URL policy and trusted hooks; no generic sanitisation claim |
| Progressive output | Keep complete-document semantics, explicit fallbacks, soft group size and event-level cancellation; no input-streaming/memory guarantee |
| Public API tracking | Record 611 source declarations across six modules; reject removals, signature changes, lost conformances and new cases in existing enums |
| Documentation | Six DocC catalogs and six scenario/compatibility articles; all archives compile with warnings as errors |
| Swift Package Index | Root `.spi.yml` selects all six documentation targets, with GMSetzer first; keep the package manifest free of documentation dependencies |
| Release identity | Use a development identity until reviewed release preparation; reject tags whose runtime identity/final note title does not match; latest published preview remains 0.6.0 |

## Corrections found during preparation

The first composition test assumed front matter was hidden automatically.
The existing contract deliberately renders an escaped fallback. The facade
preserves that contract; the omission example now supplies an explicit hook,
with a separate fallback regression.

The default SwiftPM build backend includes re-exported symbols in the umbrella
graph. Coverage/inventory collection now counts source declarations owned by
each module, excluding re-export duplicates and synthesised declarations.
The resulting 611-declaration inventory matches independently generated native
Linux graphs as well as the Mac graphs.

## Validation boundary

Current Mac and native Linux x64 Swift 6.4.2 Debug/Release runs each pass all
263 library tests (including all 652 CommonMark / 672 GFM examples). Linux's
default build backend reports 13 specification tests and 250 other tests in
separate processes; their sum is 263. All 52 offline Python tests pass on both
hosts. The seven new Swift tests cover default HTML safety, GFM, composed M5
output, unselected implementations, invalid configuration, metadata fallback,
malformed bytes and explicit raw-HTML policy.

Four additional Python regressions cover final release identities, development
identities, draft notes and malformed tags. The current `v1.0.0` preflight is
expected to reject this development snapshot until release preparation is final.

An independent local Release SwiftPM consumer passes using only the umbrella
product. Release library cross-builds pass for arm64 iOS 18 and visionOS 2
with the installed SDKs. The initial consumer build fails at sandbox-restricted
dSYM generation; repeating with debug symbols disabled succeeds. That setup
failure is retained separately and supplies no runtime validation.

At the initial local checkpoint, minimum Swift 6.2 execution remained pending.
The subsequent run at `cbdc977` passes macOS/Linux library/spec/script checks,
optimized builds and all six DocC archives plus the API check; exact evidence
is retained in the [follow-up receipt](../Validation/M8/roadmap-followup-2026-11-23/receipt.json).
Apple minimum-OS runtime checks are not claimed. These changes
do not establish new parser speed, allocation or peak-memory claims. Earlier
M7 receipts keep their exact runtime identities; the new identity/source file
must not be presented as hash-equal to those earlier inventories.

DocC builds establish valid catalogs, references and generated API pages.
The subsequent contract review below documents the consequential public
preconditions/defaults; `coverage.json` still lists declarations without
individual summaries and is not a claim of 100% inline-comment coverage.
Final API/documentation and M7 acceptance remain owner review gates. The release must choose an exact
merged commit, pass minimum-toolchain CI and consumer/archive checks, then
obtain confirmation before tagging, publishing or submitting to the Index.

## 1.0 contract review follow-up

The user requested a roadmap without links to other parser projects and
continued 1.0 work. [Roadmap](Roadmap.md) records independent stages and explicit
acceptance criteria. Its future syntax stages do not expand the 1.0 scope.

The existing public tree surface is sufficient for 1.0: callers can follow
child/sibling links, use `children(of:)`, and build `DocumentIndex` for parents,
ancestors, carets and outlines. A new [DocC tree-query guide](../../Sources/GMSetzer/GMSetzer.docc/TreeQueries.md)
shows preorder traversal and subtree skipping. Visitor/rewriter wrappers can
be additive later; no new public protocol is required before this freeze.

| Public family | Contract reviewed and clarified |
| --- | --- |
| Parser/profile | Configuration construction is tolerant; strict validation is explicit; implementations do not select themselves; profile names are labels |
| Depth limits | Constructor preconditions are 1...256 container / 1...32 inline-extension depth; invalid values are not silently clamped; limits are not byte/time caps |
| Node/document | Payload determines kind; ranges include syntax; source segments identify contributing bytes; flat storage is not preorder; release validation owns tree invariants |
| Tree queries/building | Root is zero; `children(of:)` requires an owned valid index; invalid parent/plain-text queries have documented nil/empty fallbacks; builders expose only validated snapshots |
| Positions | Original-byte versus UTF-16 versus line/scalar coordinates; exact boundaries and nil rejection; no surrogate/CRLF rounding |
| HTML | Default options, raw/comment/URL policy independence, trusted hooks, profile-selected rendering behaviour and escaping scope |
| Extension HTML | Standard recipe ownership, caller-provided title/backlink text, safe footnote ID namespaces, reference ordering and unchanged front-matter/math fallback policies |
| Native findings/fixes | Explicit rule subsets, snapshot-bound suppressions, stable message keys, separate configuration/runtime/analysis errors and exact byte preconditions before edits |
| Progressive output | Complete-document context, soft grouping budget, explicit fallback/cancellation boundaries and caller-owned result lifetime |

This follow-up edits source comments and guides, not Swift declarations or
implementations. The API baseline remains unchanged. The separate library-only
DocC correction and extension-grouping normalisation are recorded in
[their execution report](../Validation/M8/library-docs-2026-11-23.md).

All source-owned public structs, enums and typealiases now have individual
summary comments. Remaining missing-comment entries are inventoried leaf
members/cases; this is not a claim of 100% per-member inline documentation.
The six local DocC archives still compile with warnings as errors, and the
normalised source API still contains all 610 declarations.
