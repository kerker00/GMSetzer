# M7 inline token allocation optimization

22 November 2026, local candidate over `c3758fc`, identity `0.7.0-dev.1`.
Three internal parser files change; public API, input generators, profiles,
dependency pins, specification fixtures and budget limits stay unchanged.
The [candidate receipt/patch](../../BenchmarkData/m7-token-arena-2026-11-22/candidate-source.json)
identifies the measured uncommitted implementation and two regression tests.
There is no clean-candidate-commit timing claim.

## Profile and implementation

Allocation-stack recording on the existing Release executable identifies two
dominant paths for `long-emphasis-v1`, 262,150 bytes, syntax collection on:
**131,076 requests per parse** in the emphasis/array-growth path and
**131,074** in inline token projection/emission. Source inspection attributes
the repeated small arrays to per-item token storage and `InlineInput.ranges`
temporary results. Total recorded requests are **262,219 per parse**.

The candidate uses one append-only token arena per inline controller, reused
across leaves. Each item retains an integer tail index; arena records link to
the previous token. Emission reverses those indices through one reused scratch
buffer, preserving the existing per-item insertion order and tree order.
Nested custom parses rebase token indices and projected offsets when merging.
No scratch handle escapes into the public document; the implementation uses
ordinary Swift value types and no unsafe memory operations.

Token projection now uses the existing inline single-segment mapping rather
than constructing a one-element array. Disjoint segments retain the general
path and emit separate tokens. Zero-length mapping explicitly preserves the
previous boundary affinity, including positions before/after original CRLF
and stripped quote prefixes. Syntax-off allocates no token records. Public
document validation, ranges, ownership and annotation semantics are retained.

Separate allocation profiles record **2 before / 563 after measured
iterations**, with all stack entries exported. Per-iteration totals are:

| Metric | Before | After | Reduction |
| --- | ---: | ---: | ---: |
| Malloc requests | 262,219 | 94 | 99.964% |
| Gross requested bytes | 80,426,262 | about 75,828,594 | 5.72% |

These are allocation traffic, not live heap or peak RSS. The arena retains its
high-water capacity until that controller is destroyed. A large request-count
reduction does not imply an equally large memory reduction; peak memory has
not been measured here. Instrumented times are excluded from timing evidence.

## Independent before/after timing

macOS 27.0.1 / arm64, Apple Swift 6.4.2. Original Release executables/interposers
are copied before rebuilding; hashes identify both sets. The same direct
`BenchmarkTool` runs **12 hardening + 18 historical mixed cases per variant**,
without a SwiftPM/build parent, profiler or local test/build competing during
timing. Cases, tagged byte counts, parser construction/destruction and existing
five-second sampling remain unchanged. Subset commands have bounded process
groups/timeouts; both complete successfully. This is not a full 69/72 refresh.

P50 milliseconds on long emphasis:

| Nominal size | Syntax off before | Syntax off after | Syntax on before | Syntax on after | On-mode reduction |
| --- | ---: | ---: | ---: | ---: | ---: |
| 16 KiB | 0.290 | 0.266 | 1.878 | 0.432 | 77.00% |
| 64 KiB | 1.172 | 1.077 | 7.361 | 1.746 | 76.28% |
| 256 KiB | 4.772 | 4.366 | 29.721 | 7.279 | 75.51% |

The large on-mode case is **4.08× faster**. Its annotation multiplier falls
from **6.23× to 1.67×** in these paired runs; the preceding full baseline had
reported 6.41× under its own conditions. Annotation now costs 1.62–1.67× the
off case across these three sizes. Ordinary unprofiled metrics corroborate
the count reduction (262 K → 94) and rounded gross volume (80 M → 76 M).

The mixed subset contains matching CommonMark/GFM/C and selected registry/
inline cases at 100 KB / 1 MB / 5 MB. All **six current C/absolute checks** and
**nine frozen M2 checks** pass without changing limits. At 5 MB, CommonMark
takes **123.994 ms / 94.437 ms C (1.313×)** and GFM
**145.752 ms / 193.987 ms C (0.751×)**. This Mac observation does not establish
general parity or a cross-host speedup.

Matching C controls vary by up to **4.61%** between the paired runs. Load
averages (1/5/15 min) are 11.00 / 7.89 / 7.12 → 4.04 / 6.47 / 6.69 before,
and 4.46 / 5.16 / 6.03 → 3.60 / 4.54 / 5.63 after. Other owner activity and
thermal/power conditions are not controlled. Small mixed-input changes are
not claimed as general speedups; the focused 75–77% gain is the main result.

