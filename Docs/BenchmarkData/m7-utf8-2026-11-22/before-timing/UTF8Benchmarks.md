
## Baseline 'Current_run'

```
Host 'BlackBook.local' with 8 'arm64' processors with 16 GB memory, running:
Darwin Kernel Version 27.0.0: Tue Aug 11 21:02:16 PDT 2026; root:xnu-13432.1.9~1/RELEASE_ARM64_T8112
```
## UTF8Benchmarks

### GMSetzer invalid-compatible-v1 parse syntax-off 16 KiB (bytes: 16385, corpus: invalid-compatible-v1, profile: commonmark, syntax: off, validation: swift-repair)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      3324 |      3324 |      3324 |      3324 |      3324 |      3324 |      3324 |      6294 |
| Malloc (total) *            |      3318 |      3318 |      3318 |      3318 |      3318 |      3318 |      3318 |      6294 |
| Time (wall clock) (μs) *    |       757 |       786 |       789 |       798 |       817 |       869 |      1932 |      6294 |

### GMSetzer invalid-compatible-v1 parse syntax-off 256 KiB (bytes: 262145, corpus: invalid-compatible-v1, profile: commonmark, syntax: off, validation: swift-repair)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |        52 |        52 |        52 |        52 |        52 |        52 |        52 |       372 |
| Malloc (total) (K) *        |        52 |        52 |        52 |        52 |        52 |        52 |        52 |       372 |
| Time (wall clock) (μs) *    |     12338 |     12706 |     12812 |     13124 |     13763 |     33817 |     49150 |       372 |

### GMSetzer invalid-compatible-v1 parse syntax-off 64 KiB (bytes: 65545, corpus: invalid-compatible-v1, profile: commonmark, syntax: off, validation: swift-repair)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |        13 |        13 |        13 |        13 |        13 |        13 |        13 |      1528 |
| Malloc (total) (K) *        |        13 |        13 |        13 |        13 |        13 |        13 |        13 |      1528 |
| Time (wall clock) (μs) *    |      3091 |      3183 |      3203 |      3236 |      3326 |      4334 |     35426 |      1528 |

### GMSetzer invalid-compatible-v1 parse syntax-on 16 KiB (bytes: 16385, corpus: invalid-compatible-v1, profile: commonmark, syntax: on, validation: swift-repair)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      3324 |      3324 |      3324 |      3324 |      3324 |      3324 |      3324 |      6274 |
| Malloc (total) *            |      3318 |      3318 |      3318 |      3318 |      3318 |      3318 |      3318 |      6274 |
| Time (wall clock) (μs) *    |       759 |       788 |       791 |       801 |       820 |       866 |       981 |      6274 |

### GMSetzer invalid-compatible-v1 parse syntax-on 256 KiB (bytes: 262145, corpus: invalid-compatible-v1, profile: commonmark, syntax: on, validation: swift-repair)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |        52 |        52 |        52 |        52 |        52 |        52 |        52 |       391 |
| Malloc (total) (K) *        |        52 |        52 |        52 |        52 |        52 |        52 |        52 |       391 |
| Time (wall clock) (μs) *    |     12400 |     12657 |     12755 |     12845 |     12993 |     13943 |     14294 |       391 |

### GMSetzer invalid-compatible-v1 parse syntax-on 64 KiB (bytes: 65545, corpus: invalid-compatible-v1, profile: commonmark, syntax: on, validation: swift-repair)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |        13 |        13 |        13 |        13 |        13 |        13 |        13 |      1479 |
| Malloc (total) (K) *        |        13 |        13 |        13 |        13 |        13 |        13 |        13 |      1479 |
| Time (wall clock) (μs) *    |      3050 |      3174 |      3234 |      3344 |      3484 |      6578 |     35057 |      1479 |

### GMSetzer invalid-utf8-v1 parse syntax-off 16 KiB (bytes: 16388, corpus: invalid-utf8-v1, profile: commonmark, syntax: off, validation: swift-repair)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      2604 |      2604 |      2604 |      2604 |      2604 |      2604 |      2604 |      6299 |
| Malloc (total) *            |      2769 |      2769 |      2769 |      2769 |      2769 |      2769 |      2769 |      6299 |
| Time (wall clock) (μs) *    |       750 |       758 |       769 |       796 |       829 |      1021 |     27450 |      6299 |

