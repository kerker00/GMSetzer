# Progressive HTML output

> Historical record, archived during 1.0 documentation consolidation. Status,
> counts and plans below describe their original checkpoint. Current contracts
> and workflow are in the [package guide](../README.md) and
> [development handbook](../Development.md).

M6 is merged in PR #24 (`a8a0351`) and [accepted](M6Acceptance.md),
21 November 2026.
The accepted M6 snapshot used `0.6.0-dev.1` and is published separately as
[v0.6.0](https://github.com/kerker00/GMSetzer/releases/tag/v0.6.0). This M7
branch uses `0.7.0-dev.1`, which is not a published version. This API consumes
an already parsed, complete `Document` and returns structural HTML on demand.
It does not stream or incrementally parse Markdown.

## Prepare and consume

```swift
import GMSetzer

let document = MarkdownParser(profile: .gfm).parse(source)
let renderer = HTMLRenderer(includeSourceRanges: true)
let plan = try renderer.prepare(document, maximumSourceBytesPerGroup: 32_768)

try plan.forEachGroup { group, html in
    print(html, terminator: "")
    return true // false stops before the next group is rendered
}
```

The complete document and the renderer options belong to the plan. Preparation
groups top-level blocks and creates a shared `DocumentIndex` only when
contextual hooks need it. It does not render body blocks or call hooks.
Known non-rendering reference definitions are omitted from structural groups;
a custom reference-definition hook still receives them.

`maximumSourceBytesPerGroup` is a positive, soft source-byte budget. A complete
table, list, quote, code block or custom container is never cut in half. A block
larger than the budget remains one group; HTML escaping and source attributes
can make output much larger than its source. This is not a strict HTML-byte,
time or memory limit. Empty documents have no groups unless a document-level
fallback/hook requires output. A caller hook can produce an empty group.

Each `HTMLRenderGroup` supplies its ordinal, body/appendix kind, source range
and top-level node indices. These are snapshot-local values, not stable IDs
across edits. A body group's range spans its nodes, possibly including source
gaps. An appendix uses the whole document's range and has no body node indices.

`renderGroup(at:)` materialises only the requested group. Structural groups can
be requested in any order, including concurrently, and placed back in ordinal
order by a consumer. `forEachGroup` is synchronous and pull-based: it has no
producer queue, and does not retain previously delivered HTML. Its return value
counts groups handed to the consumer, including the final group returning false.
The plan itself retains the full syntax document and its small grouping/index
metadata. It does not promise constant total memory or evict source/tree data.

## Stopping and cancellation

```swift
let html = try plan.renderGroup(at: ordinal, checkpoint: {
    try Task.checkCancellation()
})
```

Checkpoints run before/after group output and between renderer events. Throwing
aborts the current render without delivering an incomplete group; the plan is
still reusable. A literal conversion, a caller hook, or a hook recursively
rendering its children is indivisible until it returns. Synchronous parsing and
preparation have already happened and are not cancelled by this callback.
Invalid nonpositive budgets and invalid ordinals throw `HTMLRenderPlanError`.

Consumers own revision/configuration checks, latest-work scheduling, cache
lifetime, backpressure across asynchronous boundaries and UI insertion. No app
session type, Foundation, JavaScript or UI dependency is added to the library.

## Explicit fallbacks and hooks

`plan.mode` distinguishes `.structural` from `.wholeDocument(reason)`:

| Reason | Why the whole output remains one group |
| --- | --- |
| `.rawHTML` | Raw source HTML can open a wrapper in one block and close it in another. Any renderer allowing raw HTML conservatively uses this fallback, including `.conformance`. |
| `.documentHook` | A root replacement/wrapper can change the structure of all children. |
| `.documentOrderHooks` | Caller hooks have not promised independent execution. |

The precedence is raw HTML, document hook, then document-order hooks. Fallback
preparation remains lazy, but its only output group materialises the complete
result. Such a plan does not shorten first-output latency through grouping.

Custom hooks default to `HTMLHookBehavior.documentOrder`. Only opt into
`.independent` when every hook is deterministic, thread-safe, has no dependence
on invocation order and returns markup contained inside its block. The promise
is the caller's responsibility; `Sendable` alone does not establish it.
Repeated requests to a fallback plan re-run its whole renderer and may repeat
caller effects, just as repeated full `render` calls do. The caller should
consume such a result once rather than treating it as independent tiles.

The existing escaping, URL policies, original node-based anchors and trusted
caller-hook boundary apply unchanged. Preparing groups is not an HTML sanitizer.
The existing `render(_:) -> String` API remains available.

## Footnotes and other extensions

`FootnotesHTMLRenderer.prepare` numbers all references over the complete
document, including forward, repeated and cyclic calls, and shares the
prepared renderer/index with every group. Top-level definitions are suppressed
in the body and cited notes become one lazy appendix group at the end. The
appendix can be requested first without changing numbering/backlinks, but must
be placed last. A whole-document fallback includes that appendix in its single
group. The appendix may itself be large and is intentionally indivisible.

`AdmonitionHTML.renderer` certifies its own built-in hooks as independent.
Combining it with footnotes preserves title rendering, nesting, source anchors
and complete-document context. A caller hook requiring document order keeps
the combined renderer in fallback mode. Math hooks and front-matter omission
remain caller policies; pure custom hooks must explicitly opt into independence.

## Validation and declared limits

`ProgressiveHTMLTests` covers deferred hook evaluation, early stopping,
out-of-order/concurrent requests, cancellation, source ranges, giant blocks,
Unicode/BOM/CRLF/invalid bytes, safe output, fallbacks and combined M5 rendering.
`SpecTests.progressiveOutputPreservesBothCompleteCorpora` compares grouped and
full output for all 652 CommonMark and 672 GFM inputs in safe and conformance
modes. Existing specification baselines and fixtures are unchanged.

The complete macOS/Swift 6.4.2 Debug and Release suites each pass 239 tests;
the same 239 tests and an optimised build pass on Linux ARM64/Swift 6.4.2.
Both hosts pass all 17 offline script tests. The [validation record](../Validation/M6/initial-html-groups.md)
details commands, source identity and limits. The bounded 1 MB Release
stage probe and its raw results are in [Benchmarks](Benchmarks.md#m6-progressive-html-first-stage-probe).
The [42-case Linux ARM64 follow-up](../Validation/M6/linux-arm64-measurements.md)
adds 100 KB/1 MB/5 MB workloads with syntax details off/on, fresh-process peak
RSS and separate allocation counts/volume. It confirms earlier output for
independent blocks, unchanged giant-block limits and no general peak-RSS gain.
The subsequent [review follow-up](../Validation/M6/review-readiness.md) defines
post-baseline budgets, verifies all 42 cases against raw records and matching
runtime source inventory/hashes, and passes all 242 tests plus an optimized
build on macOS/Swift 6.2. The [self-review](Review-M6.md) adds cancellation and
deferred-appendix coverage, corrects measurement provenance and validates
31 Python tests in normal and optimised modes. All 14 progressive tests also
pass in Swift 6.2 Release.
These are candidate budgets for owner review, not pre-registered goals or a
fresh measurement series. [PR #24 CI](https://github.com/kerker00/GMSetzer/actions/runs/44926163013)
now passes all 242 Swift tests, optimized builds and 31 Python tests on macOS
and Linux with Swift 6.2. The owner merged PR #24 at `a8a0351`; [M6 acceptance](M6Acceptance.md)
maps all declared gates to evidence, including merged-main CI. General
hardening continues in M7; consumer UI integration stays separate.


The subsequent [M7 inline-buffer optimization](../Validation/M7/inline-scratch-2026-11-21.md)
passes the current progressive correctness tests as part of the 245-test
macOS/x64 Debug/Release suites. It changes runtime source hashes, so the
historical 42-case M6 stage/RSS/allocation receipt above is not current-source
resource evidence for that candidate; the strict source-identity check rejects
reuse as expected. Fresh resource measurements remain pending. The merged M6
acceptance record continues to describe its measured source snapshot.


The later [M7 current-source report](../Validation/M7/final-x64-2026-11-22.md)
closes that earlier hash gap for the merged M7 parser, with all 42 cases / 126
checks and the complete runtime/tool inventory passing. The subsequent
[HTML-copy candidate](../Validation/M7/html-copies-2026-11-22.md) changes the renderer
again and passes a fresh 42-case / 126-check matrix for its own 43 runtime / 5
measurement-tool hashes; raw records and budget results are retained there.
Scratch storage is local to the requested render call, with no eager full-
document output reservation. Parsing still precedes output; no input-streaming
or general peak-memory reduction is introduced.