The composed all-M5 syntax-on 256 KiB case initially moves
**94.831 → 96.207 ms (+1.45%)**. A separate before/after/after/before repetition
records **95.814 / 94.962 / 94.306 / 96.797 ms**. The small initial slowdown is
not reproduced; neither a broad M5 speedup nor a stable regression is inferred.
Its ordinary allocation display falls from 296 K / 103 M to 262 K / 101 M.
Open-bracket gross traffic remains **174 M** at 256 KiB; this optimization does
not solve that remaining buffer cost.

## Correctness and portability

| Executed check | Result |
| --- | --- |
| Two new regression oracles against the original implementation | 2 tests pass before source changes |
| macOS Debug | 247 tests / 29 suites pass |
| macOS Release | 247 tests / 29 suites pass |
| macOS Release development tools / generated C comparisons | 10 tests / 5 suites pass |
| Python normal / optimized, isolated | 36 tests pass in each mode |
| Native Linux ARM64 Debug | 247 tests / 29 suites pass |
| Native Linux ARM64 Release | 247 tests / 29 suites pass |
| Independent old/new token tables | All 1,324 examples / 4,422 tokens identical |

The new public-behavior regression tests check 1,024 exact deep-emphasis tokens
across leaves, and nested custom results with 13 tokens per owner, zero-length
CRLF positions and disjoint quote-prefix projection. They preserve owner/order,
annotation off/on nodes/output and public document revalidation. They pass
against the old implementation before the optimization, as well as the new one.

An independent development executable parses both pinned specification corpora
with the old and candidate library, serializing each token's role, byte range,
owner and array order. All tables match byte for byte, SHA-256
`faa1802156ce0b35b8f069c6f636f183727d1ee74edcc361b4901839cbb5d3f9`.
The complete library suites also retain all 652 CommonMark / 672 GFM protected
exact-HTML examples and the mutation/progressive checks.

Linux uses the owner's existing native aarch64 / Debian 13.7 / Swift 6.4.2
host, with **78 transferred file hashes matching before/after**. No installation
or replacement execution environment is used. Debug/Release compile-and-test
commands complete in about 97 / 195 seconds; test execution itself takes
7.808 / 2.445 seconds. Existing Swift backtrace-protection and test-executable
linker warnings are retained; both commands exit zero. The existing x64 host
is unreachable, so current-candidate x64 execution remains pending.

During evidence collection, fetched Linux filenames overwrite the original
Mac test logs. Linux logs are moved into their own directory, then both full
Mac suites are rerun with `--skip-build` against the already-built unchanged
candidate binaries. Complete final logs are retained (3.376 / 1.006 seconds);
no timing/profile session overlaps those reruns. Tool/reference logs and all
measurement streams are unaffected by that collection correction.

## Reproduction and remaining work

Use the normal isolated native Swift test commands from
[M7 workloads](../../M7HardeningWorkloads.md#reproduction-and-bounds), with the
root package for library tests. Focused regression selection is:

```sh
swift test --filter 'deepEmphasisTokensKeepExactOwnerOrderAcrossLeaves|nestedTokensKeepOrderAndEmptyCRLFPositionsAcrossLeaves'
```

The [data directory](../../BenchmarkData/m7-token-arena-2026-11-22/) retains
both allocation JSONs, 60 ordinary timing rows, comparisons, the four-case M5
repeat, gate output, exact candidate patch/source hashes and 53 archived
streams/probe files with original/sanitized digests. The archived `measure.py`
records the two exact subset filters, invocation and validation; the archived
`token-probe.swift` records the independent table check. Allocation recording
uses the direct tool with `--export-allocation-stacks`, JSON export and
`--allocation-stack-limit 0`, selecting only long-emphasis syntax-on 256 KiB.

Minimum Swift 6.2, current-candidate x64, Linux development-tool/hardening
timings, full 69/72 refresh, fresh progressive resource hashes/RSS/stage data
and broader isolated fuzz/sanitizer evidence remain pending. Historical 69-case
and M6 resource receipts retain their original identities and are not reused
as current-candidate measurements. Next investigate large item/bracket buffers,
then malformed-byte processing with an explicit validation-enabled C control.
M7 remains in progress; push/PR/publication are separate steps.
