
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
| Malloc (bytes total) (M) *  |        59 |        59 |        59 |        59 |        59 |        59 |        59 |       162 |
| Malloc (total) (K) *        |       110 |       110 |       110 |       110 |       110 |       110 |       110 |       162 |
| Time (wall clock) (μs) *    |     27730 |     28344 |     29573 |     31654 |     35258 |     52429 |     52595 |       162 |

### GMSetzer CommonMark parse 100 KB (bytes: 100284, corpus: mixed-v1)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      5891 |      5891 |      5891 |      5891 |      5891 |      5891 |      5891 |      1831 |
| Malloc (total) (K) *        |        11 |        11 |        11 |        11 |        11 |        11 |        11 |      1831 |
| Time (wall clock) (μs) *    |      2666 |      2689 |      2705 |      2742 |      2785 |      2947 |     10816 |      1831 |

### GMSetzer CommonMark parse 5 MB (bytes: 5000500, corpus: mixed-v1)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |       292 |       292 |       292 |       292 |       292 |       292 |       292 |        35 |
| Malloc (total) (K) *        |       548 |       548 |       548 |       548 |       548 |       548 |       548 |        35 |
| Time (wall clock) (μs) *    |    145759 |    146276 |    146670 |    147587 |    147980 |    148569 |    148569 |        35 |

### GMSetzer GFM parse 1 MB (bytes: 1000100, corpus: mixed-v1)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |        68 |        68 |        68 |        68 |        68 |        68 |        68 |       150 |
| Malloc (total) (K) *        |       131 |       131 |       131 |       131 |       131 |       131 |       131 |       150 |
| Time (wall clock) (μs) *    |     32598 |     33063 |     33194 |     33423 |     33620 |     35488 |     68112 |       150 |

### GMSetzer GFM parse 100 KB (bytes: 100284, corpus: mixed-v1)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      8880 |      8880 |      8880 |      8880 |      8880 |      8880 |      8880 |      1537 |
| Malloc (total) (K) *        |        13 |        13 |        13 |        13 |        13 |        13 |        13 |      1537 |
| Time (wall clock) (μs) *    |      3186 |      3205 |      3224 |      3277 |      3351 |      3518 |      3694 |      1537 |

### GMSetzer GFM parse 5 MB (bytes: 5000500, corpus: mixed-v1)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |       439 |       439 |       439 |       439 |       439 |       439 |       439 |        29 |
| Malloc (total) (K) *        |       657 |       657 |       657 |       657 |       657 |       657 |       657 |        29 |
| Time (wall clock) (μs) *    |    170595 |    171835 |    172360 |    172753 |    173933 |    184347 |    184347 |        29 |

### cmark-gfm (C) CommonMark parse 1 MB (bytes: 1000100, corpus: mixed-v1)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |        30 |        30 |        30 |        30 |        30 |        30 |        30 |       258 |
| Malloc (total) (K) *        |       224 |       224 |       224 |       224 |       224 |       224 |       224 |       258 |
| Time (wall clock) (μs) *    |     18396 |     18776 |     18989 |     20070 |     20742 |     22184 |     22725 |       258 |

### cmark-gfm (C) CommonMark parse 100 KB (bytes: 100284, corpus: mixed-v1)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      2971 |      2971 |      2971 |      2971 |      2971 |      2971 |      2971 |      2874 |
| Malloc (total) (K) *        |        23 |        23 |        23 |        23 |        23 |        23 |        23 |      2874 |
| Time (wall clock) (μs) *    |      1695 |      1708 |      1719 |      1756 |      1801 |      1912 |      2097 |      2874 |

### cmark-gfm (C) CommonMark parse 5 MB (bytes: 5000500, corpus: mixed-v1)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |       148 |       148 |       148 |       148 |       148 |       148 |       148 |        52 |
| Malloc (total) (K) *        |      1122 |      1122 |      1122 |      1122 |      1122 |      1122 |      1122 |        52 |
| Time (wall clock) (μs) *    |     95219 |     96272 |     96600 |     96993 |     98435 |    108779 |    108779 |        52 |

### cmark-gfm (C) GFM parse 1 MB (bytes: 1000100, corpus: mixed-v1)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |        39 |        39 |        39 |        39 |        39 |        39 |        39 |       133 |
| Malloc (total) (K) *        |       431 |       431 |       431 |       431 |       431 |       431 |       431 |       133 |
| Time (wall clock) (μs) *    |     36645 |     37257 |     37552 |     37880 |     38535 |     40010 |     40333 |       133 |

### cmark-gfm (C) GFM parse 100 KB (bytes: 100284, corpus: mixed-v1)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      3878 |      3878 |      3878 |      3878 |      3878 |      3878 |      3878 |      1635 |
| Malloc (total) (K) *        |        43 |        43 |        43 |        43 |        43 |        43 |        43 |      1635 |
| Time (wall clock) (μs) *    |      2991 |      3009 |      3033 |      3088 |      3150 |      3316 |      3404 |      1635 |

### cmark-gfm (C) GFM parse 5 MB (bytes: 5000500, corpus: mixed-v1)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |       193 |       193 |       193 |       193 |       193 |       193 |       193 |        26 |
| Malloc (total) (K) *        |      2154 |      2154 |      2154 |      2154 |      2154 |      2154 |      2154 |        26 |
| Time (wall clock) (μs) *    |    191692 |    196477 |    197132 |    198443 |    204472 |    208693 |    208693 |        26 |

