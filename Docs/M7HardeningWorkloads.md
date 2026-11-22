# M7 extension and hostile-input measurement workloads

22 November 2026. `HardeningBenchmarks` is a separate development executable;
the historical `ParserBenchmarks` target and its 72 identities stay unchanged.
No library source, public API, dependency pin, specification fixture or existing
performance allowance changes in this step. The preparation checkpoint and
subsequent full scaling baseline are recorded below; neither accepts M7.

## Inputs and cases

`Tools/Sources/BenchmarkCorpus/HardeningWorkload.swift` authors deterministic
raw-byte inputs. Corpus IDs version their shapes. The nominal sizes are
16 KiB, 64 KiB and 256 KiB; complete units can exceed a nominal size, so every
case tags its actual byte count, corpus, profile and syntax-detail selection.

| Corpus ID | Shape | Swift profile |
| --- | --- | --- |
| `m5-composed-v1` | One YAML header; repeated sections with distinct footnotes, inline/display/fenced math, alerts, folded callouts and GFM tables | GFM + all five M5 extensions |
| `footnotes-repeated-v1` | Many references to one definition | GFM + footnotes |
| `open-brackets-v1` | One long unclosed bracket run | Strict CommonMark |
| `long-emphasis-v1` | Unequal long delimiter runs producing deeply nested strong nodes | Strict CommonMark |
| `unmatched-backticks-v1` | Increasing, distinct backtick run lengths | Strict CommonMark |
| `quote-overflow-v1` | Repeated blocks with 256 quote prefixes, exceeding the default 128-container budget | Strict CommonMark |
| `invalid-utf8-v1` | Invalid/truncated UTF-8, NUL and CRLF bytes | Strict CommonMark |

All seven families have Swift parse cases with syntax details off/on at all
three sizes: **42 cases**. The two extension families also have full
parse-plus-render cases off/on: **12 cases**. The five hostile families each
have a C parse control at all three sizes: **15 cases**, giving **69 total**.

Timed iterations include parser creation/validation, parsing and document
destruction. Rendering includes global footnote indexing/backlinks, safe
admonition HTML, omitted metadata and escaped placeholder math; it does not
invoke a TeX engine. Generation and registration perform no parsing/rendering.
List/filter invocations therefore do not secretly parse unselected inputs.

The pinned cmark-gfm receives the identical original byte buffer directly,
with `CMARK_OPT_SOURCEPOS`, including invalid UTF-8 without Swift replacement
decoding. C construction, parsing and freeing are timed. These controls are
informational: C has no matching all-M5 profile; quote-depth and malformed-byte
handling policies need not match. There is no C render comparison here.
Existing mixed-corpus C/absolute/frozen-M2 budgets remain separate and unchanged.

## Functional checks

`HardeningWorkloadTests` verifies actual extension kinds, one shared footnote
with many references, literal unclosed brackets/backticks, many strong nodes,
the nesting-limit diagnostic and replacement output for invalid bytes. At
512 / 4,096 / 16,384 nominal bytes, all seven inputs are deterministic, retain
original bytes, revalidate through the public document initializer, preserve
semantic nodes/diagnostics/output with syntax details off/on, match standard
UTF-16 replacement decoding and reproduce full HTML from reverse-requested
progressive groups. These checks do not establish correctness at every larger
size or prove linear complexity.

## Reproduction and bounds

First build Release development tools with the pinned lockfile. For example,
using task-specific scratch/cache directories on macOS:

```sh
env CLANG_MODULE_CACHE_PATH=/private/tmp/gmsetzer-m7-module-cache \
  SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/gmsetzer-m7-module-cache \
  swift test --package-path Tools -c release --build-system native --jobs 2 \
  --disable-sandbox --scratch-path /private/tmp/gmsetzer-m7-benchmark-build \
  --cache-path /private/tmp/gmsetzer-m7-benchmark-cache \
  --config-path /private/tmp/gmsetzer-m7-config \
  --security-path /private/tmp/gmsetzer-m7-security \
  --skip-update --force-resolved-versions -debug-info-format none
```

Set the paths to those existing Release executables for the host. Invoke the
Python driver directly, with a fresh output directory for each invocation:

```sh
python3 -I Tools/run_hardening_benchmarks.py \
  --tool /private/tmp/gmsetzer-m7-benchmark-build/arm64-apple-macosx/release/BenchmarkTool \
  --binary /private/tmp/gmsetzer-m7-benchmark-build/arm64-apple-macosx/release/HardeningBenchmarks \
  --output /private/tmp/gmsetzer-hardening-list --list
```

Use `--smoke` instead of `--list` for the five selected 16 KiB cases; it takes
about 26 seconds on the recorded Mac. Use `--run-all` only after owner
confirmation for the full series (allow roughly 6–10 minutes). Linux paths
depend on the existing native host's Swift target/build directory; use no
replacement environment without its required approval.

The driver invokes the built tool directly, without an active SwiftPM/build
parent. Each case gets a private process group, five-second sampling limit
and default **30-second whole-command timeout**, including registration and
warmup. A timeout terminates that group and stops the series. It preserves
logs and a failed receipt; it is never a passing result or timing sample.
Missing/ambiguous exports also fail even when the tool exits zero. The pinned
tool filters base names but exports tagged names; both identities are checked.

Receipts retain compiler/host/load, Git revision and working-tree status,
source/lockfile/executable/allocator hashes, case names, raw-log hashes and
p50 metrics with their displayed units. Source/executable hashes must remain
unchanged throughout a successful invocation. Do not compile, profile or edit
measurement sources while timing. The reported malloc counts and volume are
gross requests, not retained heap or peak RSS; scaled allocation displays are
rounded and must retain their unit labels.

