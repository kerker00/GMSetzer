# M1 technical acceptance — 20 November 2026

> Historical record, archived during 1.0 documentation consolidation. Status,
> counts and plans below describe their original checkpoint. Current contracts
> and workflow are in the [package guide](../README.md) and
> [development handbook](../Development.md).

Decision: **M1 technical acceptance passed; owner merge pending.** Correctness,
architecture probes, portability checks and measured budgets pass. This record is not a merge or
an M2 implementation; the owner merges the cumulative M1 PR into `main`.

## Review disposition

| M1 review item | Resolution and boundary |
| --- | --- |
| BOM, wrapper tightness, custom-leaf projection | M1-A, merged PR #4; combination regressions retained |
| Comparable C baseline, checked construction, local gate | M1-B, merged PR #5; source positions and matching corpora retained |
| Main-loop decomposition before registry work | Named phase helpers, carried into this cumulative PR; PR #8 was merged into the former portability branch after PR #7 reached main |
| Shared configuration and rule dispatch | Immutable resolved phase registry, core/custom identities, enable/disable/precedence, schema/namespace checks; no configuration findings in document text |
| Extension unit | Portable descriptor in SetzerSyntax; parser callbacks and renderer hooks stay in their modules |
| Container/transform proof | Small footnote child-projection and alert post-block probes; malformed results rejected, source snapshot retained |
| Inline contract before M2 | Internal executable draft for protected regions, progress, bounded ranges, flanking and owned opener handles; actual inline/controller integration is M2 |
| Optional syntax storage | Generic optional token table; reference convenience view; no per-reference syntax payload in NodeData |
| Parent ownership and hook context | Optional snapshot-owned parent table and contextual hooks; fast offset queries remain M3 |
| Custom fallback lifecycle | Sparse semantic text stays separate from source-only tokens; finish preserves omission, explicit clear tested |
| String/segment costs and inline budget | Reconstruction probes and a frozen total-parse allowance; final values below |
| Builder try! audit | Three deliberately retained fail-fast invariant checks, with local comments and rationale; full release validation retained, no silent recovery |
| Hostile input | Existing arbitrary-byte, prefix-heavy, long-run and depth cases; new bounded recursive extension and malformed child/token/diagnostic cases |
| Portability | Full Swift 6.2 macOS suite; full Linux x86-64 suite on Swift 6.4.2 through the existing SSH host; Swift 6.2 static Linux ARM64 cross-build |
| Setzkit documentation | Separate documentation change; app integration, UTF-16 underlines and native lint remain M3 |

The implemented APIs, draft/production distinction, trust boundary and pre-1.0
migration are in [ExtensionContracts.md](ExtensionContracts.md).

## Correctness and portability evidence

- **70 library test functions**: 65 parser/tree tests and five spec-harness
  tests, including parameterized cases. All pass on macOS Swift 6.4.2 debug
  and release, macOS Swift 6.2 and Linux x86-64 Swift 6.4.2.
- Exact protected HTML remains **339/652 CommonMark** and **339/672 pinned
  GFM**, without removing or exchanging IDs. Remaining conformance is M2/M4.
- All **four Tools test functions** pass: three reference tests totaling
  **3,919 cmark comparisons** and the three-size annotation/registry corpus
  check. The no-op selected registry preserves the same tree.
- All **13 offline Python tests** pass, including five tests for the M2 gate:
  independent size failures, malformed/missing inputs, total ceilings, unstable
  C controls and a changed frozen-baseline hash.
- All five library modules cross-build for static Linux ARM64 with Swift 6.2.
  No new VM/container, tool installation or service change was used. Only
  sources/manifest/test fixtures were transferred to a task-specific directory
  on the existing SSH host; that directory was removed after capturing results.

Swift 6.2 uses its matching Testing runtime and the compatible macOS 14.4 SDK
with package deployment target macOS 15, as described in
[Portability.md](Portability.md). Linux execution uses x86-64/glibc 2.44 and
Swift 6.4.2. The minimum compiler and Linux are exercised separately; this does
**not** claim a full Linux Swift 6.2 suite or minimum Apple-OS runtime tests.
Those additional matrix combinations remain follow-up coverage, alongside the
M3 app/device checks. No newer platform-only Span API was introduced.

The test/benchmark summaries, hashes and exact measured source revisions are
in the [acceptance evidence](../Validation/M1Acceptance/receipt.json). Scratch and
compiler/package caches were redirected to writable task paths; release tests
used `-debug-info-format none`. Library tests need no downloaded dependencies.

## Performance decision and M2 gate

