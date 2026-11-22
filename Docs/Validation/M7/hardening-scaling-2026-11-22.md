# M7 extension and hostile-input scaling baseline

22 November 2026, owner-authorised full execution of `HardeningBenchmarks`.
All **69/69 cases complete**, exit 0, at clean commit
`2f5f1bdf627182c408a0e7ba224514461edb13a5` (`0.7.0-dev.1`). This records a
measurement baseline, not a parser change or M7 acceptance.

## Execution and identity

macOS 27.0.1 / arm64, eight logical CPUs, Apple Swift 6.4.2
(`swiftlang-6.4.2.1.9 clang-2100.4.1.1`), pinned package-benchmark/cmark.
The existing Release tool/benchmark and malloc interposers have exactly the
same hashes as the [preparation checkpoint](hardening-preparation-2026-11-22.md).
All **50 measurement-source/manifest/lockfile hashes**, including the **43
library-source/root-manifest files**, match before/after. The 69 tagged names
match preparation exactly. No source, input, pin, profile or budget is changed.

The built tool runs directly, without a SwiftPM/build parent, compiler,
test suite or profiler launched alongside the timings. Each case uses a private
process group, maximum five-second sampling and a 30-second whole-command
timeout. No timeout, process failure or invalid export occurs. Each result
passes the tagged identity and three-metric checks; per-case sample counts
range from **43 to 10,000**. Fast cases can reach the iteration limit before
five seconds. Times below are p50, not worst-case latency.

```sh
python3 -I Tools/run_hardening_benchmarks.py \
  --tool /private/tmp/gmsetzer-m7-benchmark-build/arm64-apple-macosx/release/BenchmarkTool \
  --binary /private/tmp/gmsetzer-m7-benchmark-build/arm64-apple-macosx/release/HardeningBenchmarks \
  --output /private/tmp/gmsetzer-m7-hardening-full-2026-11-22 --run-all
```

The series runs **07:43:51–07:49:17 UTC**, **326 seconds (5 min 26 s)**.
One/five/fifteen-minute load averages change from **13.13 / 8.66 / 8.54** to
**3.65 / 7.28 / 8.25**. Other host activity and thermal/power conditions are
not controlled or attributed; this is one sequential observational series.
Close ratios and small differences do not establish speedups or general parity.

## Observed size-to-time growth

Swift parse-only, syntax collection off. Actual input sizes are recorded in
the raw names/CSV; complete units can exceed 16/64/256 KiB. Endpoint growth is
the 256 KiB case divided by the 16 KiB case, using actual byte counts.

| Corpus | 16 KiB ms | 64 KiB ms | 256 KiB ms | Input growth | Time growth |
| --- | ---: | ---: | ---: | ---: | ---: |
| All M5 composed | 3.394 | 14.041 | 54.886 | 15.74× | 16.17× |
| Repeated shared footnote | 2.931 | 11.502 | 48.202 | 15.99× | 16.45× |
| Unclosed brackets | 1.066 | 4.334 | 17.727 | 16.00× | 16.63× |
| Long emphasis | 0.290 | 1.195 | 4.801 | 15.99× | 16.56× |
| Unmatched backticks | 0.107 | 0.262 | 0.719 | 15.93× | 6.72× |
| Quote-budget overflow | 0.451 | 1.777 | 7.176 | 15.84× | 15.91× |
| Invalid UTF-8/NUL/CRLF | 0.786 | 3.113 | 12.534 | 16.00× | 15.95× |

All 18 Swift series, including annotation and rendering variants, show
**6.70–17.21× time growth for 15.74–16.00× input growth**. No strongly
superlinear timing pattern is observed at these three sizes. This is not an
O(n) proof, a hang-free guarantee for other inputs, or evidence beyond 256 KiB.
The unmatched-backtick generator increases run width with size: the number of
distinct runs grows more slowly than byte count. Its sublinear observed ratio
must not be generalized to arbitrary backtick documents.

Full composed rendering includes parser construction, parsing, safe HTML,
global footnote context/backlinks and escaped placeholder math, with no TeX
engine. It remains approximately proportional in this series:

| Parse + render | 16 KiB ms | 64 KiB ms | 256 KiB ms | Time growth |
| --- | ---: | ---: | ---: | ---: |
| All M5, syntax off | 5.042 | 19.104 | 78.512 | 15.57× |
| All M5, syntax on | 7.528 | 29.442 | 116.326 | 15.45× |
| Shared footnote, syntax off | 5.022 | 20.021 | 83.821 | 16.69× |
| Shared footnote, syntax on | 5.853 | 24.166 | 98.107 | 16.76× |

