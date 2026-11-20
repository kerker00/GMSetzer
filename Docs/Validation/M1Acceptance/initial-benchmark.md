warning: '--skip-update' option is deprecated and will be removed in a future release
Building for debugging...
[Computing dependencies]
[Constructing description]
[Pre-planning 1 / 599]
[Planning deferred tasks]
[19 / 117] ArgumentParserToolInfo
[30 / 133] ArgumentParserToolInfo
[40 / 143] BenchmarkShared
[52 / 146] RealModule
[59 / 147] SystemPackage
[60 / 147] SystemPackage
[63 / 147] MallocInterposerSwift
[67 / 146] Atomics
[80 / 155] SystemPackage
[84 / 155] ComplexModule
[85 / 155] CSystem
[90 / 155] Atomics
[97 / 157] Numerics
[103 / 159] Numerics
[111 / 158] MallocInterposerSwift
[113 / 159] TextTable
[116 / 170] Histogram
[121 / 176] TextTable
[128 / 176] Histogram
[136 / 173] ArgumentParserToolInfo
[144 / 170] ArgumentParser
[151 / 169] Benchmark
[153 / 169] ArgumentParser
[155 / 168] ArgumentParser
[160 / 181] ArgumentParser
[164 / 181] Benchmark
[165 / 181] ArgumentParser
[167 / 181] Benchmark
[169 / 181] Benchmark
[170 / 181] Benchmark
[173 / 182] Benchmark
[173 / 182] BenchmarkTool-product
[178 / 191] BenchmarkTool-product
[181 / 191] BenchmarkTool-product
[184 / 191] ArgumentParser
[186 / 191] Benchmark
[186 / 191] BenchmarkTool-product
[187 / 191] SystemPackage
[191 / 192] BenchmarkTool-product
Build complete! (8,67 secs)

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
| Malloc (bytes total) (M) *  |        38 |        38 |        38 |        38 |        38 |        38 |        38 |       202 |
| Malloc (total) (K) *        |       113 |       113 |       113 |       113 |       113 |       113 |       113 |       202 |
| Time (wall clock) (μs) *    |     24223 |     24412 |     24543 |     24773 |     25903 |     28918 |     29644 |       202 |

### GMSetzer CommonMark parse 100 KB (bytes: 100284, corpus: mixed-v1)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      5195 |      5195 |      5195 |      5195 |      5195 |      5195 |      5195 |      2008 |
| Malloc (total) (K) *        |        11 |        11 |        11 |        11 |        11 |        11 |        11 |      2008 |
| Time (wall clock) (μs) *    |      2413 |      2451 |      2474 |      2509 |      2564 |      2732 |      3262 |      2008 |

### GMSetzer CommonMark parse 5 MB (bytes: 5000500, corpus: mixed-v1)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |       191 |       216 |       216 |       216 |       216 |       216 |       216 |        40 |
| Malloc (total) (K) *        |       566 |       566 |       566 |       566 |       566 |       566 |       566 |        40 |
| Time (wall clock) (μs) *    |    123456 |    123929 |    124322 |    125764 |    129434 |    170607 |    170607 |        40 |

### GMSetzer GFM parse 1 MB (bytes: 1000100, corpus: mixed-v1)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |        38 |        38 |        38 |        38 |        38 |        38 |        38 |       202 |
| Malloc (total) (K) *        |       113 |       113 |       113 |       113 |       113 |       113 |       113 |       202 |
| Time (wall clock) (μs) *    |     24269 |     24461 |     24560 |     24805 |     25379 |     30753 |     33277 |       202 |

### GMSetzer GFM parse 100 KB (bytes: 100284, corpus: mixed-v1)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      5198 |      5198 |      5198 |      5198 |      5198 |      5198 |      5198 |      1985 |
| Malloc (total) (K) *        |        11 |        11 |        11 |        11 |        11 |        11 |        11 |      1985 |
| Time (wall clock) (μs) *    |      2418 |      2449 |      2472 |      2515 |      2591 |      2750 |     45165 |      1985 |

### GMSetzer GFM parse 5 MB (bytes: 5000500, corpus: mixed-v1)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |       216 |       216 |       216 |       216 |       216 |       216 |       216 |        40 |
| Malloc (total) (K) *        |       566 |       566 |       566 |       566 |       566 |       566 |       566 |        40 |
| Time (wall clock) (μs) *    |    123158 |    123732 |    124715 |    125764 |    127730 |    157387 |    157387 |        40 |

