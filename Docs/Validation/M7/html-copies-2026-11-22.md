# M7 HTML intermediate-copy optimization

22 November 2026, candidate over `0d660f9`, development identity `0.7.0-dev.1`.
One runtime file changes: `Sources/SetzerHTML/HTMLRenderer.swift`, plus one
regression test. Public APIs, parser grammar/tree/token/source contracts,
limits, dependency pins and performance budgets remain unchanged. Source
hashes and the candidate patch identify the uncommitted implementation measured
here; this is not a clean-candidate-commit or published-release measurement.

## Profile and implementation

The current 1 MB mixed-v1 pre-parsed HTML render allocation profile records
**202,620 requests / 14,759,504 gross requested bytes per iteration**. Of those,
82,125 requests / 4,181,075 bytes have escaping in their stack, and 58,414 /
3,283,352 have child collection. These are measured allocation traffic, not
live heap or peak RSS. The final String accumulator is not the only cost.

The candidate addresses those intermediate buffers:

- `escape` returns the existing immutable String value when no `&`, `<`, `>`
  or double quote needs replacement. The existing byte writer handles strings
  that do require escaping, retaining exact UTF-8 spelling and the public API.
- Each renderer call reuses a local child-index scratch array through the
  existing package-only document traversal helper. Events retain indices,
  not the scratch array. Separate/reentrant calls and progressive groups own
  separate scratch storage; renderer instances acquire no mutable state.
- Stable in-place reference-definition filtering replaces a second array;
  reverse iteration over indices replaces temporary enumerated/reversed arrays.
  Scheduling order, list tightness, GFM strong/table behavior, hook precedence,
  trust boundaries and checkpoint locations remain unchanged.

This retains the String output accumulator and introduces no unsafe access,
unchecked compilation, eager whole-document capacity hint or input streaming.
A full byte-writer rewrite is not needed to remove these profiled copies.

Separate stack exports use two before/eight after instrumented iterations:

| Metric per 1 MB render | Before | After | Reduction |
| --- | ---: | ---: | ---: |
| Allocation requests | 202,620 | 42,020 | **79.26%** |
| Gross requested bytes | 14,759,504 | 6,767,829 | **54.15%** |

The output String and URL generation remain visible costs. Instrumented
timings are excluded; lower allocation traffic does not establish peak-RSS
reduction or an equally large full-pipeline speedup.

## Unprofiled paired timing

Apple M2/macOS 27.0.1 and native Linux x64, Swift 6.4.2, Release `-O`/WMO.
Direct built BenchmarkTool invocation avoids a SwiftPM parent. Each variant
has 10 historical render/reconstruction/parser/C-control cases and eight
256 KiB M5 parse/parse-render cases, with unchanged input/profile/annotation
selections and five-second sampling. All sources/binaries remain unchanged
within successful runs. No own build, test or profiler competes during timing.

P50 milliseconds for **rendering an already parsed mixed-v1 document**:

| Host / nominal input | Before | After | Time reduction |
| --- | ---: | ---: | ---: |
| M2 / 100 KB | 2.822 | 1.334 | 52.73% |
| M2 / 1 MB | 28.230 | 14.377 | 49.07% |
| M2 / 5 MB | 143.917 | 74.187 | 48.45% |
| x64 / 100 KB | 3.344 | 2.114 | 36.78% |
| x64 / 1 MB | 34.800 | 22.823 | 34.42% |
| x64 / 5 MB | 175.899 | 114.688 | 34.80% |

The first M2 pair has control drift: unchanged CommonMark/GFM parse times rise
13.88%/9.81%, with C +2.93%/+10.42%; M5 pipeline rows also rise 3–5% while
their unchanged parse controls rise 10–20%. This prompted one retained,
focused 13-case repeat per variant, rather than a broad speed claim.

In that repeat, M2 1 MB rendering is **28.115 → 13.558 ms (−51.78%)**;
CommonMark/GFM parser drift is +0.68%/+1.25%, C −2.19%/−1.40%. Frozen-before
receipts explicitly distinguish the current workspace hashes from the measured
old binary/source identity. Both series and all control rows remain retained.
Native x64 controls are stable (parser −1.47%/+0.63%, C +1.14%/+2.15%).

M5 parse-plus-render includes substantial unrelated parsing/indexing work:
native rows range **−4.93% to +2.54%**, and M2 repeat rows **−4.23% to +1.59%**.
Do not generalize the isolated renderer result to composed M5 pipelines or
attribute phase costs by subtracting separate benchmark medians. These are
sequential pairs, not randomized repeated hardware trials; owner activity,
temperature and power state remain uncontrolled. This is not a new C-parity
claim or a full historical 72-case refresh.

## Correctness and remaining validation

| Executed check | Result |
| --- | --- |
| New byte-fidelity oracle before the runtime change | Pass |
| Mac Debug / Release | 253 tests / 29 suites pass per mode |
| Native Linux x64 Debug / Release | 253 tests / 29 suites pass per mode |
| Release development tools / C references | 12 tests / 6 suites pass per host |
| Mac Debug AddressSanitizer | 253 tests / 29 suites pass |
| Mac AddressSanitizer bounded mutation probe | 1,024 inputs / 8,192 parses pass, 56.05 s |
| Native progressive resources, source-matched | 42 cases / 126 checks pass |

The oracle compares exact UTF-8 with an independent replacement-based reference
for plain/special runs around small-string/long-buffer sizes, decomposed
Unicode, emoji, Japanese, NUL/apostrophes and every ASCII byte. It passes on
the original implementation first. Protected 652 CommonMark / 672 GFM HTML
examples, source/token invariants, hooks, cancellation and progressive/M5
contracts remain covered by the complete suites. The default Mac build system
runs its two test products separately (13 + 240 tests); native/Release/ASan
runs report a combined 253. No suite is silently omitted.

An initial default-build-system benchmark preparation fails during debug-symbol
generation. Explicit native build mode and no debug info rebuild/list all
needed executables successfully. Failed setup logs remain separate; measured
binaries are verified against source/old receipts, not assumed from a successful
unrelated test build. No package pin or toolchain is changed.

The bounded probe uses four profiles with/without syntax details, preserves
source/tree/diagnostic invariants, and compares full HTML with out-of-order
progressive groups. It has a 180-second process bound and 4,096-byte input
bound; it is deterministic mutation under ASan, not coverage-guided fuzzing.

The fresh **42-case native progressive resource matrix** passes all **126**
unchanged first-output, completion and peak-RSS checks. Eight timing samples,
three fresh RSS processes per mode and separate allocation processes retain
their existing scope. The checker verifies all **43 runtime / 5 measurement
tool hashes**, archive digests and 756 raw records on both hosts. No old
runtime hash is presented as a match for the changed renderer. This establishes
the existing resource budgets, not general peak-memory reduction.

Candidate minimum Swift 6.2 CI is pending; the branch is not merged or released.
The
[evidence directory](../../BenchmarkData/m7-html-copies-2026-11-22/) retains
raw paired/repeat exports, exact allocation stacks, tests, source/binary hashes
and the candidate patch. Logs replace task/home paths; archived digests record
original-to-retained transformations. No build binaries are committed.
