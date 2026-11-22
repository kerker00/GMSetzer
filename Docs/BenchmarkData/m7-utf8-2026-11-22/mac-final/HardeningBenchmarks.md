
## Baseline 'Current_run'

```
Host 'BlackBook.local' with 8 'arm64' processors with 16 GB memory, running:
Darwin Kernel Version 27.0.0: Tue Aug 11 21:02:16 PDT 2026; root:xnu-13432.1.9~1/RELEASE_ARM64_T8112
```
## HardeningBenchmarks

### GMSetzer footnotes-repeated-v1 parse syntax-off 16 KiB (bytes: 16398, corpus: footnotes-repeated-v1, profile: gfm-footnotes, syntax: off)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      3255 |      3255 |      3255 |      3255 |      3255 |      3255 |      3255 |      1732 |
| Malloc (total) (K) *        |        12 |        12 |        12 |        12 |        12 |        12 |        12 |      1732 |
| Time (wall clock) (μs) *    |      2768 |      2832 |      2863 |      2914 |      2990 |      3262 |      3583 |      1732 |

### GMSetzer footnotes-repeated-v1 parse syntax-off 256 KiB (bytes: 262158, corpus: footnotes-repeated-v1, profile: gfm-footnotes, syntax: off)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |        59 |        59 |        59 |        59 |        59 |        59 |        59 |       108 |
| Malloc (total) (K) *        |       184 |       184 |       184 |       184 |       184 |       184 |       184 |       108 |
| Time (wall clock) (μs) *    |     45611 |     46105 |     46498 |     47055 |     47481 |     48333 |     48680 |       108 |

### GMSetzer footnotes-repeated-v1 parse syntax-off 64 KiB (bytes: 65538, corpus: footnotes-repeated-v1, profile: gfm-footnotes, syntax: off)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |        15 |        15 |        15 |        15 |        15 |        15 |        15 |       425 |
| Malloc (total) (K) *        |        46 |        46 |        46 |        46 |        46 |        46 |        46 |       425 |
| Time (wall clock) (μs) *    |     11437 |     11608 |     11690 |     11903 |     12083 |     12427 |     12833 |       425 |

### GMSetzer footnotes-repeated-v1 parse syntax-on 16 KiB (bytes: 16398, corpus: footnotes-repeated-v1, profile: gfm-footnotes, syntax: on)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      4041 |      4041 |      4041 |      4041 |      4041 |      4041 |      4041 |      1488 |
| Malloc (total) (K) *        |        12 |        12 |        12 |        12 |        12 |        12 |        12 |      1488 |
| Time (wall clock) (μs) *    |      3259 |      3301 |      3328 |      3369 |      3443 |      3822 |     11146 |      1488 |

### GMSetzer footnotes-repeated-v1 parse syntax-on 256 KiB (bytes: 262158, corpus: footnotes-repeated-v1, profile: gfm-footnotes, syntax: on)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |        72 |        72 |        72 |        72 |        72 |        72 |        72 |        93 |
| Malloc (total) (K) *        |       184 |       184 |       184 |       184 |       184 |       184 |       184 |        93 |
| Time (wall clock) (μs) *    |     52748 |     53445 |     53936 |     54821 |     55673 |     56232 |     56232 |        93 |

### GMSetzer footnotes-repeated-v1 parse syntax-on 64 KiB (bytes: 65538, corpus: footnotes-repeated-v1, profile: gfm-footnotes, syntax: on)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |        18 |        18 |        18 |        18 |        18 |        18 |        18 |       382 |
| Malloc (total) (K) *        |        46 |        46 |        46 |        46 |        46 |        46 |        46 |       382 |
| Time (wall clock) (μs) *    |     12768 |     12960 |     13050 |     13255 |     13435 |     13943 |     14327 |       382 |

### GMSetzer footnotes-repeated-v1 parse-render syntax-off 16 KiB (bytes: 16398, corpus: footnotes-repeated-v1, profile: gfm-footnotes, syntax: off)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      5451 |      5451 |      5451 |      5451 |      5451 |      5451 |      5451 |       978 |
| Malloc (total) (K) *        |        21 |        21 |        21 |        21 |        21 |        21 |        21 |       978 |
| Time (wall clock) (μs) *    |      4947 |      5030 |      5095 |      5173 |      5259 |      5661 |      5913 |       978 |

### GMSetzer footnotes-repeated-v1 parse-render syntax-off 256 KiB (bytes: 262158, corpus: footnotes-repeated-v1, profile: gfm-footnotes, syntax: off)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |        95 |        95 |        95 |        95 |        95 |        95 |        95 |        60 |
| Malloc (total) (K) *        |       332 |       332 |       332 |       332 |       332 |       332 |       332 |        60 |
| Time (wall clock) (μs) *    |     82746 |     83689 |     84214 |     85524 |     85983 |     87910 |     87910 |        60 |

