# M7 inline buffer and emission capacity optimization

22 November 2026, local candidate over `3fdc646`, identity `0.7.0-dev.1`.
Three runtime files and two tests in one existing test file change. Public API,
grammar, parser limits, node granularity, fixtures, dependency pins, workloads
and budget limits remain unchanged. The
[candidate receipt/patch](../../BenchmarkData/m7-inline-capacity-2026-11-22/candidate-source.json)
identifies the uncommitted source measured here; no clean-candidate-commit
timing claim is made.

## Allocation profile and implementation

The existing Release open-bracket case at **262,144 original bytes**, syntax
off, records **174,190,788 gross requested bytes / 76 requests per parse**.
Two growth paths dominate: about **92.35 M bytes** in the inline controller
and **80.45 M** in document-builder append growth. These are allocation traffic,
not simultaneously live memory or peak RSS.

The implementation addresses both paths:

- Internal item links retain optional accessors but store nonnegative arena
  indices with a private `-1` nil sentinel. No public index representation or
  validation is changed. Keeping the three optional views preserves the
  controller's existing linking/rebasing algorithm.
- Bracket fields are reordered so the three Boolean fields share the final
  storage region after the two integer fields.
- After parsing an inline leaf, the builder reserves for its known item-count
  upper bound before emission. The hint can include provisional items later
  unlinked, so it is conservative. A capacity check and geometric growth across
  both builder arrays prevent repeated exact-size copying for many small leaves.

Measured `MemoryLayout.stride` in the compiled macOS arm64 modules:

| Type | Before bytes | After bytes |
| --- | ---: | ---: |
| Internal inline item | 144 | 120 |
| Internal bracket entry | 32 | 24 |
| Public tree node | 128 | 128 |

These are observations for this compiler/target, not an ABI guarantee. The
candidate uses standard Swift values and arrays without unsafe memory work,
new source-size caps, skipped parsing or output coalescing.

Separate full allocation-stack exports record 299 before / 302 after measured
iterations. Totals per iteration:

| Metric, open brackets 256 KiB | Before | After | Reduction |
| --- | ---: | ---: | ---: |
| Gross requested bytes | 174,190,788 | 119,819,700 | **31.21%** |
| Malloc requests | 76 | 51 | **32.89%** |

The candidate's one emission reservation requests about **37.75 M bytes**
instead of the previous **80.45 M** append-growth path. Remaining inline-array
growth is about **80.79 M**. Ordinary timing exports corroborate rounded
174 M → 120 M displays. Reduced requested traffic and smaller private slots
do not establish a particular retained/peak-memory reduction; conservative
capacity hints can retain unused slots. Instrumented timings are excluded.

## Unprofiled paired timing and unchanged gates

macOS 27.0.1 / arm64, Apple Swift 6.4.2. Original Release executables and malloc
interposers are copied before rebuilding and identified by hashes. Each
variant runs a direct **30-case subset**: 12 hardening cases and 18 historical
mixed cases, preserving inputs, sampling and construction/destruction work.
No SwiftPM/build parent, local test suite, compiler or profiler competes during
timing. Native Linux correctness builds execute on a separate existing host.

P50 milliseconds; bracket inputs are exactly the tagged nominal sizes:

| Nominal size | Brackets off before | Off after | Brackets on before | On after |
| --- | ---: | ---: | ---: | ---: |
| 16 KiB | 0.949 | 0.951 | 1.117 | 1.074 |
| 64 KiB | 4.207 | 3.893 | 4.481 | 4.407 |
| 256 KiB | 16.269 | 15.843 | 17.809 | 17.875 |

Bracket timing is broadly maintained; the large syntax-on change is +0.37%,
so this is a storage/traffic optimization rather than a demonstrated broad
bracket speedup. Long-emphasis syntax-on improves **6.94–10.66%** across the
three sizes, with 256 KiB **7.643 → 6.828 ms**. Composed all-M5 syntax-on moves
6.087 → 5.935 / 23.527 → 23.183 / 95.224 → 91.030 ms at the three sizes.
Small changes are observations, not generalized speedup claims.

