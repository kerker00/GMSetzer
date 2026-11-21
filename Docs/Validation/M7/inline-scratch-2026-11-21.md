# M7 first measured parser optimization: reusable inline scratch buffers

21 November 2026. Base commit `9e7bc71e9f069f4b1ed282bead75fdcb85a8b2f8`;
the measured candidate changes only `InlinePhase.swift` and `Document.swift`.
The [source manifest](../../BenchmarkData/m7-inline-scratch-2026-11-21/candidate-source.json)
records the exact 121-file transfer, candidate hashes and patch hash;
the [patch](../../BenchmarkData/m7-inline-scratch-2026-11-21/change.patch.gz)
reproduces those runtime changes against the base. It is gzip-compressed;
`patch_sha256` hashes the uncompressed unified diff. No benchmark source, input,
dependency, protected fixture, limit or public signature changes.

## Profile and implementation

Two three-second `/usr/bin/sample` captures at one-millisecond intervals cover
CommonMark `mixed-v1` parses at 1 MB and 5 MB on the existing Apple M2/macOS
27.0.1/Swift 6.4.2 Release executable. The worker stacks identify inline-phase
child traversal as a prominent path. Separate allocation-stack recording on
the same 1,000,100-byte input attributes **43,814 allocation requests per parse**
to `Document.children(of:)` called from the inline phase; another prominent
array-allocation path is the per-leaf inline emission stack.

The candidate keeps one child-index buffer and one emission-event buffer
local to each `parseInlines` call. A package-only overload fills the child
buffer after clearing its contents while retaining capacity. The public
`children(of:) -> [Int]` method still returns a separate array with the same
ordering and index precondition. The emission loop drains its reusable stack
before the next leaf. Neither buffer escapes into a document or projected
inline input; there is no shared mutable cache. Tree construction, full
document validation, source positions, tokens, extension dispatch and parsing
selections remain enabled.

Allocation recording observes **109,538 → 56,618 requests per 1 MB parse**
(**48.31% fewer**), normalized over three before / six after iterations.
Gross requested bytes are 58,549,158 → 56,067,470. Ordinary unprofiled rows
corroborate the rounded request counts, 110 K → 57 K. This is allocation churn,
not retained heap or peak RSS; retaining scratch capacity can extend the
lifetime of its high-water allocation within one parse.

## Unprofiled before/after measurements

Four separate **18-case subsets**, one before and after on each host, cover
CommonMark, GFM, matching C controls and selected no-op block/inline registries
at 100 KB / 1 MB / 5 MB. These are not four complete 72-case target runs.
Each uses the same existing five-second sampling configuration and the built
Release BenchmarkTool directly, with no SwiftPM parent or profiler during
measurement. Old executables are copied and hashed before rebuilding; no
profiled timing is used as performance evidence.

Hosts: Apple M2, eight logical CPUs/16 GiB, macOS 27.0.1, Apple Swift 6.4.2;
Intel i5-6600K, four logical CPUs/32 GiB, CachyOS Linux 7.3.4-1-cachyos/glibc
2.44, Swift 6.4.2. Existing toolchains, governors and host settings are retained.
Native Release optimization and no benchmark debug information match before/
after. All 121 transferred candidate file hashes match after x64 execution.

P50 milliseconds; all rows use identical source-positioned `mixed-v1` inputs
(100,284 / 1,000,100 / 5,000,500 UTF-8 bytes):

| Host | Profile | Size | Before | After | Time reduction | After C | After GM/C |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: |
| M2 | CommonMark | 100 KB | 2.738 | 2.265 | 17.28% | 1.650 | 1.373× |
| M2 | CommonMark | 1 MB | 27.886 | 23.593 | 15.39% | 18.596 | 1.269× |
| M2 | CommonMark | 5 MB | 147.325 | 124.649 | 15.39% | 92.668 | 1.345× |
| M2 | GFM | 100 KB | 3.256 | 2.703 | 16.98% | 2.939 | 0.920× |
| M2 | GFM | 1 MB | 33.915 | 27.525 | 18.84% | 36.766 | 0.749× |
| M2 | GFM | 5 MB | 174.457 | 145.752 | 16.45% | 191.627 | 0.761× |
| x64 | CommonMark | 100 KB | 3.971 | 3.688 | 7.13% | 2.454 | 1.503× |
| x64 | CommonMark | 1 MB | 44.761 | 42.172 | 5.78% | 33.948 | 1.242× |
| x64 | CommonMark | 5 MB | 231.604 | 215.745 | 6.85% | 140.247 | 1.538× |
| x64 | GFM | 100 KB | 4.858 | 4.461 | 8.17% | 4.534 | 0.984× |
| x64 | GFM | 1 MB | 55.411 | 50.758 | 8.40% | 56.001 | 0.906× |
| x64 | GFM | 5 MB | 283.116 | 263.848 | 6.81% | 271.843 | 0.971× |