### GMSetzer footnotes-repeated-v1 parse-render syntax-off 64 KiB (bytes: 65538, corpus: footnotes-repeated-v1, profile: gfm-footnotes, syntax: off)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |        23 |        23 |        23 |        23 |        23 |        23 |        23 |       231 |
| Malloc (total) (K) *        |        83 |        83 |        83 |        83 |        83 |        83 |        83 |       231 |
| Time (wall clock) (μs) *    |     20734 |     21004 |     21414 |     22036 |     22774 |     23904 |     36400 |       231 |

### GMSetzer footnotes-repeated-v1 parse-render syntax-on 16 KiB (bytes: 16398, corpus: footnotes-repeated-v1, profile: gfm-footnotes, syntax: on)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      6236 |      6236 |      6236 |      6236 |      6236 |      6236 |      6236 |       926 |
| Malloc (total) (K) *        |        21 |        21 |        21 |        21 |        21 |        21 |        21 |       926 |
| Time (wall clock) (μs) *    |      5301 |      5362 |      5386 |      5423 |      5468 |      5886 |      6220 |       926 |

### GMSetzer footnotes-repeated-v1 parse-render syntax-on 256 KiB (bytes: 262158, corpus: footnotes-repeated-v1, profile: gfm-footnotes, syntax: on)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |       108 |       108 |       108 |       108 |       108 |       108 |       108 |        56 |
| Malloc (total) (K) *        |       332 |       332 |       332 |       332 |       332 |       332 |       332 |        56 |
| Time (wall clock) (μs) *    |     86068 |     87491 |     88146 |     92209 |     94503 |     96629 |     96629 |        56 |

### GMSetzer footnotes-repeated-v1 parse-render syntax-on 64 KiB (bytes: 65538, corpus: footnotes-repeated-v1, profile: gfm-footnotes, syntax: on)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |        27 |        27 |        27 |        27 |        27 |        27 |        27 |       226 |
| Malloc (total) (K) *        |        83 |        83 |        83 |        83 |        83 |        83 |        83 |       226 |
| Time (wall clock) (μs) *    |     21375 |     21627 |     21856 |     22594 |     23101 |     23953 |     24271 |       226 |

### GMSetzer invalid-utf8-v1 parse syntax-off 16 KiB (bytes: 16388, corpus: invalid-utf8-v1, profile: commonmark, syntax: off)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      1252 |      1252 |      1252 |      1252 |      1252 |      1252 |      1252 |      7487 |
| Malloc (total) *            |      2738 |      2738 |      2738 |      2738 |      2738 |      2738 |      2738 |      7487 |
| Time (wall clock) (μs) *    |       637 |       645 |       656 |       676 |       701 |       794 |      8137 |      7487 |

### GMSetzer invalid-utf8-v1 parse syntax-off 256 KiB (bytes: 262148, corpus: invalid-utf8-v1, profile: commonmark, syntax: off)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |        21 |        21 |        21 |        21 |        21 |        21 |        21 |       470 |
| Malloc (total) (K) *        |        44 |        44 |        44 |        44 |        44 |        44 |        44 |       470 |
| Time (wall clock) (μs) *    |     10238 |     10461 |     10592 |     10756 |     10969 |     11960 |     12519 |       470 |

### GMSetzer invalid-utf8-v1 parse syntax-off 64 KiB (bytes: 65540, corpus: invalid-utf8-v1, profile: commonmark, syntax: off)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      5200 |      5200 |      5200 |      5200 |      5200 |      5200 |      5200 |      1846 |
| Malloc (total) (K) *        |        11 |        11 |        11 |        11 |        11 |        11 |        11 |      1846 |
| Time (wall clock) (μs) *    |      2585 |      2623 |      2660 |      2724 |      2796 |      3213 |     19252 |      1846 |

### GMSetzer invalid-utf8-v1 parse syntax-on 16 KiB (bytes: 16388, corpus: invalid-utf8-v1, profile: commonmark, syntax: on)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      1252 |      1252 |      1252 |      1252 |      1252 |      1252 |      1252 |      7474 |
| Malloc (total) *            |      2738 |      2738 |      2738 |      2738 |      2738 |      2738 |      2738 |      7474 |
| Time (wall clock) (μs) *    |       641 |       652 |       660 |       676 |       697 |       758 |      1007 |      7474 |

