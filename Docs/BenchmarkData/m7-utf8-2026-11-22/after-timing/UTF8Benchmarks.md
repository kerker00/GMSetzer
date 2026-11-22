
## Baseline 'Current_run'

```
Host 'BlackBook.local' with 8 'arm64' processors with 16 GB memory, running:
Darwin Kernel Version 27.0.0: Tue Aug 11 21:02:16 PDT 2026; root:xnu-13432.1.9~1/RELEASE_ARM64_T8112
```
## UTF8Benchmarks

### GMSetzer invalid-compatible-v1 parse syntax-off 16 KiB (bytes: 16385, corpus: invalid-compatible-v1, profile: commonmark, syntax: off, validation: swift-repair)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      1584 |      1584 |      1584 |      1584 |      1584 |      1584 |      1584 |      7549 |
| Malloc (total) *            |      3285 |      3285 |      3285 |      3285 |      3285 |      3285 |      3285 |      7549 |
| Time (wall clock) (μs) *    |       609 |       650 |       658 |       663 |       687 |       763 |      2133 |      7549 |

### GMSetzer invalid-compatible-v1 parse syntax-off 256 KiB (bytes: 262145, corpus: invalid-compatible-v1, profile: commonmark, syntax: off, validation: swift-repair)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |        25 |        25 |        25 |        25 |        25 |        25 |        25 |       465 |
| Malloc (total) (K) *        |        52 |        52 |        52 |        52 |        52 |        52 |        52 |       465 |
| Time (wall clock) (μs) *    |      9861 |     10183 |     10297 |     10551 |     11100 |     26247 |     37728 |       465 |

### GMSetzer invalid-compatible-v1 parse syntax-off 64 KiB (bytes: 65545, corpus: invalid-compatible-v1, profile: commonmark, syntax: off, validation: swift-repair)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      6168 |      6168 |      6168 |      6168 |      6168 |      6168 |      6168 |      1826 |
| Malloc (total) (K) *        |        13 |        13 |        13 |        13 |        13 |        13 |        13 |      1826 |
| Time (wall clock) (μs) *    |      2448 |      2548 |      2585 |      2648 |      2785 |      5505 |     42539 |      1826 |

### GMSetzer invalid-compatible-v1 parse syntax-on 16 KiB (bytes: 16385, corpus: invalid-compatible-v1, profile: commonmark, syntax: on, validation: swift-repair)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      1584 |      1584 |      1584 |      1584 |      1584 |      1584 |      1584 |      7616 |
| Malloc (total) *            |      3285 |      3285 |      3285 |      3285 |      3285 |      3285 |      3285 |      7616 |
| Time (wall clock) (μs) *    |       622 |       646 |       656 |       660 |       671 |       729 |      1102 |      7616 |

### GMSetzer invalid-compatible-v1 parse syntax-on 256 KiB (bytes: 262145, corpus: invalid-compatible-v1, profile: commonmark, syntax: on, validation: swift-repair)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |        25 |        25 |        25 |        25 |        25 |        25 |        25 |       489 |
| Malloc (total) (K) *        |        52 |        52 |        52 |        52 |        52 |        52 |        52 |       489 |
| Time (wall clock) (μs) *    |      9815 |     10052 |     10158 |     10273 |     10412 |     11641 |     29692 |       489 |

### GMSetzer invalid-compatible-v1 parse syntax-on 64 KiB (bytes: 65545, corpus: invalid-compatible-v1, profile: commonmark, syntax: on, validation: swift-repair)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      6168 |      6168 |      6168 |      6168 |      6168 |      6168 |      6168 |      1901 |
| Malloc (total) (K) *        |        13 |        13 |        13 |        13 |        13 |        13 |        13 |      1901 |
| Time (wall clock) (μs) *    |      2486 |      2576 |      2617 |      2662 |      2728 |      2918 |      3654 |      1901 |

### GMSetzer invalid-utf8-v1 parse syntax-off 16 KiB (bytes: 16388, corpus: invalid-utf8-v1, profile: commonmark, syntax: off, validation: swift-repair)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      1252 |      1252 |      1252 |      1252 |      1252 |      1252 |      1252 |      7732 |
| Malloc (total) *            |      2738 |      2738 |      2738 |      2738 |      2738 |      2738 |      2738 |      7732 |
| Time (wall clock) (μs) *    |       624 |       630 |       633 |       648 |       674 |       758 |      5352 |      7732 |