### GMSetzer invalid-utf8-v1 parse syntax-off 256 KiB (bytes: 262148, corpus: invalid-utf8-v1, profile: commonmark, syntax: off, validation: swift-repair)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |        42 |        42 |        42 |        42 |        42 |        42 |        42 |       389 |
| Malloc (total) (K) *        |        44 |        44 |        44 |        44 |        44 |        44 |        44 |       389 |
| Time (wall clock) (μs) *    |     11881 |     12091 |     12394 |     12845 |     13246 |     18334 |     67785 |       389 |

### GMSetzer invalid-utf8-v1 parse syntax-off 64 KiB (bytes: 65540, corpus: invalid-utf8-v1, profile: commonmark, syntax: off, validation: swift-repair)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |        11 |        11 |        11 |        11 |        11 |        11 |        11 |      1633 |
| Malloc (total) (K) *        |        11 |        11 |        11 |        11 |        11 |        11 |        11 |      1633 |
| Time (wall clock) (μs) *    |      2980 |      3015 |      3047 |      3072 |      3101 |      3314 |     13714 |      1633 |

### GMSetzer invalid-utf8-v1 parse syntax-on 16 KiB (bytes: 16388, corpus: invalid-utf8-v1, profile: commonmark, syntax: on, validation: swift-repair)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      2604 |      2604 |      2604 |      2604 |      2604 |      2604 |      2604 |      6423 |
| Malloc (total) *            |      2769 |      2769 |      2769 |      2769 |      2769 |      2769 |      2769 |      6423 |
| Time (wall clock) (μs) *    |       735 |       751 |       759 |       774 |       803 |       982 |     10920 |      6423 |

### GMSetzer invalid-utf8-v1 parse syntax-on 256 KiB (bytes: 262148, corpus: invalid-utf8-v1, profile: commonmark, syntax: on, validation: swift-repair)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |        42 |        42 |        42 |        42 |        42 |        42 |        42 |       415 |
| Malloc (total) (K) *        |        44 |        44 |        44 |        44 |        44 |        44 |        44 |       415 |
| Time (wall clock) (μs) *    |     11846 |     11993 |     12050 |     12108 |     12182 |     12730 |     13875 |       415 |

### GMSetzer invalid-utf8-v1 parse syntax-on 64 KiB (bytes: 65540, corpus: invalid-utf8-v1, profile: commonmark, syntax: on, validation: swift-repair)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |        11 |        11 |        11 |        11 |        11 |        11 |        11 |      1647 |
| Malloc (total) (K) *        |        11 |        11 |        11 |        11 |        11 |        11 |        11 |      1647 |
| Time (wall clock) (μs) *    |      2977 |      2998 |      3015 |      3054 |      3107 |      3260 |      3886 |      1647 |

### GMSetzer valid-multibyte-v1 parse syntax-off 16 KiB (bytes: 16385, corpus: valid-multibyte-v1, profile: commonmark, syntax: off, validation: swift-repair)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |       932 |       932 |       932 |       932 |       932 |       932 |       932 |     10000 |
| Malloc (total) *            |       506 |       506 |       506 |       506 |       506 |       506 |       506 |     10000 |
| Time (wall clock) (μs) *    |       148 |       149 |       149 |       150 |       151 |       179 |       231 |     10000 |

### GMSetzer valid-multibyte-v1 parse syntax-off 256 KiB (bytes: 262155, corpus: valid-multibyte-v1, profile: commonmark, syntax: off, validation: swift-repair)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |        15 |        15 |        15 |        15 |        15 |        15 |        15 |      2131 |
| Malloc (total) *            |      7536 |      7536 |      7536 |      7536 |      7536 |      7536 |      7536 |      2131 |
| Time (wall clock) (μs) *    |      2303 |      2320 |      2329 |      2353 |      2390 |      2556 |      3435 |      2131 |