## Recorded checkpoint and remaining work

The [preparation report](Validation/M7/hardening-preparation-2026-11-22.md)
records **10 Release development-tool tests / 5 suites**, **36 isolated Python
tests in each of normal/optimized mode**, **69 listed identities** and **5/5
smoke cases** on macOS arm64 / Swift 6.4.2. The old 72-name list matches the
recorded historical list exactly. The initial failed filter attempt is retained
alongside the corrected run and contributes no timings.

The owner-authorised [full scaling baseline](Validation/M7/hardening-scaling-2026-11-22.md)
then completes **69/69 cases in 326 seconds** at clean `2f5f1bd`, with all
50 measurement-source hashes and existing executable/allocator identities
unchanged. Across 16/64/256 KiB, Swift timing grows about proportionally or
less, but allocation volume and optional token costs warrant further work.
At 256 KiB, long-emphasis syntax collection costs 6.41× the off case, and
open brackets request about 174 M gross bytes. Invalid UTF-8 takes 3.33× the
C control's time; C does not enable its UTF-8 validation flag, so this is not
an equivalent-work parity result. Retained tables cover all 23 size series,
27 annotation pairs and 15 informational C comparisons.

New-harness Linux/minimum Swift 6.2 validation remains pending. Historical
library correctness and parser optimizations retain their original identities;
no repeat of the 245-test library suite, full 72-case series or fresh M6
resource matrix is claimed by this tools-only step. Next profile token
allocation, large item/bracket buffers and malformed-byte processing. Larger
inputs, isolated fuzzing/sanitizers, retained/peak-memory work and M7 acceptance
remain separate.

The later [token arena candidate](Validation/M7/token-arena-2026-11-22.md)
measures a separate 12-case subset here plus 18 historical mixed controls per
variant. It reduces long-emphasis syntax-on time by 75–77%, with 262,219 → 94
profiled requests per parse; public tokens remain identical. All current
247 library tests pass on macOS/Linux ARM64, while Linux execution of this
development harness and minimum Swift 6.2 remain pending. No corpus, byte count,
profile or budget changes. The full 69-case data above retains its earlier
identity and is not claimed as fresh evidence for the three-file optimization.
Next focus on large bracket buffers and malformed-byte processing.

The [buffer follow-up](Validation/M7/inline-capacity-2026-11-22.md) then
compacts internal slots and reserves emission batches, without changing this
corpus or existing case identities. Another paired 12-hardening/18-mixed
subset per variant records **31.21% less gross bracket byte traffic** at
256 KiB (174.19 M → 119.82 M), with timing broadly maintained. Current 249-test
library suites pass on macOS/Linux ARM64, all public spec snapshots match and
targeted C/M2 gates pass. No full 69-case refresh or peak-RSS claim is made.
The malformed-byte path and explicit validation-enabled C control are next;
Linux execution of this harness and the minimum compiler remain pending.

## Separate explicit UTF-8 controls

`UTF8Benchmarks` adds 36 identities without altering the 69 cases above or the
historical 72-case target. `UTF8Workload` retains `invalid-utf8-v1` byte for byte
and adds `invalid-compatible-v1` and `valid-multibyte-v1`. Each has 16/64/256 KiB
nominal sizes, Swift syntax off/on and C UTF-8 validation off/on. Actual byte
counts and validation selection are tagged. Parser construction, parsing and
destruction are timed, with five-second sampling; registration only generates
bytes. This target is independent of the hardening driver's fixed case list.

After building/listing the target with the same pinned Tools package, run the
existing built executables directly (replace paths with the host's Release
directory and use a fresh output directory):

```sh
"$BENCHMARK_TOOL" --command run --targets UTF8Benchmarks \
  --benchmark-executable-paths "$UTF8_BENCHMARKS" \
  --baseline-storage-path /tmp/gmsetzer-utf8-result \
  --format markdown --grouping benchmark --time-units microseconds \
  --no-progress > /tmp/gmsetzer-utf8.md 2> /tmp/gmsetzer-utf8.stderr
```

The retained measurement helper adds a 300-second process-group timeout,
requires exactly 36 unique exported identities with all three metrics, and
checks source/executable hashes before/after. Owner approval for full runs
still applies. Never run builds or profilers alongside timed work on that host.

Release reference tests verify matching repaired HTML at 512/4,096/16,384 bytes
for the compatible and valid controls, using C validation-on and an output
bridge that rejects invalid UTF-8. Legacy `c0 af` repair intentionally differs
(Swift two replacements, C one). C validation-off is informational; even
matching HTML leaves different original-byte coordinate services. See the
[UTF-8 report](Validation/M7/utf8-2026-11-22.md) for paired results and limits.

The later [native x64 completion report](Validation/M7/final-x64-2026-11-22.md)
executes all 36 UTF-8, 69 hardening and 72 historical cases with unchanged
source/executable hashes, plus 12 Release tool tests and the source-matched
42-case progressive matrix. Mac full refresh and minimum Swift 6.2 library CI
also pass. Tools/fuzz builds are measured with their actual native Swift 6.4.2
compilers; existing minimum-compiler CI does not execute those separate packages.
The [coverage-guided campaign](Validation/M7/fuzz-2026-11-22.md) is a separate
bounded robustness check, not a timing sample or proof of all-input linearity.