### GMSetzer reference syntax off 1 MB (bytes: 1000098, corpus: references-v1)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |        28 |        28 |        28 |        28 |        28 |        28 |        28 |       192 |
| Malloc (total) (K) *        |       147 |       147 |       147 |       147 |       147 |       147 |       147 |       192 |
| Time (wall clock) (μs) *    |     25516 |     25674 |     25788 |     26034 |     27165 |     28606 |     28715 |       192 |

### GMSetzer reference syntax off 100 KB (bytes: 100188, corpus: references-v1)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      3207 |      3207 |      3207 |      3207 |      3207 |      3207 |      3207 |      1915 |
| Malloc (total) (K) *        |        15 |        15 |        15 |        15 |        15 |        15 |        15 |      1915 |
| Time (wall clock) (μs) *    |      2517 |      2558 |      2583 |      2621 |      2681 |      3076 |      5640 |      1915 |

### GMSetzer reference syntax off 5 MB (bytes: 5000094, corpus: references-v1)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |       136 |       162 |       162 |       162 |       162 |       162 |       162 |        39 |
| Malloc (total) (K) *        |       732 |       732 |       732 |       732 |       732 |       732 |       732 |        39 |
| Time (wall clock) (μs) *    |    129269 |    129696 |    129827 |    130613 |    133956 |    143236 |    143236 |        39 |

### GMSetzer reference syntax on 1 MB (bytes: 1000098, corpus: references-v1)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |        59 |        59 |        59 |        59 |        59 |        59 |        59 |       115 |
| Malloc (total) (K) *        |       318 |       318 |       318 |       318 |       318 |       318 |       318 |       115 |
| Time (wall clock) (μs) *    |     42480 |     42828 |     43221 |     43745 |     45056 |     59802 |     59837 |       115 |

### GMSetzer reference syntax on 100 KB (bytes: 100188, corpus: references-v1)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      5224 |      5224 |      5224 |      5224 |      5224 |      5224 |      5224 |      1165 |
| Malloc (total) (K) *        |        32 |        32 |        32 |        32 |        32 |        32 |        32 |      1165 |
| Time (wall clock) (μs) *    |      4179 |      4235 |      4264 |      4309 |      4407 |      4698 |      6491 |      1165 |

### GMSetzer reference syntax on 5 MB (bytes: 5000094, corpus: references-v1)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |       273 |       273 |       273 |       273 |       273 |       273 |       273 |        23 |
| Malloc (total) (K) *        |      1591 |      1591 |      1591 |      1591 |      1591 |      1591 |      1591 |        23 |
| Time (wall clock) (μs) *    |    219249 |    220332 |    221512 |    231211 |    236061 |    240415 |    240415 |        23 |

### GMSetzer render 1 MB (bytes: 1000100, corpus: mixed-v1)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |        13 |        13 |        13 |        13 |        13 |        13 |        13 |       255 |
| Malloc (total) (K) *        |       128 |       128 |       128 |       128 |       128 |       128 |       128 |       255 |
| Time (wall clock) (μs) *    |     19198 |     19366 |     19448 |     19644 |     20677 |     22249 |     22399 |       255 |

### GMSetzer render 100 KB (bytes: 100284, corpus: mixed-v1)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      1444 |      1444 |      1444 |      1444 |      1444 |      1444 |      1444 |      2581 |
| Malloc (total) (K) *        |        13 |        13 |        13 |        13 |        13 |        13 |        13 |      2581 |
| Time (wall clock) (μs) *    |      1854 |      1876 |      1900 |      1951 |      1998 |      2312 |      9706 |      2581 |

### GMSetzer render 5 MB (bytes: 5000500, corpus: mixed-v1)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |        61 |        61 |        61 |        61 |        61 |        61 |        61 |        49 |
| Malloc (total) (K) *        |       639 |       639 |       639 |       639 |       639 |       639 |       639 |        49 |
| Time (wall clock) (μs) *    |     99176 |    100401 |    101777 |    103350 |    105644 |    148227 |    148227 |        49 |

### GMSetzer segment reconstruction 1 MB (bytes: 1000100, corpus: mixed-v1)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      3241 |      3241 |      3241 |      3241 |      3241 |      3241 |      3241 |      1156 |
| Malloc (total) (K) *        |        51 |        51 |        51 |        51 |        51 |        51 |        51 |      1156 |
| Time (wall clock) (μs) *    |      4187 |      4248 |      4280 |      4338 |      4465 |      4948 |      9157 |      1156 |