### GMSetzer invalid-utf8-v1 parse syntax-off 256 KiB (bytes: 262148, corpus: invalid-utf8-v1, profile: commonmark, syntax: off, validation: swift-repair)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |        21 |        21 |        21 |        21 |        21 |        21 |        21 |       484 |
| Malloc (total) (K) *        |        44 |        44 |        44 |        44 |        44 |        44 |        44 |       484 |
| Time (wall clock) (μs) *    |     10033 |     10166 |     10240 |     10346 |     10519 |     11125 |     35789 |       484 |

### GMSetzer invalid-utf8-v1 parse syntax-off 64 KiB (bytes: 65540, corpus: invalid-utf8-v1, profile: commonmark, syntax: off, validation: swift-repair)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      5200 |      5200 |      5200 |      5200 |      5200 |      5200 |      5200 |      1871 |
| Malloc (total) (K) *        |        11 |        11 |        11 |        11 |        11 |        11 |        11 |      1871 |
| Time (wall clock) (μs) *    |      2500 |      2542 |      2576 |      2644 |      2734 |      3490 |     67930 |      1871 |

### GMSetzer invalid-utf8-v1 parse syntax-on 16 KiB (bytes: 16388, corpus: invalid-utf8-v1, profile: commonmark, syntax: on, validation: swift-repair)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      1252 |      1252 |      1252 |      1252 |      1252 |      1252 |      1252 |      7519 |
| Malloc (total) *            |      2738 |      2738 |      2738 |      2738 |      2738 |      2738 |      2738 |      7519 |
| Time (wall clock) (μs) *    |       631 |       644 |       651 |       675 |       694 |       851 |      1550 |      7519 |

### GMSetzer invalid-utf8-v1 parse syntax-on 256 KiB (bytes: 262148, corpus: invalid-utf8-v1, profile: commonmark, syntax: on, validation: swift-repair)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |        21 |        21 |        21 |        21 |        21 |        21 |        21 |       476 |
| Malloc (total) (K) *        |        44 |        44 |        44 |        44 |        44 |        44 |        44 |       476 |
| Time (wall clock) (μs) *    |     10115 |     10248 |     10314 |     10387 |     10551 |     12354 |     40721 |       476 |

### GMSetzer invalid-utf8-v1 parse syntax-on 64 KiB (bytes: 65540, corpus: invalid-utf8-v1, profile: commonmark, syntax: on, validation: swift-repair)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      5200 |      5200 |      5200 |      5200 |      5200 |      5200 |      5200 |      1518 |
| Malloc (total) (K) *        |        11 |        11 |        11 |        11 |        11 |        11 |        11 |      1518 |
| Time (wall clock) (μs) *    |      2560 |      2697 |      2771 |      2894 |      4530 |     11354 |     34900 |      1518 |

### GMSetzer valid-multibyte-v1 parse syntax-off 16 KiB (bytes: 16385, corpus: valid-multibyte-v1, profile: commonmark, syntax: off, validation: swift-repair)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |       444 |       444 |       444 |       444 |       444 |       444 |       444 |     10000 |
| Malloc (total) *            |       477 |       477 |       477 |       477 |       477 |       477 |       477 |     10000 |
| Time (wall clock) (μs) *    |       109 |       110 |       110 |       113 |       115 |       152 |      9102 |     10000 |

### GMSetzer valid-multibyte-v1 parse syntax-off 256 KiB (bytes: 262155, corpus: valid-multibyte-v1, profile: commonmark, syntax: off, validation: swift-repair)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      6796 |      6796 |      6796 |      6796 |      6796 |      6796 |      6796 |      2804 |
| Malloc (total) *            |      7499 |      7499 |      7499 |      7499 |      7499 |      7499 |      7499 |      2804 |
| Time (wall clock) (μs) *    |      1664 |      1711 |      1761 |      1794 |      1840 |      2746 |      3963 |      2804 |