### GMSetzer invalid-utf8-v1 parse syntax-on 256 KiB (bytes: 262148, corpus: invalid-utf8-v1, profile: commonmark, syntax: on)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |        21 |        21 |        21 |        21 |        21 |        21 |        21 |       475 |
| Malloc (total) (K) *        |        44 |        44 |        44 |        44 |        44 |        44 |        44 |       475 |
| Time (wall clock) (μs) *    |     10186 |     10355 |     10453 |     10641 |     10772 |     11313 |     24062 |       475 |

### GMSetzer invalid-utf8-v1 parse syntax-on 64 KiB (bytes: 65540, corpus: invalid-utf8-v1, profile: commonmark, syntax: on)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      5200 |      5200 |      5200 |      5200 |      5200 |      5200 |      5200 |      1904 |
| Malloc (total) (K) *        |        11 |        11 |        11 |        11 |        11 |        11 |        11 |      1904 |
| Time (wall clock) (μs) *    |      2538 |      2580 |      2607 |      2658 |      2714 |      2896 |      3160 |      1904 |

### GMSetzer long-emphasis-v1 parse syntax-off 16 KiB (bytes: 16390, corpus: long-emphasis-v1, profile: commonmark, syntax: off)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      1125 |      1125 |      1125 |      1125 |      1125 |      1125 |      1125 |     10000 |
| Malloc (total) *            |        29 |        29 |        29 |        29 |        29 |        29 |        29 |     10000 |
| Time (wall clock) (μs) *    |       242 |       246 |       249 |       261 |       274 |       324 |      3734 |     10000 |

### GMSetzer long-emphasis-v1 parse syntax-off 256 KiB (bytes: 262150, corpus: long-emphasis-v1, profile: commonmark, syntax: off)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |        26 |        26 |        26 |        26 |        26 |        26 |        26 |      1205 |
| Malloc (total) *            |        33 |        33 |        33 |        33 |        33 |        33 |        33 |      1205 |
| Time (wall clock) (μs) *    |      3985 |      4059 |      4121 |      4219 |      4313 |      4502 |      5053 |      1205 |

### GMSetzer long-emphasis-v1 parse syntax-off 64 KiB (bytes: 65542, corpus: long-emphasis-v1, profile: commonmark, syntax: off)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      6053 |      6053 |      6053 |      6053 |      6053 |      6053 |      6053 |      4832 |
| Malloc (total) *            |        31 |        31 |        31 |        31 |        31 |        31 |        31 |      4832 |
| Time (wall clock) (μs) *    |       977 |       993 |      1012 |      1050 |      1097 |      1233 |     14236 |      4832 |

### GMSetzer long-emphasis-v1 parse syntax-on 16 KiB (bytes: 16390, corpus: long-emphasis-v1, profile: commonmark, syntax: on)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      2696 |      2696 |      2696 |      2696 |      2696 |      2696 |      2696 |     10000 |
| Malloc (total) *            |        58 |        58 |        58 |        58 |        58 |        58 |        58 |     10000 |
| Time (wall clock) (μs) *    |       403 |       408 |       417 |       436 |       476 |       649 |      2287 |     10000 |

### GMSetzer long-emphasis-v1 parse syntax-on 256 KiB (bytes: 262150, corpus: long-emphasis-v1, profile: commonmark, syntax: on)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |        51 |        51 |        51 |        51 |        51 |        51 |        51 |       684 |
| Malloc (total) *            |        70 |        70 |        70 |        70 |        70 |        70 |        70 |       684 |
| Time (wall clock) (μs) *    |      6722 |      6840 |      6955 |      7160 |      7754 |     15622 |     42907 |       684 |

### GMSetzer long-emphasis-v1 parse syntax-on 64 KiB (bytes: 65542, corpus: long-emphasis-v1, profile: commonmark, syntax: on)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |        12 |        12 |        12 |        12 |        12 |        12 |        12 |      3002 |
| Malloc (total) *            |        64 |        64 |        64 |        64 |        64 |        64 |        64 |      3002 |
| Time (wall clock) (μs) *    |      1613 |      1634 |      1650 |      1680 |      1725 |      1843 |      2102 |      3002 |

### GMSetzer m5-composed-v1 parse syntax-off 16 KiB (bytes: 16654, corpus: m5-composed-v1, profile: gfm-all-m5, syntax: off)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      4223 |      4223 |      4223 |      4223 |      4223 |      4223 |      4223 |      1429 |
| Malloc (total) (K) *        |        17 |        17 |        17 |        17 |        17 |        17 |        17 |      1429 |
| Time (wall clock) (μs) *    |      3381 |      3416 |      3453 |      3533 |      3619 |      3885 |     19500 |      1429 |

