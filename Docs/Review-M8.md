# M8 API and publication preparation review

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

New code has not yet run on the minimum Swift 6.2 CI or Apple minimum OS
runtimes. The updated CI adds DocC and API inventory checks on Swift 6.2;
its definition is prepared locally, not an executed CI result. These changes
do not establish new parser speed, allocation or peak-memory claims. Earlier
M7 receipts keep their exact runtime identities; the new identity/source file
must not be presented as hash-equal to those earlier inventories.

DocC builds establish valid catalogs, references and generated API pages,
not full editorial review of every member. `coverage.json` from the build lists
source declarations without individual comments. Final API/documentation and
M7 acceptance remain owner review gates. The release must choose an exact
merged commit, pass minimum-toolchain CI and consumer/archive checks, then
obtain confirmation before tagging, publishing or submitting to the Index.
