# M6 progressive HTML acceptance

> Historical record, archived during 1.0 documentation consolidation. Status,
> counts and plans below describe their original checkpoint. Current contracts
> and workflow are in the [package guide](../README.md) and
> [development handbook](../Development.md).

21 November 2026. [PR #24](https://github.com/kerker00/GMSetzer/pull/24)
is merged at `a8a0351b0ab6aa09b8167e371148ae2895e78f0a`. M6 is accepted
against Plan 10.1's declared library contract, based on the evidence below and
the owner's merge of the reviewed API, documented limits and post-baseline
budgets. Development identity remains `0.6.0-dev.1`; no 0.6 release is implied.

| Gate | Evidence |
| --- | --- |
| Semantic equivalence | Every protected CommonMark/GFM input is compared with full output in safe and conformance modes. All 652 CommonMark and 672 GFM examples pass. Conformance explicitly uses the documented raw-HTML fallback. |
| Global context | Focused tests retain forward links, cyclic/repeated footnotes, one deferred appendix and composed front matter/math/alerts/callouts, including title hooks. |
| Order and identity | Snapshot-local descriptors, reverse-order and concurrent requests retain exact output/anchors/numbering. Document-order hooks and root hooks use explicit fallbacks. |
| Structure and positions | Top-level groups preserve whole lists, tables, fences and custom wrappers, original source ranges, BOM/CRLF/multibyte/invalid-byte provenance. Giant blocks remain indivisible. |
| Safe output | Full/grouped paths share the existing escaping, URL/comment policy and caller-hook trust boundary; raw HTML conservatively falls back to a complete document. |
| Resource behavior | Deferred hooks, stopping after a group, interruption after output construction begins, actual task cancellation and lazy appendix hooks have focused regression tests. Emission has no producer queue. Parsing/preparation and individual hooks/literals remain synchronous as documented. |
| Measurements | The archived 42-case 100 KB/1 MB/5 MB workload/annotation matrix records parse/preparation/first/full times, fresh-process peak RSS and gross allocation requests. All cases meet the reviewed post-baseline latency/completion/RSS budgets. All 43 runtime/manifest hashes and the complete file inventory match the merged source. |
| Portability and scope | PR and merged-main CI pass on macOS/Swift 6.2.3 and Ubuntu/Swift 6.2: 242 Swift tests, optimized builds and 31 Python tests per host. Local Swift 6.4.2/6.2 checks, including 14 progressive Release tests, are recorded separately. The runtime remains Foundation-free and has no external dependencies. |

Merged-main evidence: [CI run 44927786679](https://github.com/kerker00/GMSetzer/actions/runs/44927786679).
The [self-review](Review-M6.md) and [review-readiness record](../Validation/M6/review-readiness.md)
retain the findings, corrections, commands, toolchain configuration and exact
measurement limits. Historical records remain unchanged as historical evidence.

This accepts progressive output under its declared scope. It does not establish
general peak-memory reduction, faster parsing, independent execution of arbitrary
hooks, bounded single-block HTML size, UI/device latency or broad fuzzing.
General speed/hostile-input/allocation hardening is M7. Stable API/DocC/1.0
work remains M8. Publication still follows the separate release process.