### GMSetzer m5-composed-v1 parse syntax-off 256 KiB (bytes: 262177, corpus: m5-composed-v1, profile: gfm-all-m5, syntax: off)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |        65 |        65 |        65 |        65 |        65 |        65 |        65 |        92 |
| Malloc (total) (K) *        |       260 |       260 |       260 |       260 |       260 |       260 |       260 |        92 |
| Time (wall clock) (μs) *    |     52534 |     53707 |     54657 |     55640 |     56328 |     58925 |     58925 |        92 |

### GMSetzer m5-composed-v1 parse syntax-off 64 KiB (bytes: 65665, corpus: m5-composed-v1, profile: gfm-all-m5, syntax: off)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |        16 |        16 |        16 |        16 |        16 |        16 |        16 |       369 |
| Malloc (total) (K) *        |        66 |        66 |        66 |        66 |        66 |        66 |        66 |       369 |
| Time (wall clock) (μs) *    |     13137 |     13328 |     13509 |     13722 |     13926 |     14606 |     17048 |       369 |

### GMSetzer m5-composed-v1 parse syntax-on 16 KiB (bytes: 16654, corpus: m5-composed-v1, profile: gfm-all-m5, syntax: on)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      6395 |      6395 |      6395 |      6395 |      6395 |      6395 |      6395 |       819 |
| Malloc (total) (K) *        |        17 |        17 |        17 |        17 |        17 |        17 |        17 |       819 |
| Time (wall clock) (μs) *    |      5821 |      5972 |      6054 |      6160 |      6271 |      6840 |     20081 |       819 |

### GMSetzer m5-composed-v1 parse syntax-on 256 KiB (bytes: 262177, corpus: m5-composed-v1, profile: gfm-all-m5, syntax: on)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |       101 |       101 |       101 |       101 |       101 |       101 |       101 |        53 |
| Malloc (total) (K) *        |       262 |       262 |       262 |       262 |       262 |       262 |       262 |        53 |
| Time (wall clock) (μs) *    |     92021 |     93389 |     94110 |     94700 |     96338 |    126442 |    126442 |        53 |

### GMSetzer m5-composed-v1 parse syntax-on 64 KiB (bytes: 65665, corpus: m5-composed-v1, profile: gfm-all-m5, syntax: on)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |        25 |        25 |        25 |        25 |        25 |        25 |        25 |       216 |
| Malloc (total) (K) *        |        66 |        66 |        66 |        66 |        66 |        66 |        66 |       216 |
| Time (wall clock) (μs) *    |     22556 |     23036 |     23216 |     23396 |     23577 |     24216 |     24661 |       216 |

### GMSetzer m5-composed-v1 parse-render syntax-off 16 KiB (bytes: 16654, corpus: m5-composed-v1, profile: gfm-all-m5, syntax: off)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      5169 |      5169 |      5169 |      5169 |      5169 |      5169 |      5169 |       849 |
| Malloc (total) (K) *        |        27 |        27 |        27 |        27 |        27 |        27 |        27 |       849 |
| Time (wall clock) (μs) *    |      4887 |      5075 |      5353 |      5767 |      7348 |     10961 |    102583 |       849 |

### GMSetzer m5-composed-v1 parse-render syntax-off 256 KiB (bytes: 262177, corpus: m5-composed-v1, profile: gfm-all-m5, syntax: off)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |        80 |        80 |        80 |        80 |        80 |        80 |        80 |        60 |
| Malloc (total) (K) *        |       422 |       422 |       422 |       422 |       422 |       422 |       422 |        60 |
| Time (wall clock) (μs) *    |     79252 |     80216 |     80806 |     83231 |     93389 |    127143 |    127143 |        60 |

### GMSetzer m5-composed-v1 parse-render syntax-off 64 KiB (bytes: 65665, corpus: m5-composed-v1, profile: gfm-all-m5, syntax: off)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |        20 |        20 |        20 |        20 |        20 |        20 |        20 |       246 |
| Malloc (total) (K) *        |       106 |       106 |       106 |       106 |       106 |       106 |       106 |       246 |
| Time (wall clock) (μs) *    |     19608 |     20038 |     20283 |     20562 |     20955 |     22577 |     22667 |       246 |

### GMSetzer m5-composed-v1 parse-render syntax-on 16 KiB (bytes: 16654, corpus: m5-composed-v1, profile: gfm-all-m5, syntax: on)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      7341 |      7341 |      7341 |      7341 |      7341 |      7341 |      7341 |       641 |
| Malloc (total) (K) *        |        28 |        28 |        28 |        28 |        28 |        28 |        28 |       641 |
| Time (wall clock) (μs) *    |      7515 |      7688 |      7778 |      7885 |      8008 |      8233 |      9711 |       641 |