### GMSetzer segment reconstruction 100 KB (bytes: 100284, corpus: mixed-v1)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |       325 |       325 |       325 |       325 |       325 |       325 |       325 |     10000 |
| Malloc (total) *            |      5125 |      5125 |      5125 |      5125 |      5125 |      5125 |      5125 |     10000 |
| Time (wall clock) (μs) *    |       418 |       423 |       425 |       444 |       458 |       551 |      1474 |     10000 |

### GMSetzer segment reconstruction 5 MB (bytes: 5000500, corpus: mixed-v1)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |        16 |        16 |        16 |        16 |        16 |        16 |        16 |       229 |
| Malloc (total) (K) *        |       256 |       256 |       256 |       256 |       256 |       256 |       256 |       229 |
| Time (wall clock) (μs) *    |     21170 |     21414 |     21529 |     21807 |     22643 |     28590 |     33896 |       229 |

### GMSetzer text reconstruction 1 MB (bytes: 1000100, corpus: mixed-v1)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      1956 |      1956 |      1956 |      1956 |      1956 |      1956 |      1956 |      3406 |
| Malloc (total) (K) *        |        16 |        16 |        16 |        16 |        16 |        16 |        16 |      3406 |
| Time (wall clock) (μs) *    |      1415 |      1434 |      1453 |      1490 |      1524 |      1655 |      2443 |      3406 |

### GMSetzer text reconstruction 100 KB (bytes: 100284, corpus: mixed-v1)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |       196 |       196 |       196 |       196 |       196 |       196 |       196 |     10000 |
| Malloc (total) *            |      1648 |      1648 |      1648 |      1648 |      1648 |      1648 |      1648 |     10000 |
| Time (wall clock) (μs) *    |       142 |       143 |       144 |       145 |       153 |       187 |       281 |     10000 |

### GMSetzer text reconstruction 5 MB (bytes: 5000500, corpus: mixed-v1)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      9782 |      9782 |      9782 |      9782 |      9782 |      9782 |      9782 |       676 |
| Malloc (total) (K) *        |        82 |        82 |        82 |        82 |        82 |        82 |        82 |       676 |
| Time (wall clock) (μs) *    |      7120 |      7225 |      7274 |      7401 |      7696 |     10502 |     12797 |       676 |

### GMSetzer validate 1 MB (bytes: 1000100, corpus: mixed-v1)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |        77 |        77 |        77 |        77 |        77 |        77 |        77 |      2963 |
| Malloc (total) *            |         3 |         3 |         3 |         3 |         3 |         3 |         3 |      2963 |
| Time (wall clock) (μs) *    |      1544 |      1574 |      1604 |      1662 |      1723 |      2449 |    111097 |      2963 |

### GMSetzer validate 100 KB (bytes: 100284, corpus: mixed-v1)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) *      |      7927 |      7927 |      7927 |      7927 |      7927 |      7927 |      7927 |     10000 |
| Malloc (total) *            |         3 |         3 |         3 |         3 |         3 |         3 |         3 |     10000 |
| Time (wall clock) (μs) *    |       153 |       156 |       157 |       166 |       177 |       368 |      1426 |     10000 |

### GMSetzer validate 5 MB (bytes: 5000500, corpus: mixed-v1)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |       383 |       383 |       383 |       383 |       383 |       383 |       383 |       607 |
| Malloc (total) *            |         3 |         3 |         3 |         3 |         3 |         3 |         3 |       607 |
| Time (wall clock) (μs) *    |      7956 |      8106 |      8188 |      8319 |      8561 |      8757 |      9225 |       607 |

### cmark-gfm (C) CommonMark parse 1 MB (bytes: 1000100, corpus: mixed-v1)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |        30 |        30 |        30 |        30 |        30 |        30 |        30 |       263 |
| Malloc (total) (K) *        |       224 |       224 |       224 |       224 |       224 |       224 |       224 |       263 |
| Time (wall clock) (μs) *    |     18346 |     18711 |     18825 |     18973 |     19284 |     25215 |     32201 |       263 |

### cmark-gfm (C) CommonMark parse 100 KB (bytes: 100284, corpus: mixed-v1)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      2971 |      2971 |      2971 |      2971 |      2971 |      2971 |      2971 |      2779 |
| Malloc (total) (K) *        |        23 |        23 |        23 |        23 |        23 |        23 |        23 |      2779 |
| Time (wall clock) (μs) *    |      1705 |      1735 |      1754 |      1808 |      1857 |      2140 |     17223 |      2779 |

