# M6 progressive HTML: Linux ARM64 measurements

21 November 2026. Owner-authorised follow-up measurements of the initial M6
library at `087e694` (`feature/m6-progressive-html`, `0.6.0-dev.1`). Library
sources, package manifest, parser, tests and protected fixtures are unchanged
from that commit. Only the development probe and documentation are extended.
This compares the full and grouped renderer of the **same version**, not Linux
against the earlier macOS timings or against a C reference.

## Environment and commands

Existing owner-provided Raspberry Pi 5 Model B Rev 1.0, Linux aarch64,
Debian 13.7, glibc 2.41, four logical CPUs and approximately 8 GiB RAM.
Swift 6.4.2 (`swift-6.4.2-RELEASE`), GCC 14.2.0. Optimised native SwiftPM build,
with two build jobs; measurement processes execute sequentially. The CPU uses
its existing `ondemand` governor; affinity, clock settings, services and system
packages are not changed. No VM or container is created.

```sh
export PATH="$HOME/.local/opt/swift-6.4.2/usr/bin:$PATH"
swift build --build-system native --package-path Tools/ProgressiveHTMLProbe -c release --jobs 2
cc -O2 -shared -fPIC -ftls-model=initial-exec -Wall -Wextra Tools/ProgressiveHTMLProbe/Support/allocator.c -o libgm-alloc.so
cc -O0 -fno-builtin -Wall -Wextra Tools/ProgressiveHTMLProbe/Support/allocator-check.c -ldl -pthread -o allocator-check
LD_PRELOAD="$PWD/libgm-alloc.so" ./allocator-check
python3 Tools/ProgressiveHTMLProbe/run-linux-matrix.py \
  --binary Tools/ProgressiveHTMLProbe/.build/release/ProgressiveHTMLProbe \
  --allocator libgm-alloc.so --output /tmp/gmsetzer-m6-results
```

The allocator calibration passes: six allocation requests, 511 requested bytes,
reset and disabled-counter behavior. A separate 100 KB smoke case passes before
the recorded full matrix. Both are excluded from its timing samples. The
runtime reports unavailable swift-backtrace protection; the release linker
reports an RWX LOAD segment. The build and measurement commands succeed; these
observations do not validate crash-backtrace or executable hardening behavior.

## Measurement scope

Seven deterministic workloads × 100 KB/1 MB/5 MB × syntax details off/on =
42 cases. Inputs round up to complete units; actual byte counts are recorded.
Prose selects CommonMark, all other workloads select GFM. The extension workload
selects front matter, footnotes, math, alerts and callouts together. It hides
front matter, emits escaped opaque math spans and uses the built-in admonition/
footnote composition; it does not run a TeX engine. This is one representative
M5 combination, not an exhaustive extension/callback matrix.

Source ranges and `block-` node anchors are enabled throughout. Grouping uses
the default 32,768-source-byte soft budget. All cases verify assembled and full
HTML byte for byte in a separate process before measurement. Timing uses one
excluded warmup and eight uninstrumented samples, alternating four full-first
and four groups-first iterations on each parsed document. Table values are
medians; combined stages are paired sums of measured intervals. Harness
bookkeeping between intervals is excluded. Raw samples retain ordering.

RSS uses three fresh **uninstrumented** processes per parse/full/first/groups
pipeline and reports whole-process VmHWM in KiB. It includes generated source,
runtime and parsing; it is not an isolated renderer peak or retained memory.
Group consumption keeps the first HTML group and releases each later group,
without assembling the output. The allocation pass is separate and has one
fresh process per pipeline. Its stage counters report successful allocation
requests and gross requested bytes on the synchronous calling thread, including
the full requested size of realloc, without subtracting frees. It excludes
background-thread allocations and direct mappings. Instrumented timings/RSS
are not used. See the [probe instructions](../../../Tools/ProgressiveHTMLProbe/README.md)
for the exact boundaries and limitations.

## Results

All **42 cases pass exact HTML equality**, with 756 verification/timing/resource subprocesses. The sequential matrix took **13.9 minutes**, excluding compilation and the smoke case. The source hashes of all 48 measured source/tool files match the local checkout.

### Stage timings, syntax details off