### GMSetzer m5-composed-v1 parse-render syntax-on 256 KiB (bytes: 262177, corpus: m5-composed-v1, profile: gfm-all-m5, syntax: on)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |       116 |       116 |       116 |       116 |       116 |       116 |       116 |        41 |
| Malloc (total) (K) *        |       424 |       424 |       424 |       424 |       424 |       424 |       424 |        41 |
| Time (wall clock) (μs) *    |    120284 |    121504 |    122421 |    123208 |    123666 |    125630 |    125630 |        41 |

### GMSetzer m5-composed-v1 parse-render syntax-on 64 KiB (bytes: 65665, corpus: m5-composed-v1, profile: gfm-all-m5, syntax: on)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |        29 |        29 |        29 |        29 |        29 |        29 |        29 |       156 |
| Malloc (total) (K) *        |       107 |       107 |       107 |       107 |       107 |       107 |       107 |       156 |
| Time (wall clock) (μs) *    |     28967 |     29802 |     30835 |     31965 |     34636 |     59539 |     80447 |       156 |

### GMSetzer open-brackets-v1 parse syntax-off 16 KiB (bytes: 16384, corpus: open-brackets-v1, profile: commonmark, syntax: off)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      6984 |      6984 |      6984 |      6984 |      6984 |      6984 |      6984 |      5016 |
| Malloc (total) *            |        43 |        43 |        43 |        43 |        43 |        43 |        43 |      5016 |
| Time (wall clock) (μs) *    |       927 |       948 |       969 |      1004 |      1048 |      1223 |     12856 |      5016 |

### GMSetzer open-brackets-v1 parse syntax-off 256 KiB (bytes: 262144, corpus: open-brackets-v1, profile: commonmark, syntax: off)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |       120 |       120 |       120 |       120 |       120 |       120 |       120 |       240 |
| Malloc (total) *            |        51 |        51 |        51 |        51 |        51 |        51 |        51 |       240 |
| Time (wall clock) (μs) *    |     16001 |     17138 |     18776 |     22135 |     26935 |     56230 |     85089 |       240 |

### GMSetzer open-brackets-v1 parse syntax-off 64 KiB (bytes: 65536, corpus: open-brackets-v1, profile: commonmark, syntax: off)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |        30 |        30 |        30 |        30 |        30 |        30 |        30 |      1217 |
| Malloc (total) *            |        47 |        47 |        47 |        47 |        47 |        47 |        47 |      1217 |
| Time (wall clock) (μs) *    |      3826 |      3951 |      4049 |      4198 |      4411 |      4940 |      5669 |      1217 |

### GMSetzer open-brackets-v1 parse syntax-on 16 KiB (bytes: 16384, corpus: open-brackets-v1, profile: commonmark, syntax: on)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      6984 |      6984 |      6984 |      6984 |      6984 |      6984 |      6984 |      4299 |
| Malloc (total) *            |        43 |        43 |        43 |        43 |        43 |        43 |        43 |      4299 |
| Time (wall clock) (μs) *    |      1053 |      1093 |      1134 |      1164 |      1217 |      1823 |     11438 |      4299 |

### GMSetzer open-brackets-v1 parse syntax-on 256 KiB (bytes: 262144, corpus: open-brackets-v1, profile: commonmark, syntax: on)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |       120 |       120 |       120 |       120 |       120 |       120 |       120 |       262 |
| Malloc (total) *            |        51 |        51 |        51 |        51 |        51 |        51 |        51 |       262 |
| Time (wall clock) (μs) *    |     17752 |     18514 |     19055 |     19579 |     20054 |     22446 |     24400 |       262 |

### GMSetzer open-brackets-v1 parse syntax-on 64 KiB (bytes: 65536, corpus: open-brackets-v1, profile: commonmark, syntax: on)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |        30 |        30 |        30 |        30 |        30 |        30 |        30 |      1060 |
| Malloc (total) *            |        47 |        47 |        47 |        47 |        47 |        47 |        47 |      1060 |
| Time (wall clock) (μs) *    |      4339 |      4477 |      4555 |      4669 |      4866 |      5734 |     58361 |      1060 |

