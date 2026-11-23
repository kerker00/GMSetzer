# M7 extension/hostile-input preparation checkpoint

22 November 2026. Local `feature/m7-hardening` preparation over
`a56a26ea680f9b777e4cdafe96f0f88a31ab086a`, development identity
`0.7.0-dev.1`. The harness is not committed during measurement: exact source,
lockfile, executable and allocator hashes plus dirty status are retained in
the [receipt](../../BenchmarkData/m7-hardening-preparation-2026-11-22/receipt.json).
Library source/root manifest, protected fixtures, historical benchmark source/
generator and dependency lockfile match that revision byte for byte. This step
adds development tooling, tests and documentation only.

## Executed validation

macOS 27.0.1 / arm64, eight logical CPUs, Apple Swift 6.4.2
(`swiftlang-6.4.2.1.9 clang-2100.4.1.1`). No installation or replacement
execution environment is used.

| Check | Observed result |
| --- | --- |
| Release development-tool suite | 10 tests / 5 suites pass, exit 0 |
| Python isolated | 36 tests pass, exit 0 |
| Python optimized isolated | 36 tests pass, exit 0 |
| New target listing | 69 unique tagged names |
| Historical target listing | 72 names, exact equality including order/byte tags |
| Final bounded smoke | 5/5 complete, exit 0; source/executable hashes unchanged |

The tool suite includes generated-document comparisons with pinned C as well
as the four new workload tests. Seven parameterized workload arguments are
included in Swift Testing's ten reported tests, not added as separate test
methods. New checks verify real M5 node kinds, repeated shared-note references,
hostile shapes, byte retention, annotation invariance, validated documents,
UTF-16 decoding and full/grouped output equality at bounded sizes. See the
[workload contract](../../Archive/M7HardeningWorkloads.md) for exact scope and commands.
Python checks exercise malformed/ambiguous results, literal base-name filters,
incomplete listings and a bounded subprocess timeout that preserves logs.

The Release build uses the native SwiftPM build system, two jobs,
`--force-resolved-versions`, task-specific scratch/cache/module directories and
the pinned lockfile. Existing `--skip-update` / `--build-system native`
deprecation warnings are retained; the build and test command completes
successfully. Python commands are:

```sh
python3 -I -m unittest discover -s Scripts
python3 -O -I -m unittest discover -s Scripts
```

No repeat of the library's 245-test suite is claimed: its runtime/tests/root
manifest are unchanged by this checkpoint. Previously recorded current-parser
correctness remains in the [scratch-buffer report](inline-scratch-2026-11-21.md).
The new harness has not run on Linux or the minimum Swift 6.2 compiler.

## Smoke observations and limits

The existing Release `BenchmarkTool` and `HardeningBenchmarks` run directly,
without a SwiftPM/build parent. Each invocation selects one base name; every
export must contain exactly that tagged case and one valid wall-clock/count/
volume metric. Five-second sampling, default 30-second whole-case timeout and
private process groups apply. No compilation, test suite or profiling is
launched alongside this final timing series. Other host activity is not
controlled; these smoke timings are not acceptance thresholds.

Final series completes on 22 November, ending **06:22:12 UTC**, in about
26 seconds. One/five/fifteen-minute load averages change from
3.99 / 4.70 / 3.47 to 3.57 / 4.53 / 3.46. Allocation columns below retain the
benchmark tool's rounded K/M displays.

| Case, nominal 16 KiB | Actual bytes | p50 ms | Samples | Malloc count | Gross requested bytes |
| --- | ---: | ---: | ---: | ---: | ---: |
| All M5 parse, syntax off | 16,654 | 3.400 | 1,464 | 17 K | 4,223 K |
| All M5 parse + render, syntax on | 16,654 | 7.487 | 667 | 30 K | 7,512 K |
| Shared footnote parse + render, syntax off | 16,398 | 5.063 | 986 | 21 K | 5,549 K |
| Unclosed brackets parse, syntax off | 16,384 | 1.060 | 4,709 | 63 | 13 M |
| C unclosed brackets parse, source positions on | 16,384 | 1.316 | 3,785 | 33 K | 3,672 K |

The bracket case's 13 M gross requested bytes merits investigation across
sizes; a single small input does not establish growth order or peak memory.
No M5-versus-C claim is possible with these profiles. No optimization speedup,
full-suite budget pass, larger-input complexity or peak-RSS reduction is
inferred from this smoke check.

The first attempt exits without a case: the pinned tool filters `baseName`
but the initial driver passed the tagged display name. The driver rejects
the empty result even though the tool exits zero, preserving a failed receipt.
The corrected filter passes five cases. Review then tightens metric-category
validation; the final driver passes the same five cases again. Both successful
runs and the failed attempt remain archived; only final rows are summarized
above. No library workaround or input/budget relaxation is involved.

## Evidence and next work

The [data directory](../../BenchmarkData/m7-hardening-preparation-2026-11-22/)
retains 69/72 name lists, a final CSV/receipt, validation metadata and 38
sanitized archive members with original/retained hashes. Runtime/measurement
sources and the tool/executable are unchanged during the final run. The
recorded dirty state is explicit; no clean-commit timing claim is made.

Full **69-case** execution at all three sizes is prepared but not performed.
It remains subject to the owner-confirmation rule in `CLAUDE.md`; allow about
6–10 minutes on this host, stopping at the first timeout/invalid result.
Analyse actual byte ratios against timing/gross allocation growth before
selecting another parser change. Minimum-compiler/new-harness Linux execution,
the fresh progressive resource matrix, full historical benchmark refresh and
broader isolated fuzz/sanitizer evidence remain open. M7 is not accepted,
merged, pushed or released by this checkpoint.
