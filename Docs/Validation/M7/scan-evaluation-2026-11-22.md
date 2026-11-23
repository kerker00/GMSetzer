# M7 scan/Span evaluation and documentation follow-up

22 November 2026, `feature/m7-scan-evaluation` over `dd075ee` (PR #26's
reviewed candidate). **No production source, package manifest, fixture,
dependency pin or public API changes.** This records experiments, not an
adopted parser optimization or accepted/released M7. The measured probe is
identified by its uncommitted source hashes and retained harness, rather than
claiming a clean-candidate-commit measurement.

## User documentation

The README shrinks from 318 to 102 lines, leading with one-import GFM usage,
requirements, release links and two current same-run comparison rows. Those
rows explicitly describe the unreleased M7 candidate, actual byte sizes,
CommonMark/no-annotation parse scope, source positions and differing
swift-markdown defaults. Installation still pins the published 0.6.0 preview;
no tag, release or repository visibility is changed.

Chronological checkpoints move to [Status](../../Archive/Status.md); the reference
index and module map move to [Documentation](../../README.md). The exact
first Swift example is extracted from the new README, compiled against the
unchanged Release library modules and executed. Heading and GFM checkbox
assertions pass; source/output/build logs are retained. This is a documentation
smoke check with Swift 6.4.2, not a new full library suite or consumer-device test.

## Experiment contract

The standalone [probe](../../../Tools/ScanProbe/README.md) compiles the actual
current `ByteSearch.swift` baseline alongside six experimental strategies.
Scalar buffer versus scalar Span isolates one access comparison; current word8
versus RawSpan word8 uses the same mask algorithm. SIMD16/32 compare CR/LF in
wider blocks and find the first matching lane, with bounded unaligned loads
and scalar tails. CRLF is combined into one line boundary.

The benchmark covers the parser's **next-boundary traversal only**. It excludes
the first counting/reservation pass, line-table allocation, complete parsing,
Unicode repair, tokens and HTML. This single-module experimental compilation
also does not establish production cross-module code generation or end-to-end
benefit. No result is called a Markdown throughput improvement.

Four authored inputs (80-byte LF lines, dense CRLF, multibyte text and one long
line) at 64 KiB/1 MiB/5 MiB yield **72 rows per host**, each with **12 samples**.
Two complete cyclic rotations balance strategy order. Untimed current-word8
calibration sets a shared iteration count per input. A deterministic mutation
of byte zero before every scan prevents invariant-scan hoisting; per-round
checksums and iteration counts agree across all strategies. Generation,
verification and encoding are outside timing; final fingerprints remain
observable in the exported report. Bounds checks are not disabled.

Before each run, an independent scalar position-list oracle verifies all
strategies on **15,520 views** covering lengths 0–96, offsets 0–31, five input
families, multiple starting positions and exact full-traversal fingerprints.
Nonempty views end at the allocation boundary to exercise short/vector tails.
The final Mac Debug/AddressSanitizer verification passes, without timing rows.

## Native results

Existing native hosts, Swift **6.4.2**, `-O` and whole-module optimization:
Apple M2/macOS 27.0.1/arm64 (explicit macOS 15 compile target), and the existing
CachyOS Linux/x86_64 host. No installation, service change, VM or container.
The runner invokes the executable directly after compilation; no own compiler,
test suite or profiler competes with timing on that host. Other owner activity,
power state and temperature are not controlled.

At **1 MiB**, p50 current-word8 microseconds and candidate time/current time.
Ratios below 1 mean less time in this isolated traversal:

| Host / input | Current µs | RawSpan word8 | SIMD16 | SIMD32 |
| --- | ---: | ---: | ---: | ---: |
| M2 / 80-byte LF | 102.02 | 1.211× | 0.786× | 6.468× |
| M2 / dense CRLF | 526.23 | 1.451× | 1.357× | 13.599× |
| M2 / multibyte | 216.22 | 1.103× | 0.479× | 4.631× |
| M2 / long line | 95.70 | 1.221× | 0.429× | 5.196× |
| x64 / 80-byte LF | 209.92 | 1.703× | 0.732× | 5.164× |
| x64 / dense CRLF | 2,570.97 | 0.984× | 0.558× | 2.818× |
| x64 / multibyte | 311.28 | 1.325× | 0.621× | 4.423× |
| x64 / long line | 186.79 | 1.799× | 0.450× | 4.525× |

All sizes, scalar variants, samples and checksums remain in the exports;
this table is not a selection that discards failing cases. SIMD16 is promising
for longer lines but regresses **35.7%** on dense M2 CRLF. The tested SIMD32
implementation is substantially slower; a wider Swift vector type alone is
not an optimization. Its precise lowering bottleneck is not diagnosed here.

The RawSpan word8 variant is generally slower in this experiment, despite
retaining the algorithm; one near-equal x64 dense case is not a broad win.
Scalar Span versus scalar buffer is also mixed. This does not establish that
Span is generally slow: the exact loop, bounds-check elimination, compiler and
access pattern matter. There is no basis for a blanket replacement today.

Complete probe execution, including verification, takes **17.682 s on M2**
and **11.989 s on x64**. M2 load averages are **2.84/2.56/2.66 →
3.22/2.65/2.69**; x64 **0.08/0.02/0.03 → 0.22/0.05/0.04**. These are recorded
conditions, not controlled repeated hardware trials or a C comparison.

## Source identity, evidence and decision

Both Release runs and the final Mac ASan check verify unchanged executable,
four probe/baseline/driver hashes and the complete **43-file runtime/manifest
inventory**. The latter matches PR #26's production source. It identifies the
unchanged library; this standalone probe does not rebuild or rerun its full
252-test suite or the historical 69/72 targets. Their earlier evidence retains
its source identity. Compiling with language mode 6/macOS 15 using Swift 6.4.2
does not prove Swift 6.2 compiler compatibility or minimum-OS execution for
these new experiments; those checks precede any production adoption.

The [data directory](../../BenchmarkData/m7-scan-evaluation-2026-11-22/) retains
all final raw samples, derived summaries, source/command/binary receipts,
ASan/example logs and exact final harness. The initial five-strategy pilot
(60 rows per host, ten samples) led to adding the matched RawSpan algorithm;
its logs and exact harness are retained as preparation, not substituted for
the final 72-row comparison. No failed timing is hidden or budget relaxed.
Task paths are replaced in logs/receipts; original-to-retained and dataset
digests are recorded. No executable/runtime binaries are committed.

**Decision:** retain the current production scanner. A future SIMD16 adoption
needs a solution for dense-input regressions and paired full-parser measurements
under unchanged semantic/resource gates. Further work follows measured
intermediate-copy and HTML-output costs; token layout changes remain
profile-driven. The owner-approved M8 facade/shared parser-renderer configuration
and separately designed input streaming remain planned, not implemented here.