### cmark-gfm (C) CommonMark parse 5 MB (bytes: 5000500, corpus: mixed-v1)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |       148 |       148 |       148 |       148 |       148 |       148 |       148 |        51 |
| Malloc (total) (K) *        |      1122 |      1122 |      1122 |      1122 |      1122 |      1122 |      1122 |        51 |
| Time (wall clock) (μs) *    |     95148 |     96141 |     97059 |    101384 |    107414 |    126619 |    126619 |        51 |

### cmark-gfm (C) GFM parse 1 MB (bytes: 1000100, corpus: mixed-v1)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |        39 |        39 |        39 |        39 |        39 |        39 |        39 |       135 |
| Malloc (total) (K) *        |       431 |       431 |       431 |       431 |       431 |       431 |       431 |       135 |
| Time (wall clock) (μs) *    |     35945 |     36438 |     36798 |     37323 |     37945 |     42041 |     66078 |       135 |

### cmark-gfm (C) GFM parse 100 KB (bytes: 100284, corpus: mixed-v1)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      3878 |      3878 |      3878 |      3878 |      3878 |      3878 |      3878 |      1585 |
| Malloc (total) (K) *        |        43 |        43 |        43 |        43 |        43 |        43 |        43 |      1585 |
| Time (wall clock) (μs) *    |      3033 |      3064 |      3101 |      3160 |      3258 |      3815 |      9202 |      1585 |

### cmark-gfm (C) GFM parse 5 MB (bytes: 5000500, corpus: mixed-v1)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |       193 |       193 |       193 |       193 |       193 |       193 |       193 |        26 |
| Malloc (total) (K) *        |      2154 |      2154 |      2154 |      2154 |      2154 |      2154 |      2154 |        26 |
| Time (wall clock) (μs) *    |    194244 |    195559 |    195953 |    198312 |    206569 |    209046 |    209046 |        26 |

### cmark-gfm (C) references 1 MB (bytes: 1000098, corpus: references-v1)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |        15 |        15 |        15 |        15 |        15 |        15 |        15 |       353 |
| Malloc (total) (K) *        |       162 |       162 |       162 |       162 |       162 |       162 |       162 |       353 |
| Time (wall clock) (μs) *    |     13717 |     13844 |     13902 |     14066 |     14844 |     20546 |     23387 |       353 |

### cmark-gfm (C) references 100 KB (bytes: 100188, corpus: references-v1)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      1510 |      1510 |      1510 |      1510 |      1510 |      1510 |      1510 |      3608 |
| Malloc (total) (K) *        |        16 |        16 |        16 |        16 |        16 |        16 |        16 |      3608 |
| Time (wall clock) (μs) *    |      1344 |      1354 |      1364 |      1396 |      1444 |      1596 |      2015 |      3608 |

### cmark-gfm (C) references 5 MB (bytes: 5000094, corpus: references-v1)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |        75 |        75 |        75 |        75 |        75 |        75 |        75 |        65 |
| Malloc (total) (K) *        |       808 |       808 |       808 |       808 |       808 |       808 |       808 |        65 |
| Time (wall clock) (μs) *    |     76380 |     76939 |     77267 |     77988 |     80019 |     96329 |     96329 |        65 |

### swift-markdown parse 1 MB (bytes: 1000100, corpus: mixed-v1)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |        67 |        67 |        67 |        67 |        67 |        67 |        67 |        21 |
| Malloc (total) (K) *        |       653 |       653 |       653 |       653 |       653 |       653 |       653 |        21 |
| Time (wall clock) (μs) *    |    230857 |    231866 |    233964 |    252051 |    260309 |    283349 |    283349 |        21 |

### swift-markdown parse 100 KB (bytes: 100284, corpus: mixed-v1)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      6731 |      6731 |      6731 |      6731 |      6731 |      6731 |      6731 |       197 |
| Malloc (total) (K) *        |        66 |        66 |        66 |        66 |        66 |        66 |        66 |       197 |
| Time (wall clock) (μs) *    |     22816 |     24134 |     24756 |     26903 |     28541 |     31113 |     34875 |       197 |

### swift-markdown parse 5 MB (bytes: 5000500, corpus: mixed-v1)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |       335 |       335 |       335 |       335 |       335 |       335 |       335 |         5 |
| Malloc (total) (K) *        |      3267 |      3267 |      3267 |      3267 |      3267 |      3267 |      3267 |         5 |
| Time (wall clock) (μs) *    |   1190033 |   1210057 |   1221591 |   1226834 |   1256461 |   1256461 |   1256461 |         5 |