### GMSetzer quote-overflow-v1 parse syntax-off 16 KiB (bytes: 16576, corpus: quote-overflow-v1, profile: commonmark, syntax: off)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      4190 |      4190 |      4190 |      4190 |      4190 |      4190 |      4190 |     10000 |
| Malloc (total) *            |        84 |        84 |        84 |        84 |        84 |        84 |        84 |     10000 |
| Time (wall clock) (μs) *    |       449 |       453 |       462 |       480 |       503 |       556 |      1061 |     10000 |

### GMSetzer quote-overflow-v1 parse syntax-off 256 KiB (bytes: 262626, corpus: quote-overflow-v1, profile: commonmark, syntax: off)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |        58 |        58 |        58 |        58 |        58 |        58 |        58 |       661 |
| Malloc (total) *            |       571 |       571 |       571 |       571 |       571 |       571 |       571 |       661 |
| Time (wall clock) (μs) *    |      7140 |      7340 |      7434 |      7561 |      7733 |      8684 |     47005 |       661 |

### GMSetzer quote-overflow-v1 parse syntax-off 64 KiB (bytes: 65786, corpus: quote-overflow-v1, profile: commonmark, syntax: off)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |        15 |        15 |        15 |        15 |        15 |        15 |        15 |      2713 |
| Malloc (total) *            |       185 |       185 |       185 |       185 |       185 |       185 |       185 |      2713 |
| Time (wall clock) (μs) *    |      1767 |      1793 |      1824 |      1859 |      1893 |      2015 |      9716 |      2713 |

### GMSetzer quote-overflow-v1 parse syntax-on 16 KiB (bytes: 16576, corpus: quote-overflow-v1, profile: commonmark, syntax: on)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      4975 |      4975 |      4975 |      4975 |      4975 |      4975 |      4975 |      9152 |
| Malloc (total) *            |       110 |       110 |       110 |       110 |       110 |       110 |       110 |      9152 |
| Time (wall clock) (μs) *    |       527 |       530 |       539 |       553 |       574 |       628 |      1041 |      9152 |

### GMSetzer quote-overflow-v1 parse syntax-on 256 KiB (bytes: 262626, corpus: quote-overflow-v1, profile: commonmark, syntax: on)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |        70 |        70 |        70 |        70 |        70 |        70 |        70 |       555 |
| Malloc (total) *            |       605 |       605 |       605 |       605 |       605 |       605 |       605 |       555 |
| Time (wall clock) (μs) *    |      8504 |      8765 |      8937 |      9175 |      9462 |     10445 |     11823 |       555 |

### GMSetzer quote-overflow-v1 parse syntax-on 64 KiB (bytes: 65786, corpus: quote-overflow-v1, profile: commonmark, syntax: on)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |        18 |        18 |        18 |        18 |        18 |        18 |        18 |      2181 |
| Malloc (total) *            |       215 |       215 |       215 |       215 |       215 |       215 |       215 |      2181 |
| Time (wall clock) (μs) *    |      2112 |      2193 |      2226 |      2284 |      2451 |      3590 |      5162 |      2181 |

### GMSetzer unmatched-backticks-v1 parse syntax-off 16 KiB (bytes: 16476, corpus: unmatched-backticks-v1, profile: commonmark, syntax: off)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |       631 |       631 |       631 |       631 |       631 |       631 |       631 |     10000 |
| Malloc (total) *            |       387 |       387 |       387 |       387 |       387 |       387 |       387 |     10000 |
| Time (wall clock) (μs) *    |       102 |       103 |       105 |       109 |       112 |       135 |       266 |     10000 |

### GMSetzer unmatched-backticks-v1 parse syntax-off 256 KiB (bytes: 262455, corpus: unmatched-backticks-v1, profile: commonmark, syntax: off)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      1624 |      1624 |      1624 |      1624 |      1624 |      1624 |      1624 |      6836 |
| Malloc (total) *            |      1477 |      1477 |      1477 |      1477 |      1477 |      1477 |      1477 |      6836 |
| Time (wall clock) (μs) *    |       689 |       704 |       719 |       741 |       765 |       848 |     10654 |      6836 |

### GMSetzer unmatched-backticks-v1 parse syntax-off 64 KiB (bytes: 65708, corpus: unmatched-backticks-v1, profile: commonmark, syntax: off)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |       864 |       864 |       864 |       864 |       864 |       864 |       864 |     10000 |
| Malloc (total) *            |       751 |       751 |       751 |       751 |       751 |       751 |       751 |     10000 |
| Time (wall clock) (μs) *    |       252 |       255 |       260 |       272 |       285 |       338 |       856 |     10000 |