All **six C/absolute gates** and **nine frozen M2 checks** pass unchanged.
At mixed 5 MB, CommonMark/C is **124.781 / 93.061 ms (1.341×)** and GFM/C is
**144.966 / 193.069 ms (0.751×)**. Matching C controls vary by up to **3.57%**;
there is no claim of general C parity or cross-host speedup. The 1 MB
CommonMark row improves much more than the 5 MB row, so its isolated percentage
is not used as a general parser improvement.

Load averages (1/5/15 min) are **3.13 / 4.06 / 4.73 → 4.41 / 4.46 / 4.79**
before, and **2.82 / 3.74 / 4.33 → 3.18 / 3.39 / 4.07** after. Other owner
activity, temperature and power state are not controlled. These are sequential
paired subsets, not randomized repeated trials or a full 69/72-case refresh.

## Correctness and independent public-tree check

| Executed check | Result |
| --- | --- |
| New regression oracles against original code | 2 tests pass before runtime changes |
| macOS Debug / Release | 249 tests / 29 suites pass in each mode |
| macOS Release development tools / C comparisons | 10 tests / 5 suites pass |
| Native Linux ARM64 Debug / Release | 249 tests / 29 suites pass in each mode |
| Independent public node/token snapshots | All 1,324 examples identical |

One new test checks bracket leaves around 1,024/4,096 boundaries, individual
literal nodes, exact source segments and intervening resolved links. Another
checks 512 small paragraphs with four links/strong spans each, retaining
12,289 nodes and 16,384 tokens. Both preserve exact HTML, annotation invariance
and tree structure; the bracket test revalidates the public document. Ordinary
tests contain no timing/capacity threshold.

A separate development executable parses both pinned corpora with the old and
candidate library under the same compiler. It serializes public node payload
representations (`String(reflecting:)`), ranges, ordered source segments,
child/sibling links, and exact token roles/ranges/owners/order. All **7,994
nodes / 4,422 tokens** across **1,324 examples** match byte for byte, SHA-256
`9f26ebb925dd832f82d85fdae89388a8ce4107e9793ac8f208c03c7a577866b6`.
This probe is an internal comparison, not a new public serialization format.
The full suites retain all 652 CommonMark / 672 GFM protected HTML examples
and the existing mutation, M5 and progressive-output checks.

Linux uses the already-authorised native aarch64 / Debian 13.7 / Swift 6.4.2
host, with all **78 transferred hashes matching before/after**. No installation
or replacement environment is used. Debug/Release compile-and-test commands
complete in about **81 / 197 seconds**; test execution takes **6.988 / 1.975 s**.
Existing nonfatal backtrace-protection/linker warnings remain in the retained
logs. Current Linux x64/minimum Swift 6.2 remain pending. Python source is
unchanged; its prior 36 tests per mode are not repeated for this runtime-only
step. The four current budget commands do validate the fresh measurement rows.

## Evidence and next work

The [data directory](../../BenchmarkData/m7-inline-capacity-2026-11-22/) retains
both profiles, all 60 ordinary rows, comparisons, gate output, layout probe,
public-tree probe/tables, exact candidate patch/source hashes and **45 archived
files** with original-to-sanitized digests. All 51 measurement-source hashes
are unchanged during each successful subset; baseline sources match `3fdc646`.

Minimum compiler/current x64, Linux development-tool timings, full 69/72-case
refresh, fresh progressive resource hashes/stage/RSS data and broader fuzz/
sanitizer checks remain open. Historical measurements retain their source
identities and are not reused as current resource evidence. Next investigate
malformed UTF-8 processing with a separately identified validation-enabled C
control before equivalent-work conclusions. M7 remains in progress; this step
does not push, open a PR or publish a release.