### GMSetzer valid-multibyte-v1 parse syntax-off 64 KiB (bytes: 65560, corpus: valid-multibyte-v1, profile: commonmark, syntax: off, validation: swift-repair)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      3656 |      3656 |      3656 |      3656 |      3656 |      3656 |      3656 |      8440 |
| Malloc (total) *            |      1915 |      1915 |      1915 |      1915 |      1915 |      1915 |      1915 |      8440 |
| Time (wall clock) (μs) *    |       578 |       585 |       586 |       589 |       606 |       666 |      3966 |      8440 |

### GMSetzer valid-multibyte-v1 parse syntax-on 16 KiB (bytes: 16385, corpus: valid-multibyte-v1, profile: commonmark, syntax: on, validation: swift-repair)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |       932 |       932 |       932 |       932 |       932 |       932 |       932 |     10000 |
| Malloc (total) *            |       506 |       506 |       506 |       506 |       506 |       506 |       506 |     10000 |
| Time (wall clock) (μs) *    |       147 |       149 |       149 |       150 |       156 |       181 |       304 |     10000 |

### GMSetzer valid-multibyte-v1 parse syntax-on 256 KiB (bytes: 262155, corpus: valid-multibyte-v1, profile: commonmark, syntax: on, validation: swift-repair)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |        15 |        15 |        15 |        15 |        15 |        15 |        15 |      2143 |
| Malloc (total) *            |      7536 |      7536 |      7536 |      7536 |      7536 |      7536 |      7536 |      2143 |
| Time (wall clock) (μs) *    |      2296 |      2312 |      2320 |      2343 |      2374 |      2482 |      2650 |      2143 |

### GMSetzer valid-multibyte-v1 parse syntax-on 64 KiB (bytes: 65560, corpus: valid-multibyte-v1, profile: commonmark, syntax: on, validation: swift-repair)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      3656 |      3656 |      3656 |      3656 |      3656 |      3656 |      3656 |      8173 |
| Malloc (total) *            |      1915 |      1915 |      1915 |      1915 |      1915 |      1915 |      1915 |      8173 |
| Time (wall clock) (μs) *    |       578 |       586 |       592 |       618 |       649 |       771 |      3581 |      8173 |

### cmark-gfm (C) invalid-compatible-v1 parse validation-off 16 KiB (bytes: 16385, corpus: invalid-compatible-v1, profile: commonmark, syntax: off, validation: off)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |       676 |       676 |       676 |       676 |       676 |       676 |       676 |     10000 |
| Malloc (total) *            |      3303 |      3303 |      3303 |      3303 |      3303 |      3303 |      3303 |     10000 |
| Time (wall clock) (μs) *    |       253 |       263 |       266 |       277 |       292 |       344 |     16524 |     10000 |

### cmark-gfm (C) invalid-compatible-v1 parse validation-off 256 KiB (bytes: 262145, corpus: invalid-compatible-v1, profile: commonmark, syntax: off, validation: off)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |        11 |        11 |        11 |        11 |        11 |        11 |        11 |      1135 |
| Malloc (total) (K) *        |        52 |        52 |        52 |        52 |        52 |        52 |        52 |      1135 |
| Time (wall clock) (μs) *    |      4287 |      4358 |      4383 |      4420 |      4493 |      4776 |      6581 |      1135 |

### cmark-gfm (C) invalid-compatible-v1 parse validation-off 64 KiB (bytes: 65545, corpus: invalid-compatible-v1, profile: commonmark, syntax: off, validation: off)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      2657 |      2657 |      2657 |      2657 |      2657 |      2657 |      2657 |      4411 |
| Malloc (total) (K) *        |        13 |        13 |        13 |        13 |        13 |        13 |        13 |      4411 |
| Time (wall clock) (μs) *    |      1029 |      1060 |      1068 |      1097 |      1146 |      1779 |     26088 |      4411 |

