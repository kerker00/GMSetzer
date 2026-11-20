warning: '--skip-update' option is deprecated and will be removed in a future release
Building for debugging...
[Computing dependencies]
[Using on-disk description]
[15 / 76] RealModule
[28 / 83] BenchmarkShared
[38 / 93] MallocInterposerC
[50 / 84] SystemPackage
[58 / 82] MallocInterposerSwift
[66 / 75] MallocInterposerSwift-product
[69 / 78] Benchmark
[79 / 84]
[80 / 85] SwiftRuntimeHooks
[81 / 87] Benchmark
[88 / 96] BenchmarkTool-product
[89 / 96] BenchmarkTool-product
[91 / 96] BenchmarkTool-product
[93 / 96] BenchmarkTool-product
[95 / 96] BenchmarkTool-product
Build complete! (3,35 secs)

[33mWarning: this project depends on the benchmark package using its legacy
identifier 'package-benchmark'. The repository has been renamed; please update
your Package.swift to use the new URL and identifier:

  .package(url: "https://github.com/ordo-one/benchmark", ...)
  .product(name: "Benchmark", package: "benchmark"),
  .plugin(name: "BenchmarkPlugin", package: "benchmark"),

Support for the legacy 'package-benchmark' identifier will be removed in a
future release.[0m


## Baseline 'Current_run'

```
Host 'BlackBook.local' with 8 'arm64' processors with 16 GB memory, running:
Darwin Kernel Version 27.0.0: Tue Aug 11 21:02:16 PDT 2026; root:xnu-13432.1.9~1/RELEASE_ARM64_T8112
```
## ParserBenchmarks

### GMSetzer CommonMark parse 1 MB (bytes: 1000100, corpus: mixed-v1)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |        38 |        38 |        38 |        38 |        38 |        38 |        38 |       203 |
| Malloc (total) (K) *        |       113 |       113 |       113 |       113 |       113 |       113 |       113 |       203 |
| Time (wall clock) (μs) *    |     24002 |     24297 |     24592 |     24805 |     25494 |     25952 |     26424 |       203 |

### GMSetzer CommonMark parse 100 KB (bytes: 100284, corpus: mixed-v1)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      5195 |      5195 |      5195 |      5195 |      5195 |      5195 |      5195 |      1992 |
| Malloc (total) (K) *        |        11 |        11 |        11 |        11 |        11 |        11 |        11 |      1992 |
| Time (wall clock) (μs) *    |      2395 |      2433 |      2468 |      2523 |      2585 |      2847 |     34751 |      1992 |

### GMSetzer CommonMark parse 5 MB (bytes: 5000500, corpus: mixed-v1)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |       216 |       216 |       216 |       216 |       216 |       216 |       216 |        41 |
| Malloc (total) (K) *        |       566 |       566 |       566 |       566 |       566 |       566 |       566 |        41 |
| Time (wall clock) (μs) *    |    121451 |    122159 |    122683 |    123994 |    126878 |    138395 |    138395 |        41 |

### GMSetzer reference syntax off 1 MB (bytes: 1000098, corpus: references-v1)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |        28 |        28 |        28 |        28 |        28 |        28 |        28 |       192 |
| Malloc (total) (K) *        |       147 |       147 |       147 |       147 |       147 |       147 |       147 |       192 |
| Time (wall clock) (μs) *    |     25367 |     25608 |     25919 |     26329 |     27001 |     28230 |     28723 |       192 |

### GMSetzer reference syntax off 100 KB (bytes: 100188, corpus: references-v1)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      3207 |      3207 |      3207 |      3207 |      3207 |      3207 |      3207 |      1983 |
| Malloc (total) (K) *        |        15 |        15 |        15 |        15 |        15 |        15 |        15 |      1983 |
| Time (wall clock) (μs) *    |      2443 |      2476 |      2501 |      2550 |      2615 |      2779 |      3148 |      1983 |

### GMSetzer reference syntax off 5 MB (bytes: 5000094, corpus: references-v1)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |       162 |       162 |       162 |       162 |       162 |       162 |       162 |        39 |
| Malloc (total) (K) *        |       732 |       732 |       732 |       732 |       732 |       732 |       732 |        39 |
| Time (wall clock) (μs) *    |    126468 |    127468 |    130613 |    132776 |    135266 |    138785 |    138785 |        39 |

### GMSetzer reference syntax on 1 MB (bytes: 1000098, corpus: references-v1)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |        53 |        53 |        53 |        53 |        53 |        53 |        53 |       153 |
| Malloc (total) (K) *        |       227 |       227 |       227 |       227 |       227 |       227 |       227 |       153 |
| Time (wall clock) (μs) *    |     32130 |     32391 |     32506 |     32702 |     33260 |     35389 |     56150 |       153 |

### GMSetzer reference syntax on 100 KB (bytes: 100188, corpus: references-v1)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      4641 |      4641 |      4641 |      4641 |      4641 |      4641 |      4641 |      1490 |
| Malloc (total) (K) *        |        23 |        23 |        23 |        23 |        23 |        23 |        23 |      1490 |
| Time (wall clock) (μs) *    |      3243 |      3283 |      3320 |      3402 |      3494 |      3713 |      4101 |      1490 |

### GMSetzer reference syntax on 5 MB (bytes: 5000094, corpus: references-v1)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |       244 |       244 |       244 |       244 |       244 |       244 |       244 |        31 |
| Malloc (total) (K) *        |      1136 |      1136 |      1136 |      1136 |      1136 |      1136 |      1136 |        31 |
| Time (wall clock) (μs) *    |    163755 |    164233 |    164758 |    167379 |    169607 |    173611 |    173611 |        31 |

### GMSetzer selected registry parse 1 MB (bytes: 1000100, corpus: mixed-v1)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |        38 |        38 |        38 |        38 |        38 |        38 |        38 |       188 |
| Malloc (total) (K) *        |       113 |       113 |       113 |       113 |       113 |       113 |       113 |       188 |
| Time (wall clock) (μs) *    |     25942 |     26132 |     26345 |     26837 |     27836 |     28459 |     28742 |       188 |

### GMSetzer selected registry parse 100 KB (bytes: 100284, corpus: mixed-v1)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      5195 |      5195 |      5195 |      5195 |      5195 |      5195 |      5195 |      1841 |
| Malloc (total) (K) *        |        11 |        11 |        11 |        11 |        11 |        11 |        11 |      1841 |
| Time (wall clock) (μs) *    |      2602 |      2623 |      2650 |      2726 |      2824 |      3213 |     40773 |      1841 |

### GMSetzer selected registry parse 5 MB (bytes: 5000500, corpus: mixed-v1)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |       216 |       216 |       216 |       216 |       216 |       216 |       216 |        35 |
| Malloc (total) (K) *        |       566 |       566 |       566 |       566 |       566 |       566 |       566 |        35 |
| Time (wall clock) (μs) *    |    131999 |    133169 |    137626 |    141033 |    148374 |    289032 |    289032 |        35 |

### cmark-gfm (C) CommonMark parse 1 MB (bytes: 1000100, corpus: mixed-v1)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |        30 |        30 |        30 |        30 |        30 |        30 |        30 |       245 |
| Malloc (total) (K) *        |       224 |       224 |       224 |       224 |       224 |       224 |       224 |       245 |
| Time (wall clock) (μs) *    |     18661 |     19186 |     19939 |     20759 |     21643 |     35226 |     45238 |       245 |

### cmark-gfm (C) CommonMark parse 100 KB (bytes: 100284, corpus: mixed-v1)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      2971 |      2971 |      2971 |      2971 |      2971 |      2971 |      2971 |      2809 |
| Malloc (total) (K) *        |        23 |        23 |        23 |        23 |        23 |        23 |        23 |      2809 |
| Time (wall clock) (μs) *    |      1713 |      1731 |      1758 |      1812 |      1852 |      1983 |      5525 |      2809 |

### cmark-gfm (C) CommonMark parse 5 MB (bytes: 5000500, corpus: mixed-v1)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |       148 |       148 |       148 |       148 |       148 |       148 |       148 |        49 |
| Malloc (total) (K) *        |      1122 |      1122 |      1122 |      1122 |      1122 |      1122 |      1122 |        49 |
| Time (wall clock) (μs) *    |     94924 |     95486 |     95945 |    102826 |    116851 |    169665 |    169665 |        49 |