### GMSetzer unmatched-backticks-v1 parse syntax-on 16 KiB (bytes: 16476, corpus: unmatched-backticks-v1, profile: commonmark, syntax: on)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |       631 |       631 |       631 |       631 |       631 |       631 |       631 |     10000 |
| Malloc (total) *            |       387 |       387 |       387 |       387 |       387 |       387 |       387 |     10000 |
| Time (wall clock) (μs) *    |       104 |       105 |       106 |       112 |       120 |       203 |     23167 |     10000 |

### GMSetzer unmatched-backticks-v1 parse syntax-on 256 KiB (bytes: 262455, corpus: unmatched-backticks-v1, profile: commonmark, syntax: on)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      1624 |      1624 |      1624 |      1624 |      1624 |      1624 |      1624 |      6662 |
| Malloc (total) *            |      1477 |      1477 |      1477 |      1477 |      1477 |      1477 |      1477 |      6662 |
| Time (wall clock) (μs) *    |       700 |       729 |       745 |       757 |       778 |       863 |      1545 |      6662 |

### GMSetzer unmatched-backticks-v1 parse syntax-on 64 KiB (bytes: 65708, corpus: unmatched-backticks-v1, profile: commonmark, syntax: on)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |       864 |       864 |       864 |       864 |       864 |       864 |       864 |     10000 |
| Malloc (total) *            |       751 |       751 |       751 |       751 |       751 |       751 |       751 |     10000 |
| Time (wall clock) (μs) *    |       257 |       260 |       266 |       276 |       287 |       324 |       482 |     10000 |

### cmark-gfm (C) invalid-utf8-v1 parse 16 KiB (bytes: 16388, corpus: invalid-utf8-v1, profile: commonmark, syntax: off)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |       574 |       574 |       574 |       574 |       574 |       574 |       574 |     10000 |
| Malloc (total) *            |      2757 |      2757 |      2757 |      2757 |      2757 |      2757 |      2757 |     10000 |
| Time (wall clock) (μs) *    |       222 |       235 |       240 |       251 |       259 |       291 |       510 |     10000 |

### cmark-gfm (C) invalid-utf8-v1 parse 256 KiB (bytes: 262148, corpus: invalid-utf8-v1, profile: commonmark, syntax: off)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      9249 |      9249 |      9249 |      9249 |      9249 |      9249 |      9249 |      1198 |
| Malloc (total) (K) *        |        44 |        44 |        44 |        44 |        44 |        44 |        44 |      1198 |
| Time (wall clock) (μs) *    |      3690 |      3899 |      4028 |      4172 |      4506 |      6689 |     18286 |      1198 |

### cmark-gfm (C) invalid-utf8-v1 parse 64 KiB (bytes: 65540, corpus: invalid-utf8-v1, profile: commonmark, syntax: off)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      2250 |      2250 |      2250 |      2250 |      2250 |      2250 |      2250 |      4072 |
| Malloc (total) (K) *        |        11 |        11 |        11 |        11 |        11 |        11 |        11 |      4072 |
| Time (wall clock) (μs) *    |       922 |       968 |       998 |      1098 |      1766 |      3631 |     36713 |      4072 |

### cmark-gfm (C) long-emphasis-v1 parse 16 KiB (bytes: 16390, corpus: long-emphasis-v1, profile: commonmark, syntax: off)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |       806 |       806 |       806 |       806 |       806 |       806 |       806 |     10000 |
| Malloc (total) *            |      4119 |      4119 |      4119 |      4119 |      4119 |      4119 |      4119 |     10000 |
| Time (wall clock) (μs) *    |       263 |       292 |       301 |       312 |       322 |       394 |      1458 |     10000 |

### cmark-gfm (C) long-emphasis-v1 parse 256 KiB (bytes: 262150, corpus: long-emphasis-v1, profile: commonmark, syntax: off)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |        13 |        13 |        13 |        13 |        13 |        13 |        13 |       973 |
| Malloc (total) (K) *        |        66 |        66 |        66 |        66 |        66 |        66 |        66 |       973 |
| Time (wall clock) (μs) *    |      4774 |      4915 |      4997 |      5136 |      5444 |      7004 |     27625 |       973 |

### cmark-gfm (C) long-emphasis-v1 parse 64 KiB (bytes: 65542, corpus: long-emphasis-v1, profile: commonmark, syntax: off)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      3214 |      3214 |      3214 |      3214 |      3214 |      3214 |      3214 |      2677 |
| Malloc (total) (K) *        |        16 |        16 |        16 |        16 |        16 |        16 |        16 |      2677 |
| Time (wall clock) (μs) *    |      1166 |      1224 |      1256 |      1360 |      3187 |      9593 |     59656 |      2677 |