### cmark-gfm (C) invalid-compatible-v1 parse validation-on 16 KiB (bytes: 16385, corpus: invalid-compatible-v1, profile: commonmark, syntax: off, validation: on)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |       712 |       712 |       712 |       712 |       712 |       712 |       712 |     10000 |
| Malloc (total) *            |      3304 |      3304 |      3304 |      3304 |      3304 |      3304 |      3304 |     10000 |
| Time (wall clock) (μs) *    |       297 |       307 |       308 |       311 |       326 |       380 |     26591 |     10000 |

### cmark-gfm (C) invalid-compatible-v1 parse validation-on 256 KiB (bytes: 262145, corpus: invalid-compatible-v1, profile: commonmark, syntax: off, validation: on)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |        11 |        11 |        11 |        11 |        11 |        11 |        11 |       906 |
| Malloc (total) (K) *        |        52 |        52 |        52 |        52 |        52 |        52 |        52 |       906 |
| Time (wall clock) (μs) *    |      4957 |      5116 |      5259 |      5607 |      6058 |      9249 |     34329 |       906 |

### cmark-gfm (C) invalid-compatible-v1 parse validation-on 64 KiB (bytes: 65545, corpus: invalid-compatible-v1, profile: commonmark, syntax: off, validation: on)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      2778 |      2778 |      2778 |      2778 |      2778 |      2778 |      2778 |      4005 |
| Malloc (total) (K) *        |        13 |        13 |        13 |        13 |        13 |        13 |        13 |      4005 |
| Time (wall clock) (μs) *    |      1200 |      1225 |      1232 |      1262 |      1299 |      1381 |      1644 |      4005 |

### cmark-gfm (C) invalid-utf8-v1 parse validation-off 16 KiB (bytes: 16388, corpus: invalid-utf8-v1, profile: commonmark, syntax: off, validation: off)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |       574 |       574 |       574 |       574 |       574 |       574 |       574 |     10000 |
| Malloc (total) *            |      2757 |      2757 |      2757 |      2757 |      2757 |      2757 |      2757 |     10000 |
| Time (wall clock) (μs) *    |       217 |       226 |       226 |       227 |       232 |       264 |       331 |     10000 |

### cmark-gfm (C) invalid-utf8-v1 parse validation-off 256 KiB (bytes: 262148, corpus: invalid-utf8-v1, profile: commonmark, syntax: off, validation: off)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      9249 |      9249 |      9249 |      9249 |      9249 |      9249 |      9249 |      1335 |
| Malloc (total) (K) *        |        44 |        44 |        44 |        44 |        44 |        44 |        44 |      1335 |
| Time (wall clock) (μs) *    |      3590 |      3639 |      3670 |      3717 |      3815 |      5132 |     18155 |      1335 |

### cmark-gfm (C) invalid-utf8-v1 parse validation-off 64 KiB (bytes: 65540, corpus: invalid-utf8-v1, profile: commonmark, syntax: off, validation: off)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      2250 |      2250 |      2250 |      2250 |      2250 |      2250 |      2250 |      5501 |
| Malloc (total) (K) *        |        11 |        11 |        11 |        11 |        11 |        11 |        11 |      5501 |
| Time (wall clock) (μs) *    |       878 |       899 |       902 |       908 |       930 |       995 |      1307 |      5501 |

### cmark-gfm (C) invalid-utf8-v1 parse validation-on 16 KiB (bytes: 16388, corpus: invalid-utf8-v1, profile: commonmark, syntax: off, validation: on)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |       607 |       607 |       607 |       607 |       607 |       607 |       607 |     10000 |
| Malloc (total) *            |      2758 |      2758 |      2758 |      2758 |      2758 |      2758 |      2758 |     10000 |
| Time (wall clock) (μs) *    |       262 |       267 |       268 |       269 |       276 |       311 |       362 |     10000 |

### cmark-gfm (C) invalid-utf8-v1 parse validation-on 256 KiB (bytes: 262148, corpus: invalid-utf8-v1, profile: commonmark, syntax: off, validation: on)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      9804 |      9804 |      9804 |      9804 |      9804 |      9804 |      9804 |      1144 |
| Malloc (total) (K) *        |        44 |        44 |        44 |        44 |        44 |        44 |        44 |      1144 |
| Time (wall clock) (μs) *    |      4275 |      4305 |      4329 |      4379 |      4485 |      4866 |      9299 |      1144 |