## Costs worth profiling next

**Syntax tokens on deeply nested emphasis.** At 262,150 bytes, annotation
off/on takes **4.801 / 30.769 ms (6.41×)**. Malloc requests rise from **56**
to the displayed **262 K**, and gross requested bytes from **38 M to 80 M**.
The time multiplier is 6.12–6.49× across the three sizes; growth remains
approximately proportional, but the optional service has a large constant
cost for this shape. As a source-inspection hypothesis, the per-item token
arrays in `InlineParser.Item` and the subsequent token emission are candidates
for allocation profiling. This run does not provide allocation stacks or prove
which call site causes the measured cost. Preserve exact tokens/ownership,
annotation invariance and public validation while investigating.

**Large buffers for unclosed brackets.** At 262,144 bytes, Swift records
**76 requests / 174 M gross bytes**, compared with C's **524 K / 59 M**.
Few requests can still request substantial storage: request count alone is not
a memory-efficiency measure. Swift takes 17.727 ms versus C's 21.217 ms here,
so elapsed time alone also misses this cost. Investigate item/bracket storage
layout and buffer growth with allocation stacks. The displayed 174 M is about
664 requested bytes per input byte, summed over the parse; it is **not 174 MB
of simultaneously live memory or peak RSS**.

**Malformed-byte decoding and tree work.** At 262,148 bytes, Swift/C take
**12.534 / 3.768 ms (3.33×)**, with about **42 M / 9,249 K** requested bytes.
The time ratio stays 3.33–3.39× across sizes. The C control enables source
positions but does **not** set `CMARK_OPT_VALIDATE_UTF8`; the pinned
`swift-cmark/src/blocks.c` only runs its UTF-8 validation under that flag.
GMSetzer preserves original bytes and performs replacement decoding into a
validated Swift tree. Profile the Swift path, and add a separately identified
validation-enabled C control before drawing equivalent-work conclusions.
Do not silently change the recorded corpus/control or relax an existing gate.

Allocation units use the pinned tool's decimal K=1,000 / M=1,000,000, with
rounded displays. Derived byte/count values and their ratios are approximate.
M5 gross-byte endpoint growth is about 15.39–18.49×; the shared-note cases
increase somewhat more than input bytes. Long-emphasis annotation volume grows
about 18.98×. These results support further buffer/allocation investigation;
they do not establish proportional retained/peak-memory growth.

## Informational C controls

Syntax off, identical original buffers, source positions on for both parsers.
No C rendering/all-M5 equivalence exists in this target.

| Corpus, nominal 256 KiB | Swift ms | C ms | Swift/C |
| --- | ---: | ---: | ---: |
| Unclosed brackets | 17.727 | 21.217 | 0.836× |
| Long emphasis | 4.801 | 4.825 | 0.995× |
| Unmatched backticks | 0.719 | 0.425 | 1.692× |
| Quote overflow | 7.176 | 17.564 | 0.409× |
| Invalid UTF-8 | 12.534 | 3.768 | 3.326× |

Quote policies differ: Swift explicitly limits block containers to 128 while
inputs contain 256 quote prefixes per unit. Malformed-byte validation differs
as noted above. These ratios neither prove general C parity nor constitute
new ≤2× budget failures/passes. Existing mixed-corpus C/absolute/frozen-M2
limits remain unchanged and were not rerun. Historical normal-input CommonMark
is still 24–54% slower than C on x64 after the earlier optimization.

## Evidence and remaining gates

The [data directory](../../BenchmarkData/m7-hardening-full-2026-11-22/)
contains the receipt, all 69 rows, 23 scaling groups, 27 annotation pairs,
15 C comparisons and **142 archived streams/metadata files**. Original and
sanitized hashes are mapped explicitly. A standalone derivation script
regenerates all tables from archived results, with identical output hashes.

No correctness suite is rerun for this measurement-only step; the unchanged
harness's 10 Release tool tests / 5 suites and 36 Python tests in each mode
remain at the preparation checkpoint. New-harness Linux/minimum Swift 6.2,
candidate Linux ARM64, fresh progressive RSS/stage/allocation checks, a full
historical 72-case refresh and broader fuzz/sanitizer evidence remain pending.
Next profile the demonstrated token/buffer/byte-processing costs, retain the
existing correctness and performance gates, and measure any candidate on
matching workloads. No runtime optimization, push, merge or release is part
of this checkpoint; M7 remains in progress.