### cmark-gfm (C) open-brackets-v1 parse 16 KiB (bytes: 16384, corpus: open-brackets-v1, profile: commonmark, syntax: off)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      3672 |      3672 |      3672 |      3672 |      3672 |      3672 |      3672 |      2794 |
| Malloc (total) (K) *        |        33 |        33 |        33 |        33 |        33 |        33 |        33 |      2794 |
| Time (wall clock) (μs) *    |      1393 |      1426 |      1458 |      1523 |      2591 |      6365 |     22606 |      2794 |

### cmark-gfm (C) open-brackets-v1 parse 256 KiB (bytes: 262144, corpus: open-brackets-v1, profile: commonmark, syntax: off)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |        59 |        59 |        59 |        59 |        59 |        59 |        59 |       212 |
| Malloc (total) (K) *        |       524 |       524 |       524 |       524 |       524 |       524 |       524 |       212 |
| Time (wall clock) (μs) *    |     22042 |     22643 |     23118 |     23577 |     24396 |     36110 |     41008 |       212 |

### cmark-gfm (C) open-brackets-v1 parse 64 KiB (bytes: 65536, corpus: open-brackets-v1, profile: commonmark, syntax: off)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |        15 |        15 |        15 |        15 |        15 |        15 |        15 |       522 |
| Malloc (total) (K) *        |       131 |       131 |       131 |       131 |       131 |       131 |       131 |       522 |
| Time (wall clock) (μs) *    |      5530 |      6255 |      7217 |     10535 |     15311 |     27476 |    145353 |       522 |

### cmark-gfm (C) quote-overflow-v1 parse 16 KiB (bytes: 16576, corpus: quote-overflow-v1, profile: commonmark, syntax: off)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      1982 |      1982 |      1982 |      1982 |      1982 |      1982 |      1982 |      5697 |
| Malloc (total) (K) *        |        16 |        16 |        16 |        16 |        16 |        16 |        16 |      5697 |
| Time (wall clock) (μs) *    |       821 |       849 |       864 |       895 |       925 |      1010 |      3360 |      5697 |

### cmark-gfm (C) quote-overflow-v1 parse 256 KiB (bytes: 262626, corpus: quote-overflow-v1, profile: commonmark, syntax: off)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |        31 |        31 |        31 |        31 |        31 |        31 |        31 |       275 |
| Malloc (total) (K) *        |       261 |       261 |       261 |       261 |       261 |       261 |       261 |       275 |
| Time (wall clock) (μs) *    |     16989 |     17777 |     18055 |     18317 |     18629 |     20464 |     46131 |       275 |

### cmark-gfm (C) quote-overflow-v1 parse 64 KiB (bytes: 65786, corpus: quote-overflow-v1, profile: commonmark, syntax: off)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      7859 |      7859 |      7859 |      7859 |      7859 |      7859 |      7859 |      1350 |
| Malloc (total) (K) *        |        65 |        65 |        65 |        65 |        65 |        65 |        65 |      1350 |
| Time (wall clock) (μs) *    |      3334 |      3453 |      3531 |      3666 |      3791 |      7078 |     38308 |      1350 |

### cmark-gfm (C) unmatched-backticks-v1 parse 16 KiB (bytes: 16476, corpus: unmatched-backticks-v1, profile: commonmark, syntax: off)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |       197 |       197 |       197 |       197 |       197 |       197 |       197 |     10000 |
| Malloc (total) *            |       393 |       393 |       393 |       393 |       393 |       393 |       393 |     10000 |
| Time (wall clock) (μs) *    |        45 |        47 |        47 |        49 |        96 |       129 |      3531 |     10000 |

### cmark-gfm (C) unmatched-backticks-v1 parse 256 KiB (bytes: 262455, corpus: unmatched-backticks-v1, profile: commonmark, syntax: off)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      2420 |      2420 |      2420 |      2420 |      2420 |      2420 |      2420 |     10000 |
| Malloc (total) *            |      1486 |      1486 |      1486 |      1486 |      1486 |      1486 |      1486 |     10000 |
| Time (wall clock) (μs) *    |       422 |       428 |       443 |       462 |       485 |       548 |      4286 |     10000 |

### cmark-gfm (C) unmatched-backticks-v1 parse 64 KiB (bytes: 65708, corpus: unmatched-backticks-v1, profile: commonmark, syntax: off)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |       715 |       715 |       715 |       715 |       715 |       715 |       715 |     10000 |
| Malloc (total) *            |       759 |       759 |       759 |       759 |       759 |       759 |       759 |     10000 |
| Time (wall clock) (μs) *    |       129 |       129 |       130 |       133 |       142 |       163 |       266 |     10000 |