All times are milliseconds. `First` includes complete-document preparation and the first group, **after parsing**. `All groups` includes preparation and consumption without HTML assembly.

| Workload | Nominal size | Parse | Full HTML | Prepare + first | All groups | Groups |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| Mixed GFM | 100 KB | 11.55 | 13.42 | 4.63 | 13.36 | 4 |
| Mixed GFM | 1 MB | 116.70 | 137.08 | 9.07 | 131.79 | 31 |
| Mixed GFM | 5 MB | 562.75 | 673.74 | 27.85 | 658.84 | 153 |
| Prose (CommonMark) | 100 KB | 4.28 | 4.24 | 1.42 | 4.29 | 4 |
| Prose (CommonMark) | 1 MB | 50.47 | 45.64 | 2.36 | 44.53 | 31 |
| Prose (CommonMark) | 5 MB | 231.21 | 227.45 | 6.17 | 222.42 | 153 |
| Many small blocks | 100 KB | 25.66 | 40.43 | 14.94 | 41.57 | 4 |
| Many small blocks | 1 MB | 225.10 | 388.22 | 35.74 | 403.25 | 31 |
| Many small blocks | 5 MB | 1114.40 | 1957.99 | 124.91 | 2018.50 | 153 |
| GFM tables | 100 KB | 14.77 | 19.82 | 6.47 | 19.44 | 4 |
| GFM tables | 1 MB | 132.37 | 194.40 | 7.64 | 190.74 | 31 |
| GFM tables | 5 MB | 686.64 | 982.56 | 14.60 | 950.87 | 153 |
| One long code block | 100 KB | 0.41 | 1.19 | 1.20 | 1.20 | 1 |
| One long code block | 1 MB | 4.35 | 12.85 | 12.89 | 12.89 | 1 |
| One long code block | 5 MB | 22.27 | 64.22 | 64.34 | 64.34 | 1 |
| Multibyte text | 100 KB | 5.22 | 5.04 | 1.73 | 5.10 | 4 |
| Multibyte text | 1 MB | 62.17 | 53.52 | 3.50 | 52.57 | 31 |
| Multibyte text | 5 MB | 304.18 | 269.85 | 10.85 | 263.41 | 153 |
| All five M5 extensions | 100 KB | 43.64 | 19.53 | 8.34 | 19.19 | 5 |
| All five M5 extensions | 1 MB | 506.27 | 210.74 | 67.19 | 207.04 | 32 |
| All five M5 extensions | 5 MB | 2585.24 | 1093.97 | 355.65 | 1062.06 | 154 |

### End-to-end availability, mixed GFM

Paired medians include parsing, not application transfer/layout.

| Nominal size | Parse + prepare + first | Parse + full HTML |
| --- | ---: | ---: |
| 100 KB | 16.14 ms | 24.90 ms |
| 1 MB | 125.79 ms | 253.63 ms |
| 5 MB | 590.13 ms | 1229.37 ms |

### 5 MB whole-process peak RSS, syntax details off

Medians of three fresh processes, in MiB. Differences of a few pages are not evidence of a meaningful memory change.

| Workload | Parse only | Full HTML | First group | All groups |
| --- | ---: | ---: | ---: | ---: |
| Mixed GFM | 254.84 | 254.81 | 254.81 | 254.80 |
| Prose (CommonMark) | 103.59 | 103.58 | 103.59 | 103.58 |
| Many small blocks | 811.16 | 811.16 | 811.16 | 811.17 |
| GFM tables | 322.78 | 322.83 | 322.80 | 322.80 |
| One long code block | 43.61 | 56.20 | 56.69 | 56.73 |
| Multibyte text | 157.73 | 157.78 | 157.73 | 157.73 |
| All five M5 extensions | 328.94 | 328.95 | 328.50 | 328.94 |

### 5 MB gross render/preparation allocations, syntax details off

One separate instrumented run per mode. Parsing is excluded here; the CSV/raw records retain its counts as well. Group values sum preparation + first + remaining groups. Gross MiB is requested allocation volume, **not** retained memory or RSS.