### GMSetzer valid-multibyte-v1 parse syntax-off 64 KiB (bytes: 65560, corpus: valid-multibyte-v1, profile: commonmark, syntax: off, validation: swift-repair)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      1708 |      1708 |      1708 |      1708 |      1708 |      1708 |      1708 |     10000 |
| Malloc (total) *            |      1882 |      1882 |      1882 |      1882 |      1882 |      1882 |      1882 |     10000 |
| Time (wall clock) (μs) *    |       418 |       423 |       426 |       440 |       458 |       537 |      8602 |     10000 |

### GMSetzer valid-multibyte-v1 parse syntax-on 16 KiB (bytes: 16385, corpus: valid-multibyte-v1, profile: commonmark, syntax: on, validation: swift-repair)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |       444 |       444 |       444 |       444 |       444 |       444 |       444 |     10000 |
| Malloc (total) *            |       477 |       477 |       477 |       477 |       477 |       477 |       477 |     10000 |
| Time (wall clock) (μs) *    |       106 |       107 |       107 |       108 |       110 |       131 |       291 |     10000 |

### GMSetzer valid-multibyte-v1 parse syntax-on 256 KiB (bytes: 262155, corpus: valid-multibyte-v1, profile: commonmark, syntax: on, validation: swift-repair)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      6796 |      6796 |      6796 |      6796 |      6796 |      6796 |      6796 |      2883 |
| Malloc (total) *            |      7499 |      7499 |      7499 |      7499 |      7499 |      7499 |      7499 |      2883 |
| Time (wall clock) (μs) *    |      1667 |      1684 |      1705 |      1757 |      1803 |      1933 |     11276 |      2883 |

### GMSetzer valid-multibyte-v1 parse syntax-on 64 KiB (bytes: 65560, corpus: valid-multibyte-v1, profile: commonmark, syntax: on, validation: swift-repair)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      1708 |      1708 |      1708 |      1708 |      1708 |      1708 |      1708 |     10000 |
| Malloc (total) *            |      1882 |      1882 |      1882 |      1882 |      1882 |      1882 |      1882 |     10000 |
| Time (wall clock) (μs) *    |       417 |       423 |       425 |       432 |       452 |       545 |      5586 |     10000 |

### cmark-gfm (C) invalid-compatible-v1 parse validation-off 16 KiB (bytes: 16385, corpus: invalid-compatible-v1, profile: commonmark, syntax: off, validation: off)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |       676 |       676 |       676 |       676 |       676 |       676 |       676 |     10000 |
| Malloc (total) *            |      3303 |      3303 |      3303 |      3303 |      3303 |      3303 |      3303 |     10000 |
| Time (wall clock) (μs) *    |       254 |       268 |       271 |       275 |       281 |       312 |       465 |     10000 |

### cmark-gfm (C) invalid-compatible-v1 parse validation-off 256 KiB (bytes: 262145, corpus: invalid-compatible-v1, profile: commonmark, syntax: off, validation: off)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |        11 |        11 |        11 |        11 |        11 |        11 |        11 |      1090 |
| Malloc (total) (K) *        |        52 |        52 |        52 |        52 |        52 |        52 |        52 |      1090 |
| Time (wall clock) (μs) *    |      4290 |      4465 |      4530 |      4628 |      4833 |      5399 |      6856 |      1090 |

### cmark-gfm (C) invalid-compatible-v1 parse validation-off 64 KiB (bytes: 65545, corpus: invalid-compatible-v1, profile: commonmark, syntax: off, validation: off)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      2657 |      2657 |      2657 |      2657 |      2657 |      2657 |      2657 |      4442 |
| Malloc (total) (K) *        |        13 |        13 |        13 |        13 |        13 |        13 |        13 |      4442 |
| Time (wall clock) (μs) *    |      1041 |      1070 |      1082 |      1111 |      1147 |      1314 |     45520 |      4442 |

