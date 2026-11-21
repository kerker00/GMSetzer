# Progressive HTML stage and Linux resource probe

This development-only package depends on the local GMSetzer checkout. Neither
Foundation nor the optional Linux allocation interposer enters library targets.
It compares the full and prepared renderers of **the same library revision**;
it is not the package-benchmark/C performance gate.

## Build and run

From the GMSetzer root, with Swift 6.2 or newer:

```sh
swift build --build-system native --package-path Tools/ProgressiveHTMLProbe -c release
Tools/ProgressiveHTMLProbe/.build/release/ProgressiveHTMLProbe 1000000 8 mixed syntax-off timing
```

Arguments are size (1–5,000,000 bytes), iterations (1–9), workload, syntax
collection and mode. Inputs round up to complete units; JSON records actual
UTF-8 byte counts. Workloads are `mixed`, `prose`, `small-blocks`, `tables`,
`long-code`, `multibyte` and `extensions`. Prose selects CommonMark; the others
select GFM. The extension case explicitly selects all five M5 extensions,
hides front matter, escapes raw math into a span, composes admonitions and
emits named footnotes. This is no math typesetter or consumer application.
Source ranges and `block-` node anchors are enabled in every renderer.

`timing` does one excluded warmup and alternates full-first/group-first order
on each parsed document. The matrix uses eight samples (four of each order).
`parse`, `full`, `first` and `groups` execute only the named pipeline without
warmup; `verify` compares complete HTML strings byte for byte. Group mode
holds the first group and releases each later group after counting its bytes;
it never assembles full HTML. The soft source budget is 32,768 bytes.

The JSON schema is `progressive-<workload>-v2`; the earlier archived macOS
`progressive-mixed-v1` files retain their original probe/schema and ordering.
Times for preparation, first output and remaining groups are separate timed
operations. Reported combined times are **paired sums** of those intervals;
harness dictionary/descriptor-summary bookkeeping between intervals is excluded.
They do not include transferring output or displaying it in a WebView. Parsing
is still required before any group. Inspect raw samples and separate order
subsets before interpreting small timing differences.

## Linux RSS and allocation matrix

No install, root privileges, container, host configuration or extra Python
package is required. Use a task-specific output path that does not exist.
Compile the optional allocator only on the measured glibc host:

```sh
cc -O2 -shared -fPIC -ftls-model=initial-exec -Wall -Wextra Tools/ProgressiveHTMLProbe/Support/allocator.c -o libgm-alloc.so
cc -O0 -fno-builtin -Wall -Wextra Tools/ProgressiveHTMLProbe/Support/allocator-check.c -ldl -pthread -o allocator-check
LD_PRELOAD="$PWD/libgm-alloc.so" ./allocator-check
python3 Tools/ProgressiveHTMLProbe/run-linux-matrix.py \
  --binary Tools/ProgressiveHTMLProbe/.build/release/ProgressiveHTMLProbe \
  --allocator libgm-alloc.so --output /tmp/gmsetzer-m6-results
```

Add `--smoke` for only 100 KB mixed/syntax-off. The complete sequential matrix
has seven workloads × three sizes × syntax details off/on = **42 cases**.
Each case runs exact HTML verification, an uninstrumented eight-sample timing
process, three fresh uninstrumented processes per `parse`/`full`/`first`/`groups`
RSS mode and one fresh instrumented process per mode. The runner preserves raw
JSON, writes summaries incrementally and records source/executable hashes and
host state. The revision label is fixed to this initial M6 measurement (087e694);
verify source hashes against that revision before using this receipt for another
checkout. All processes are sequential; affinity/governor settings are read,
not changed. A failed case stops the run with previous data preserved.

RSS is Linux `/proc/self/status` **VmHWM in KiB for the whole process**. It
includes runtime, generated source, parsing and that process's requested
pipeline. It is not an isolated renderer peak, retained memory or a sum of
stages. The three fresh-process samples expose run-to-run page variation.
Do not subtract independent high-water values to infer exact phase memory.

Allocation instrumentation uses `LD_PRELOAD` and glibc `__libc_*` entry points.
It counts successful `malloc`, `calloc`, `realloc`, `memalign`, `aligned_alloc`,
`posix_memalign`, `valloc` and `pvalloc` requests on the synchronous calling
thread, between stage counter boundaries. A realloc counts its full new
requested size; deallocations are not subtracted. Numbers describe **gross
requested bytes and allocation calls**, not live bytes, usable-size overhead,
background threads or every direct mmap/runtime allocation. The calibration
checks six requests totalling 511 bytes, reset and disabled counters. Swift
stage counts also include tiny clock/closure boundary costs. This glibc probe
is intentionally separate from the library and is not a portable profiler.
Instrumented timings and instrumented RSS are not used for comparisons.

A single long code block stays indivisible. A footnote appendix is one group
and may exceed the soft source/HTML size budget. Record these limits alongside
the timing gains of inputs with many independent blocks. This matrix supplies
M6 evidence; minimum-compiler checks, application UI measurements and the
broader M7 hardening/comparison benchmark are separate work.

## Offline M6 review budgets

After collecting the complete matrix, run the offline checker from the repo
root against the archived evidence directory:

```sh
python3 -I Scripts/check_progressive_html_budget.py \
  Docs/BenchmarkData/m6-progressive-html/linux-arm64-2026-11-21 \
  --source-root .
```

This reads the archived matrix without executing the probe. It verifies all
42 cases, artifacts/source hashes, raw verification/timing/RSS records and
per-case post-baseline budgets. Source matching is required before applying
historical results to a current checkout. The candidate budgets and limitations
are in [review readiness](../../Docs/Validation/M6/review-readiness.md). A
passed check is not owner acceptance, a new run or application UI evidence.