| Workload | Full calls | Grouped calls | Full gross MiB | Grouped gross MiB |
| --- | ---: | ---: | ---: | ---: |
| Mixed GFM | 3,200,091 | 3,203,738 | 313.52 | 301.59 |
| Prose (CommonMark) | 936,942 | 940,107 | 75.42 | 87.50 |
| Many small blocks | 9,860,508 | 9,864,909 | 1124.89 | 1091.84 |
| GFM tables | 4,960,810 | 4,964,457 | 519.79 | 485.70 |
| One long code block | 19 | 24 | 33.23 | 33.23 |
| Multibyte text | 1,109,796 | 1,113,113 | 92.09 | 105.81 |
| All five M5 extensions | 3,722,375 | 3,725,567 | 380.86 | 334.91 |

### Syntax-detail cost at 1 MB

All cases also measure annotations on. These are descriptive paired-configuration medians, not additive parser attribution.

| Workload | Parse off | Parse on | Full RSS off/on, MiB |
| --- | ---: | ---: | ---: |
| Mixed GFM | 116.70 ms | 141.34 ms | 64.64 / 76.61 |
| Prose (CommonMark) | 50.47 ms | 63.66 ms | 34.69 / 37.08 |
| Many small blocks | 225.10 ms | 238.63 ms | 175.48 / 188.14 |
| GFM tables | 132.37 ms | 176.33 ms | 78.80 / 100.05 |
| One long code block | 4.35 ms | 4.36 ms | 25.95 / 25.95 |
| Multibyte text | 62.17 ms | 72.75 ms | 45.23 / 47.41 |
| All five M5 extensions | 506.27 ms | 947.60 ms | 81.81 / 114.28 |

### Observations

- Many independent blocks provide earlier output. Grouping does not remove the complete parse or the top-level/context preparation pass. Full completion remains similar in this sample; both small overheads and apparent savings occur, without a controlled regression verdict.
- A single fenced code block has one group, so first output requires its complete rendering and has no early-output benefit. Its grouped peak RSS is slightly higher in this run.
- In the mixed and small-block cases, parse-only high-water memory already reaches approximately the full/groups peaks. No general peak-memory reduction is established. The 5 MB small-block workload expands to 102,808,670 HTML bytes with ranges/anchors; it is deliberately demanding, not a prediction for every 5 MB document.
- The M5 composition pays for global context before first output, and emits one indivisible footnote appendix. Descriptor source span for that appendix covers the document, so the CSV's largest source-span value is not an appendix HTML-size budget. Annotation-enabled M5 parsing is a separate substantial cost.
- The fixed 32 KiB source budget is neither an HTML-byte nor a process-memory cap. Per-stage timings, first HTML bytes, node/group counts and annotation-on values remain available for every case.

Raw evidence: [receipt and source hashes](../../BenchmarkData/m6-progressive-html/linux-arm64-2026-11-21/receipt.json), [complete summary JSON](../../BenchmarkData/m6-progressive-html/linux-arm64-2026-11-21/summary.json), [42-case CSV](../../BenchmarkData/m6-progressive-html/linux-arm64-2026-11-21/summary.csv), [all raw process records](../../BenchmarkData/m6-progressive-html/linux-arm64-2026-11-21/raw-results.tar.gz), [artifact SHA-256](../../BenchmarkData/m6-progressive-html/linux-arm64-2026-11-21/sha256.json).

Host state: 48.5 °C before / 53.5 °C after; reported CPU frequency 2400 / 2400 MHz. These snapshots are not continuous thermal/scheduling monitoring.


## Interpretation and remaining gates

Full parsing still precedes preparation and output. The first-group figures
must not be presented as first-visible-output latency. Transfer, HTML insertion,
layout, scrolling and device behavior are outside these measurements.

General M7 parser/C comparison gates and their frozen limits are unchanged.
These same-host stage probes are not a package-benchmark run, a statistically
controlled regression verdict or acceptance of arbitrary custom hooks. The
minimum supported Swift 6.2 compiler and quantitative M6 acceptance targets
remain to be checked/agreed before completing M6. The existing 239-test macOS/
Linux and 17-script-test results are retained in the [initial validation](initial-html-groups.md);
this measurement-only change does not claim a fresh run of those suites.
There is no API, parser, consumer repository, push, PR, tag or release change.