### cmark-gfm (C) invalid-compatible-v1 parse validation-on 16 KiB (bytes: 16385, corpus: invalid-compatible-v1, profile: commonmark, syntax: off, validation: on)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |       712 |       712 |       712 |       712 |       712 |       712 |       712 |     10000 |
| Malloc (total) *            |      3304 |      3304 |      3304 |      3304 |      3304 |      3304 |      3304 |     10000 |
| Time (wall clock) (μs) *    |       286 |       304 |       307 |       314 |       326 |       368 |      6289 |     10000 |

### cmark-gfm (C) invalid-compatible-v1 parse validation-on 256 KiB (bytes: 262145, corpus: invalid-compatible-v1, profile: commonmark, syntax: off, validation: on)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (M) *  |        11 |        11 |        11 |        11 |        11 |        11 |        11 |       944 |
| Malloc (total) (K) *        |        52 |        52 |        52 |        52 |        52 |        52 |        52 |       944 |
| Time (wall clock) (μs) *    |      4851 |      4997 |      5251 |      5394 |      5665 |      7262 |      9040 |       944 |

### cmark-gfm (C) invalid-compatible-v1 parse validation-on 64 KiB (bytes: 65545, corpus: invalid-compatible-v1, profile: commonmark, syntax: off, validation: on)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      2778 |      2778 |      2778 |      2778 |      2778 |      2778 |      2778 |      4034 |
| Malloc (total) (K) *        |        13 |        13 |        13 |        13 |        13 |        13 |        13 |      4034 |
| Time (wall clock) (μs) *    |      1178 |      1210 |      1222 |      1247 |      1278 |      1397 |      5628 |      4034 |

### cmark-gfm (C) invalid-utf8-v1 parse validation-off 16 KiB (bytes: 16388, corpus: invalid-utf8-v1, profile: commonmark, syntax: off, validation: off)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |       574 |       574 |       574 |       574 |       574 |       574 |       574 |     10000 |
| Malloc (total) *            |      2757 |      2757 |      2757 |      2757 |      2757 |      2757 |      2757 |     10000 |
| Time (wall clock) (μs) *    |       215 |       232 |       237 |       243 |       253 |       378 |     28937 |     10000 |

### cmark-gfm (C) invalid-utf8-v1 parse validation-off 256 KiB (bytes: 262148, corpus: invalid-utf8-v1, profile: commonmark, syntax: off, validation: off)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      9249 |      9249 |      9249 |      9249 |      9249 |      9249 |      9249 |      1209 |
| Malloc (total) (K) *        |        44 |        44 |        44 |        44 |        44 |        44 |        44 |      1209 |
| Time (wall clock) (μs) *    |      3560 |      3768 |      3926 |      4243 |      4747 |      6611 |     12806 |      1209 |

### cmark-gfm (C) invalid-utf8-v1 parse validation-off 64 KiB (bytes: 65540, corpus: invalid-utf8-v1, profile: commonmark, syntax: off, validation: off)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      2250 |      2250 |      2250 |      2250 |      2250 |      2250 |      2250 |      3631 |
| Malloc (total) (K) *        |        11 |        11 |        11 |        11 |        11 |        11 |        11 |      3631 |
| Time (wall clock) (μs) *    |       924 |       995 |      1046 |      1341 |      2472 |      3836 |     19274 |      3631 |

### cmark-gfm (C) invalid-utf8-v1 parse validation-on 16 KiB (bytes: 16388, corpus: invalid-utf8-v1, profile: commonmark, syntax: off, validation: on)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |       607 |       607 |       607 |       607 |       607 |       607 |       607 |     10000 |
| Malloc (total) *            |      2758 |      2758 |      2758 |      2758 |      2758 |      2758 |      2758 |     10000 |
| Time (wall clock) (μs) *    |       262 |       284 |       290 |       308 |       585 |      1566 |     34864 |     10000 |

### cmark-gfm (C) invalid-utf8-v1 parse validation-on 256 KiB (bytes: 262148, corpus: invalid-utf8-v1, profile: commonmark, syntax: off, validation: on)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      9804 |      9804 |      9804 |      9804 |      9804 |      9804 |      9804 |       937 |
| Malloc (total) (K) *        |        44 |        44 |        44 |        44 |        44 |        44 |        44 |       937 |
| Time (wall clock) (μs) *    |      4217 |      4518 |      4870 |      5526 |      6685 |     12583 |     33505 |       937 |