Selected no-op registry/inline cases also improve: **14.22–16.62% on M2** and
**5.26–8.65% on x64** across their six cases per host. These dispatch probes
do not measure real M5 processing. Matching C controls change by at most
**2.07% on M2 / 1.36% on x64** between the fresh before/after runs. The Mac's
six stricter C/absolute gates and nine frozen M2 core/selected-variant gates
pass with unchanged limits; frozen C drift remains within ±10%. All six x64
same-host ≤2× C comparisons pass; Mac absolute/frozen gates are not applied
to x64. The exact gate outputs are retained with the data.

These are observed same-host before/after results on this corpus, not a
cross-architecture attribution or a guarantee for arbitrary Markdown.
CommonMark remains about **24–54% slower than C on x64**; parity is not yet
achieved. After profiles still show document construction/validation, trigger
scanning and root child traversal as useful next investigation points, without
establishing exact isolated phase costs. GFM is below its matching C median
in all six current Mac/x64 cases.

## Correctness, review and remaining evidence

| Current candidate | macOS arm64 | Linux x64 |
| --- | --- | --- |
| Library Debug | 245 tests / 29 suites pass | 245 tests / 29 suites pass |
| Library Release | 245 tests / 29 suites pass | 245 tests / 29 suites pass |
| Development tools Release | 6 tests / 4 suites pass | 6 tests / 4 suites pass |

The library checks retain all 652 CommonMark / 672 GFM protected examples,
annotation equality, exact grouped/full HTML and the bounded mutation/depth
campaign. Tool tests include generated C-reference comparisons and annotated/
registry corpus checks through 5 MB. Review confirms buffer ownership is local,
old contents are cleared/drained and no validation or syntax work is skipped.

The first copied x64 Clang module cache fails compilation because its PCM
files embed the old absolute cache path. The transferred cache directories
are renamed out of the active cache paths and regenerated in place. Tests
then execute successfully; the initial compile failure and final phase results
remain in the archive. No toolchain installation or host change is used.

Candidate minimum Swift 6.2 and Linux ARM64 suites were not repeated in this
step. Nor were the full 72-case suite, broader hostile/M5 scaling or isolated
fuzz/sanitizers. The historical M6 42-case resource matrix is tied to older
runtime hashes: the unchanged strict source-identity checker now rejects it
for this candidate as expected. It remains valid history, not fresh resource
evidence; current progressive-output stage/RSS/allocation measurements need a
new series before claiming those resource budgets for this runtime. Existing
progressive correctness tests pass. M7 remains open.

## Evidence and reproduction

[All 72 subset rows](../../BenchmarkData/m7-inline-scratch-2026-11-21/summary.csv),
[36 paired comparisons](../../BenchmarkData/m7-inline-scratch-2026-11-21/comparison.json),
[matching C comparisons](../../BenchmarkData/m7-inline-scratch-2026-11-21/c-comparison.json),
[allocation stacks before](../../BenchmarkData/m7-inline-scratch-2026-11-21/allocation-before.json)
and [after](../../BenchmarkData/m7-inline-scratch-2026-11-21/allocation-after.json),
[allocation summary](../../BenchmarkData/m7-inline-scratch-2026-11-21/allocation-summary.json),
[test receipt](../../BenchmarkData/m7-inline-scratch-2026-11-21/validation.json),
[complete sanitized streams/profiles](../../BenchmarkData/m7-inline-scratch-2026-11-21/raw-output.tar.gz),
[original/retained stream hashes](../../BenchmarkData/m7-inline-scratch-2026-11-21/stream-hashes.json)
and [artifact hashes](../../BenchmarkData/m7-inline-scratch-2026-11-21/sha256.json).
Each readable export and receipt is in the same data directory. Sanitization
redacts task/user-home paths, host labels and process addresses and uses LF;
all numerical metric rows, stack counts and allocation JSON values are retained.

Use the [direct invocation](linux-x64-2026-11-21.md#reproduction-and-retained-evidence)
with this exact filter, and the native scratch/cache/build options already
documented there. Keep stdout/stderr separate and record source/binary hashes:

```text
(GMSetzer (CommonMark parse|GFM parse|selected registry parse|selected inline parse)|cmark-gfm \(C\) (CommonMark|GFM) parse) (100 KB|1 MB|5 MB).*
```

CPU captures launch the Release runner filtered to `GMSetzer CommonMark parse
1 MB.*` or the corresponding 5 MB case, then attach `sample <pid> 3 1 -file <output>` after 1.2 s.
Allocation recording is separate: add `--export-allocation-stacks
--allocation-stacks-export-format json --allocation-stacks-export-path <path>`
to the direct tool and select only the 1 MB CommonMark case. Instrumented and
uninstrumented runs must not overlap; none of these captures does. Benchmark
and long-test authorization rules in `CLAUDE.md` remain unchanged.