The full **42-case** countermeasurement at `e7668b8` passes all six block
budgets and the frozen M1-B 10% regression alert. Full-run core times are
2.654 / 27.410 / 138.019 ms; its C controls are 1.903 / 21.299 / 103.743 ms.
The initial 36-case run at `231ae50` exposed per-token role-string construction.
`8a301e2` replaces those concatenations with static role strings: the focused
1 MB annotation count falls from about **318 K to 227 K allocations** (rounded
harness output). Raw initial and full results are retained, not overwritten.

Because the full run's 1 MB C control drifted more than 10% from the initial
run, a separate **15-case focused repeat** checks core, annotation and selected
registry cases. C controls are within 10% of both previous runs at each size.
Freeze this complete repeat as [m2-baseline.md](../Validation/M1Acceptance/m2-baseline.md),
without mixing cases from different runs:

| CommonMark mixed-v1 | 100 KB | 1 MB | 5 MB |
| --- | ---: | ---: | ---: |
| GMSetzer block parse, ms | 2.468 | 24.592 | 122.683 |
| C with source positions, ms | 1.758 | 19.939 | 95.945 |
| Ratio | 1.404× | 1.233× | 1.279× |
| Total measured headroom, ms | 1.048 | 15.286 | 69.207 |
| Fixed M2 additional parse allowance, ms | 0.5 | 8 | 40 |
| Reserve after allowance, ms | 0.548 | 7.286 | 29.207 |

The repeat's reference annotation timings at 1 MB are **25.919 ms off /
32.506 ms on** (+25.4%). The selected no-op registry takes **26.345 ms** versus
24.592 ms core (+7.1%); at 5 MB the measured delta is +12.2%. This overhead is
real and must count against the budget when such rules are selected. These
are current paths, not complete-inline/GFM or arbitrary-plugin cost estimates.

In the full 42-case run, the separate 1 MB reconstruction probes measure
**1.665 ms / 16 K allocations / 1,956 K bytes** for text and
**4.542 ms / 51 K allocations / 3,241 K bytes** for segments. The optional
parent index measures **0.289 ms / one allocation / 1,226 K bytes**. Those
microbenchmarks run independently; their sums do not establish parser savings.
The cross-run timing variation precludes attributing an exact speed improvement
to the storage/dispatch changes. Allocation differences are recorded separately.

The fixed M2 allowance is **0.5 / 8 / 40 ms** at 100 KB / 1 MB / 5 MB on the
unchanged `mixed-v1` CommonMark corpus with annotations off. It limits the delta
of the **whole parse** over the frozen M1 result, including any new allocation,
annotation-off bookkeeping or validation work; it is not a sum of isolated
phase medians and is not a claim that M2 already meets it. Remaining reserve
must stay positive in M1's preflight.

Use the frozen receipt and executable check when M2 parsing is available:

```sh
python3 -I Scripts/check_m2_budget.py path/to/m2-benchmark.md \
  --baseline Docs/Validation/M1Acceptance/m2-baseline.md \
  --allowance Docs/Validation/M1Acceptance/inline-budget.json
```

The check verifies the frozen baseline hash, all three size/corpus identities,
each independent delta allowance, the current absolute/2×C total ceiling, and
C-control drift within 10%. Exit 0 means pass, 1 means a budget failure, and 2
means malformed/missing inputs. Use the same host/toolchain/configuration and
repeat a noisy measurement before interpreting a failure. Do not replace the
frozen baseline to make M2 pass. If the budget fails, optimize before advancing.
The earlier 10% M1-B alert remains appropriate for block-only counterchecks;
it is not the permitted size of M2's new inline work.

String and segment reconstruction probes force materialization and record time,
allocation count and bytes. Their medians cannot be subtracted from total parse
time as causal savings. Retain strings/segment arrays for now: there is a
bounded M2 allowance, while a lazy/pool migration still needs its own controlled
experiment and projection invariants. The parent index is optional; its cost
is measured separately. A selected no-op extension measures dispatch overhead,
not the cost of arbitrary caller callbacks or transforms.

The GFM timings remain **informational only** until M4: C parses tables and
autolinks that GMSetzer has not implemented. Neither those ratios nor this
block-only CommonMark run prove completed inline/GFM performance. Full syntax
annotation overhead must be measured again after M2 emits inline roles.

## Next delivery boundary

After technical acceptance and the owner's merge, M2 implements core inlines,
reference decoding/resolution and source roles through the controlled inline
boundary. M3 delivers offset/UTF-16 queries, outline and native analysis with a
real Setzkit underline proof. M4/M5 deliver the full GFM/additional extensions.
These milestones and editor/device checks are not marked complete by M1.