### cmark-gfm (C) invalid-utf8-v1 parse validation-on 64 KiB (bytes: 65540, corpus: invalid-utf8-v1, profile: commonmark, syntax: off, validation: on)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      2359 |      2359 |      2359 |      2359 |      2359 |      2359 |      2359 |      4643 |
| Malloc (total) (K) *        |        11 |        11 |        11 |        11 |        11 |        11 |        11 |      4643 |
| Time (wall clock) (μs) *    |      1036 |      1065 |      1069 |      1078 |      1101 |      1174 |      1634 |      4643 |

### cmark-gfm (C) valid-multibyte-v1 parse validation-off 16 KiB (bytes: 16385, corpus: valid-multibyte-v1, profile: commonmark, syntax: off, validation: off)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |       221 |       221 |       221 |       221 |       221 |       221 |       221 |     10000 |
| Malloc (total) *            |       960 |       960 |       960 |       960 |       960 |       960 |       960 |     10000 |
| Time (wall clock) (μs) *    |        76 |        79 |        79 |        80 |        80 |        98 |       154 |     10000 |

### cmark-gfm (C) valid-multibyte-v1 parse validation-off 256 KiB (bytes: 262155, corpus: valid-multibyte-v1, profile: commonmark, syntax: off, validation: off)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      3582 |      3582 |      3582 |      3582 |      3582 |      3582 |      3582 |      3901 |
| Malloc (total) (K) *        |        15 |        15 |        15 |        15 |        15 |        15 |        15 |      3901 |
| Time (wall clock) (μs) *    |      1251 |      1265 |      1269 |      1282 |      1315 |      1414 |      3773 |      3901 |

### cmark-gfm (C) valid-multibyte-v1 parse validation-off 64 KiB (bytes: 65560, corpus: valid-multibyte-v1, profile: commonmark, syntax: off, validation: off)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |       934 |       934 |       934 |       934 |       934 |       934 |       934 |     10000 |
| Malloc (total) *            |      3774 |      3774 |      3774 |      3774 |      3774 |      3774 |      3774 |     10000 |
| Time (wall clock) (μs) *    |       299 |       313 |       315 |       317 |       326 |       364 |       409 |     10000 |

### cmark-gfm (C) valid-multibyte-v1 parse validation-on 16 KiB (bytes: 16385, corpus: valid-multibyte-v1, profile: commonmark, syntax: off, validation: on)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |       221 |       221 |       221 |       221 |       221 |       221 |       221 |     10000 |
| Malloc (total) *            |       960 |       960 |       960 |       960 |       960 |       960 |       960 |     10000 |
| Time (wall clock) (μs) *    |        85 |        87 |        88 |        88 |        89 |       108 |       157 |     10000 |

### cmark-gfm (C) valid-multibyte-v1 parse validation-on 256 KiB (bytes: 262155, corpus: valid-multibyte-v1, profile: commonmark, syntax: off, validation: on)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      3582 |      3582 |      3582 |      3582 |      3582 |      3582 |      3582 |      3550 |
| Malloc (total) (K) *        |        15 |        15 |        15 |        15 |        15 |        15 |        15 |      3550 |
| Time (wall clock) (μs) *    |      1378 |      1394 |      1401 |      1411 |      1437 |      1510 |      1703 |      3550 |

### cmark-gfm (C) valid-multibyte-v1 parse validation-on 64 KiB (bytes: 65560, corpus: valid-multibyte-v1, profile: commonmark, syntax: off, validation: on)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |       934 |       934 |       934 |       934 |       934 |       934 |       934 |     10000 |
| Malloc (total) *            |      3774 |      3774 |      3774 |      3774 |      3774 |      3774 |      3774 |     10000 |
| Time (wall clock) (μs) *    |       335 |       349 |       351 |       353 |       360 |       401 |       633 |     10000 |