### cmark-gfm (C) invalid-utf8-v1 parse validation-on 64 KiB (bytes: 65540, corpus: invalid-utf8-v1, profile: commonmark, syntax: off, validation: on)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      2359 |      2359 |      2359 |      2359 |      2359 |      2359 |      2359 |      4486 |
| Malloc (total) (K) *        |        11 |        11 |        11 |        11 |        11 |        11 |        11 |      4486 |
| Time (wall clock) (μs) *    |      1030 |      1090 |      1104 |      1116 |      1142 |      1249 |     22222 |      4486 |

### cmark-gfm (C) valid-multibyte-v1 parse validation-off 16 KiB (bytes: 16385, corpus: valid-multibyte-v1, profile: commonmark, syntax: off, validation: off)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |       221 |       221 |       221 |       221 |       221 |       221 |       221 |     10000 |
| Malloc (total) *            |       960 |       960 |       960 |       960 |       960 |       960 |       960 |     10000 |
| Time (wall clock) (μs) *    |        76 |        79 |        80 |        81 |        85 |       103 |       199 |     10000 |

### cmark-gfm (C) valid-multibyte-v1 parse validation-off 256 KiB (bytes: 262155, corpus: valid-multibyte-v1, profile: commonmark, syntax: off, validation: off)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      3582 |      3582 |      3582 |      3582 |      3582 |      3582 |      3582 |      3781 |
| Malloc (total) (K) *        |        15 |        15 |        15 |        15 |        15 |        15 |        15 |      3781 |
| Time (wall clock) (μs) *    |      1241 |      1276 |      1290 |      1316 |      1364 |      1762 |     13699 |      3781 |

### cmark-gfm (C) valid-multibyte-v1 parse validation-off 64 KiB (bytes: 65560, corpus: valid-multibyte-v1, profile: commonmark, syntax: off, validation: off)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |       934 |       934 |       934 |       934 |       934 |       934 |       934 |     10000 |
| Malloc (total) *            |      3774 |      3774 |      3774 |      3774 |      3774 |      3774 |      3774 |     10000 |
| Time (wall clock) (μs) *    |       302 |       317 |       320 |       327 |       340 |       391 |     13414 |     10000 |

### cmark-gfm (C) valid-multibyte-v1 parse validation-on 16 KiB (bytes: 16385, corpus: valid-multibyte-v1, profile: commonmark, syntax: off, validation: on)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |       221 |       221 |       221 |       221 |       221 |       221 |       221 |     10000 |
| Malloc (total) *            |       960 |       960 |       960 |       960 |       960 |       960 |       960 |     10000 |
| Time (wall clock) (μs) *    |        84 |        86 |        87 |        88 |        89 |       105 |       386 |     10000 |

### cmark-gfm (C) valid-multibyte-v1 parse validation-on 256 KiB (bytes: 262155, corpus: valid-multibyte-v1, profile: commonmark, syntax: off, validation: on)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |      3582 |      3582 |      3582 |      3582 |      3582 |      3582 |      3582 |      3324 |
| Malloc (total) (K) *        |        15 |        15 |        15 |        15 |        15 |        15 |        15 |      3324 |
| Time (wall clock) (μs) *    |      1374 |      1428 |      1480 |      1510 |      1562 |      2204 |      9166 |      3324 |

### cmark-gfm (C) valid-multibyte-v1 parse validation-on 64 KiB (bytes: 65560, corpus: valid-multibyte-v1, profile: commonmark, syntax: off, validation: on)

| Metric                      |        p0 |       p25 |       p50 |       p75 |       p90 |       p99 |      p100 |   Samples |
|:----------------------------|----------:|----------:|----------:|----------:|----------:|----------:|----------:|----------:|
| Malloc (bytes total) (K) *  |       934 |       934 |       934 |       934 |       934 |       934 |       934 |     10000 |
| Malloc (total) *            |      3774 |      3774 |      3774 |      3774 |      3774 |      3774 |      3774 |     10000 |
| Time (wall clock) (μs) *    |       334 |       366 |       375 |       393 |       479 |      1110 |      3725 |     10000 |

